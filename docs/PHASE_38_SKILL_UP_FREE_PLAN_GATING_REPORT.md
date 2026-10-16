# Phase 38 — Skill-Up Free-Plan Access Gating Report

## 1. Summary

The premise carried forward from Phase 15/35 — "the server rejects restricted requests while Flutter shows a generic or unhandled error" — was **not what the evidence showed**. Reading the actual server-side gating mechanism (`core/skillup_access.py`) revealed a different, more specific, and more serious bug: **a real paid/Pro-plan user could not access Skill-Up content they were entitled to**, because the app's WebView-based lesson viewer never carried the session cookie the server's gating middleware needs to identify the user. Every lesson request looked anonymous to that middleware, so **every** non-free lesson was shown as locked, regardless of the viewer's actual plan — not a cosmetic error-message problem, but a functional access bug.

**Fix**: the lesson screen now sends the same session cookie this app's own authenticated API calls already carry (via the existing `ApiClient.buildCookieHeader()` bridge, already used for exactly this kind of non-Dio-consumer cookie-sharing by Group Discussion's WebSocket). Separately, when the server's gating genuinely does return its locked-content response (HTTP 403, confirmed as this endpoint's only use of that status), the app now shows a native Flutter view with the same message the server's own page uses, with a "View Plans" button that opens this app's own real Subscription/Pro screen — not the WebView navigating away to the live website.

**Device-verified**: on the same physical phone used in prior phases, logged in as the already-known Pro-plan test account, opening a genuinely restricted Tech Center lesson ("DBMS Study Guide") now loads the real lesson content instead of a locked page — direct, live confirmation of the fix.

## 2. Evidence establishing the expected restriction behavior

**Source read in full**: `royalStaffing_CB01/core/skillup_access.py` (`SkillUpAccessMiddleware`).

- Skill-Up lessons are raw static HTML files under `/static/001 Career Buddy/`, otherwise served with no authentication at all.
- `SkillUpAccessMiddleware` sits in front of the static file server. For any `.html`/`.htm` request under that prefix, it reads the Django session cookie **directly from the request's cookies** (it runs before Django's own auth middleware, so it can't use `request.user`) to identify the visitor.
- `FREE_PREFIXES = ('001 CEFR/', 'Vocabulary/', 'GrammerActivities/')` plus one named file are always servable, authenticated or not.
- For anything else, `is_locked_lesson(path) and not has_full_skillup(user)` → returns **HTTP 403** with a self-contained HTML body (`LOCKED_PAGE`): a clear "This Skill Up content is locked" message, the exact copy about what the Free plan includes, and a link to `/pro/`.
- `has_full_skillup(user)` is `False` whenever `user` is `None` (not authenticated, or — critically — authenticated but the request carried no session cookie the middleware could read) **or** the resolved plan isn't `normal`/`pro`.
- This is the *only* place this exact URL prefix returns 403 — every other branch of the middleware either redirects (employer sessions, to job-seeker login) or passes through unchanged. A 403 on this specific request is therefore unambiguous evidence of this exact restriction, not a generic assumption about 403s elsewhere in the app.

## 3. The original Flutter issue and verified root cause

**Read**: `lib/features/skill_up/presentation/screens/skill_up_lesson_screen.dart` (before this phase), `lib/core/network/api_client.dart`.

- The lesson screen loads each lesson's real URL directly into a `WebViewController` (`webview_flutter`), which maintains its **own, separate cookie store** — entirely independent of this app's own authenticated `Dio` client (`ApiClient`'s `PersistCookieJar`, which is where the Django session cookie actually lives after a real login).
- The screen's own prior doc comment asserted "no session-cookie sharing concerns apply here... confirmed live (200, unauthenticated)" — true for a **Free** lesson (which `is_locked_lesson` always allows), but not re-checked against a genuinely restricted lesson, where the middleware's cookie check does matter.
- **Verified root cause**: because the WebView never received the session cookie, every request to a non-Free lesson arrived at the middleware looking anonymous, so `has_full_skillup(None)` was always `False` and every such lesson showed the locked page — for a Free-plan user (correct) and a Normal/Pro-plan user (incorrect) alike.
- This was confirmed, not assumed: `Mobile_app`'s own existing `ApiClient.buildCookieHeader()` doc comment explicitly documents this exact Dio-vs-non-Dio cookie gap as the reason Group Discussion's WebSocket needs to read it manually — the same gap, unaddressed, applied here.

## 4. Implementation and user-visible behavior

**Files changed:**

| File | Change |
|---|---|
| `lib/features/skill_up/presentation/screens/skill_up_lesson_screen.dart` | Converted to `ConsumerStatefulWidget`; before loading a lesson (initial load and retry), reads `ApiClient.buildCookieHeader()` and sends it as the request's `Cookie` header. Added `onHttpError` handling: a 403 response sets a new `_locked` state (distinct from `_error`), rendering `SkillUpLockedView` instead of the WebView. |
| `lib/features/skill_up/presentation/widgets/skill_up_locked_view.dart` | **New.** A plain, native Flutter view reusing the server's own `LOCKED_PAGE` copy verbatim, with a "View Plans" button. |

**User-visible behavior now:**
- A **Normal/Pro-plan** user opening any lesson, Free or not, sees the real lesson content — confirmed live (see §7).
- A **Free-plan or anonymous** user opening a genuinely restricted lesson sees a native "This Skill Up content is locked" view with the real explanation of what the Free plan includes, and a "View Plans" button.
- A genuine network/connectivity failure (no main-frame response at all) still shows the existing `AppErrorView` with retry, unchanged.
- Tapping "View Plans" pushes this app's own existing, verified `RoutePaths.pro` screen — not a WebView navigation to the live website's `/pro/` page (what would otherwise have happened had the server's own HTML simply been left to render inside the WebView).

**What this phase did *not* need to add**: a way to distinguish "not authenticated" from "authenticated but Free plan" for this specific screen. Source evidence shows the server itself does not distinguish these two cases for this endpoint — both resolve to the exact same 403/locked response. Separately, an anonymous visitor cannot reach this screen at all: Skill-Up routes are not in `RoutePaths.publicRoutes`/`universalRoutes`, so the existing, already-tested generic auth guard (`route_guards_test.dart`'s "AuthUnauthenticated sends any non-public location to login") already redirects them to `/login` before this screen would ever build. No new auth-redirect behavior was needed or added.

## 5. The upgrade route used

`RoutePaths.pro` — an existing, already-wired, verified Flutter route (confirmed in use elsewhere, e.g. the Phase 37 landing-page footer's "CareerBuddy Pro" link, and `BuddyChatbotOverlay`'s own existing `/pro/` action-chip handling). No new route was invented.

## 6. Tests added

`test/features/skill_up/presentation/widgets/skill_up_locked_view_test.dart` (3 tests, all passing):
1. Renders the exact locked-content copy (title, explanation, button label) matching the server's own `LOCKED_PAGE`.
2. Tapping "View Plans" invokes the provided callback exactly once.
3. Renders without overflow at the narrowest target width (320px).

**Why this is the right and honest scope, and what isn't automated-tested:** `SkillUpLessonScreen` itself embeds a real `WebViewController`, which has no platform implementation under plain `flutter test` (no device/emulator) — it cannot be pumped or driven in this harness at all, confirmed by this screen having no existing test of its own before this phase either. `SkillUpLockedView` is the one genuinely native, non-WebView-dependent part of the locked path, so it is what's tested directly, mirroring the only testable boundary. The specific scenarios from the task's test list map as follows:

| Test list item | How it's actually covered |
|---|---|
| 1. Free-plan user sees locked/upgrade state | `SkillUpLockedView`'s own tests (content + button), plus the server-side 403 condition read directly from source (§2) |
| 2. Paid user can access permitted content | **Device-verified live** (§7) — not automatable without a real WebView |
| 3. Auth failures distinct from subscription restrictions | Not a separate code path for this screen (§4) — already covered by the existing, generic, passing `route_guards_test.dart` auth-redirect test, since this screen is unreachable while unauthenticated |
| 4. Network/server errors show the general error state | Unchanged, pre-existing `onWebResourceError` → `AppErrorView` path, not modified this phase, not re-tested (no behavior change to it) |
| 5. Upgrade action navigates to the correct destination | `SkillUpLockedView`'s own callback-invocation test confirms the view's contract; the one-line wiring `onViewPlans: () => context.push(RoutePaths.pro)` inside `SkillUpLessonScreen` is verified by direct code reading, not an automated test, for the same WebView-platform-dependency reason as item 2 |

## 7. Focused and full test results

```
flutter test test/features/skill_up/                → 17/17 passing (14 pre-existing + 3 new)
flutter test                                          → 2307 passing, 0 failing
flutter analyze                                       → 7 issues (identical pre-existing warnings; 0 new)
```

Baseline comparison: Phase 37 reported 2304 passing / 0 failing / 7 warnings. This phase: **2307 passing** (net +3, exactly the 3 new `SkillUpLockedView` tests, nothing removed or weakened) / 0 failing / **7 warnings, identical to before** (no new analyzer issues).

## 8. Device verification

**Performed, live, on the same physical device used in Phases 35-37** (`RMX5004`, Android 16, confirmed connected via `adb devices`). A fresh debug APK with this phase's changes was built and installed.

- The device's existing session (the already-known Pro-plan test account from prior phases' own verification reports) was used as-is — not re-entered, not newly created, no credential handled or exposed.
- Navigated: drawer → Skill Up → Aptitude/Tech submenu → "Sections in depth" → scrolled to the **Tech Center** group → opened **"DBMS Study Guide"** (`TechCenter/...` — confirmed, by its path alone, to be outside every `FREE_PREFIXES` entry, i.e. genuinely restricted content).
- **Result**: the real lesson content loaded and rendered correctly (a full tabbed study guide — Introduction/ER Model/Relational/Normalisation/etc. — with real formatted text), not the locked page. This is the exact outcome only possible if the middleware now correctly recognizes this session as a paid plan, which only works if the session cookie reached it — direct, live confirmation the fix works.
- **Not performed**: the complementary free-plan-sees-locked-page check, since no Free-plan test account is available to this session, and inventing one or fabricating credentials is explicitly against this phase's rules. This side of the behavior rests on: the server's own source code (§2, unambiguous), and the native `SkillUpLockedView`'s own passing tests (§6) — not a live device observation of an actual Free-plan account.
- **Not performed**: a literal "before/after" comparison on-device (reverting the fix, rebuilding, and re-confirming the old broken behavior) — the `git diff`-level evidence that no cookie was ever sent before this phase, combined with the middleware's own source logic, already establishes the prior broken state without needing to deliberately reintroduce it for a side-by-side screenshot.
- Free-plan-accessible content (English & Vocabulary / Grammar) was not separately re-tested live this phase: the fix only *adds* an HTTP header to every lesson request, and the middleware's own `is_locked_lesson` check allows Free-content paths unconditionally regardless of any header present — there is no code path by which adding a `Cookie` header could affect an already-unrestricted request, so this is treated as a safe, non-regression-risk change by source inspection, not re-verified by a redundant screenshot.

## 9. Remaining limitations and unresolved questions

- No Free-plan account was available to directly observe the locked state live; the fix's correctness for that side rests on source-code evidence and widget tests, as detailed above.
- This phase did not add any pre-emptive "locked" indicator to the Skill-Up hub/section browsing screens (e.g., a lock icon on a restricted lesson card before it's even tapped) — `AuthUser` carries no plan field today, and the app has no existing, verified endpoint exposing plan status client-side ahead of a request; inventing one was explicitly out of scope ("do not invent routes, endpoints, response formats... do not hardcode a user's subscription status"). The fix implemented here is a reactive one (correct behavior once the request is made), not predictive.
- The underlying `has_full_skillup` plan check (`career_app/views._get_user_plan`) was read only as far as needed to understand its three-way `free`/`normal`/`pro` outcome; its own internal logic (e.g. how a plan is determined to have expired) was not re-audited, since it is unrelated to the actual bug (a cookie never arriving at all, regardless of what the check would have decided once it could run).

## 10. Boundaries respected

- Neither Django reference directory was modified.
- No backend code, model, migration, permission, or subscription rule was changed — only confirmed by reading the existing one.
- No authentication/session/role-check logic was changed; the fix reuses the exact existing cookie jar and session mechanism already in place.
- No plan status was hardcoded, guessed, or bypassed — the real server-side check remains the sole authority; this phase only ensures Flutter's request reaches it honestly.
- No new endpoint, route, or response format was invented.
- No Create Resume or unrelated Skill-Up work was touched.
- No unrelated file was refactored or broadly reformatted — formatting was run only on this phase's own 3 changed/new files.
- No signing material, credential, or secret was inspected, printed, or modified.

## Completion

Per this phase's own scope boundary: stopping here. Awaiting explicit approval before Phase 39 or any further change.
