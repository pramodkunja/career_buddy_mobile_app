# Phase 37 — Landing Page UI Rebuild Report

## 1. Summary

The Flutter landing/home screen was rebuilt from the **actual current** `royalStaffing_CB01/templates/landing.html` source, not from the older `templates/home.html` template the previous implementation was based on, and not from assumptions in earlier reports. Every visual/content claim below was verified by reading the live source directly this phase (markup, CSS cascade, and — critically — the full CSS override chain, which changes several conclusions from the Phase 35 audit; see §9).

Changed: the hero (`HomeHero`), the job-seeker/employer marketing cards (`PortalCard`, now content-accurate instead of based on a removed template), the brand logo (`AppTopBar`/`AppFooter`), a new trust strip (`HomeTrustStrip`), and a new landing-specific footer (`HomeLandingFooter`) that replaces the shared `AppFooter` only on the pages that, on the real site, never show that shared footer at all. All existing navigation, authentication, and the debug-preview gate are unchanged and device-verified intact.

## 2. Updated website files and assets used as references

- `royalStaffing_CB01/templates/landing.html` — read in full for the hero (`.hero`, lines ~472-660 and the overriding "VIBRANT THEME LAYER" block, lines ~1299-1450), the job-seeker/employer "story" sections (`#job-seeker`/`#employer`, lines 6839-6945), the trust strip (lines 6607-6625), and the landing-specific footer (`<footer id="contact">`, lines 7349-7402).
- `royalStaffing_CB01/static/img/logo-mark.png` and `logo-mark-light.png` — copied verbatim (read-only source, never modified) into `Mobile_app/assets/images/`.
- The hero's own embedded base64 illustration (`landing.html:6569`) was extracted and inspected directly to confirm what it actually is (a flat-style illustration, not a photo) — ultimately **not used**, see §9 for why.

## 3. Flutter files changed

| File | Change |
|---|---|
| `lib/features/home/presentation/widgets/home_hero.dart` | Full rebuild: light/vibrant gradient background, gradient-clipped headline text, real lead copy, pill-shaped buttons, correct "Get Started Free" label. |
| `lib/features/home/presentation/widgets/portal_card.dart` | Full rebuild: eyebrow/headline/body/4-item checklist/single CTA/secondary login link/content panel with mini-cards, replacing the old full-bleed photo-card design. |
| `lib/features/home/presentation/widgets/public_home_body.dart` | Wires the rebuilt hero, new trust strip, and both rebuilt story cards with their real content. |
| `lib/features/home/presentation/widgets/home_trust_strip.dart` | **New.** The 5-item trust band under the hero. |
| `lib/features/home/presentation/widgets/home_landing_footer.dart` | **New.** The landing-specific 4-column footer. |
| `lib/features/home/presentation/screens/home_screen.dart` | Swaps in the new footer for every non-employer case (guest and authenticated student); keeps the existing shared `AppFooter` for the authenticated-employer case only. |
| `lib/shared/widgets/app_top_bar.dart` | Real logo asset (`logo-mark.png`) replacing the generic `Icons.school_outlined` placeholder. |
| `lib/shared/widgets/app_footer.dart` | Real logo asset (`logo-mark-light.png`) replacing the generic icon placeholder. |
| `pubspec.yaml` | Registers the 2 new logo assets. |
| `assets/images/logo-mark.png`, `logo-mark-light.png` | **New**, copied verbatim from the read-only web source. |

Incidental, unrelated-but-honest fix: an overly broad `dart format` pass (run on every git-modified Dart file rather than only this phase's own changes) reformatted two pre-existing files from earlier, already-uncommitted phases (`resume_role_parser.dart`, `role_picker_screen.dart`) and, as a side effect of their changed line-wrapping, surfaced 5 latent `curly_braces_in_flow_control_structures` analyzer infos in code neither written nor touched by this phase. Rather than attempt to reconstruct their exact prior formatting, the 5 missing-brace spots were fixed directly (adding `{ }` around single-statement `if` bodies — a trivially safe, behavior-preserving change). Confirmed via `flutter analyze` returning to exactly the pre-Phase-37 baseline afterward (§8).

## 4. Before-and-after: major visible differences

| Element | Before | After |
|---|---|---|
| Hero background | Solid dark navy gradient | Light, multi-color radial/linear gradient (the actual current `.hero` rule, confirmed as the active, non-overridden-again rule) |
| Hero headline | Plain white text | Gradient-clipped text (navy→indigo→pink), via `ShaderMask` reproducing the web's `background-clip:text` |
| Hero primary CTA | "Get Started", flat gold, rectangular | "Get Started Free", blue→violet→pink gradient, pill-shaped |
| Hero eyebrow badge | Plain translucent navy pill | Light blue-to-pink tinted pill, purple text, sparkle icon |
| Job-seeker/employer cards | Full-bleed photo cards with stat-number bubbles with no current web equivalent, content from the removed `home.html` template | Two-column "story" layout: real current headline/body/4-item checklist/single CTA, matching `landing.html`'s actual `#job-seeker`/`#employer` sections |
| Trust strip | Absent | Present, 5 items, gradient band |
| Brand logo | Generic `Icons.school_outlined` everywhere | The real lightbulb-mascot logo (`logo-mark.png`/`logo-mark-light.png`, matching which variant the web itself uses on which background) |
| Footer (landing screen only) | Shared simple `AppFooter` | The landing page's own richer 4-column footer, matching `landing.html` being a fully standalone template with its own footer (confirmed by its absence of `{% extends %}`) |

## 5. CTA and navigation behavior: preserved or adjusted, with evidence

- **"Get Started Free"** (renamed from "Get Started"): same callback, same destination (`RoutePaths.register` for a guest, dashboard for an authenticated user) — confirmed by `home_screen_test.dart`'s passing navigation tests.
- **"Find Jobs" / "Create Resume"**: unchanged labels, unchanged callbacks/destinations, including the Phase 34 choice-sheet behavior for "Create Resume" — confirmed by the same passing tests, unmodified in intent.
- **Job-seeker/employer card CTAs** (renamed "Register Free"→"Explore Job Seeker Portal", "Register Company"→"Explore Employer Portal"): same underlying `onRegister`/`onEmployerRegister` callbacks, same destinations — only the visible label changed, to match the real web's own button text. Confirmed by passing tests asserting the post-tap destination.
- **Login**: the real web's story sections have no inline login link (login lives only in the nav bar there), but this phase preserves the existing, working `onLogin`/`onEmployerLogin` actions as a small secondary "Login" text link under each card's primary CTA, rather than silently removing a working action — confirmed by a passing test.
- **Footer links**: of 18 real links, 16 map to an existing Flutter route/callback and are wired to their exact real destinations (see §6 for the full mapping and the 2 that don't). Confirmed live on-device (Skill Up and CareerBuddy Pro footer links navigate correctly) and by passing tests.
- **Debug-preview button and login screen**: untouched — confirmed unchanged both by source (no file in `features/auth/` was modified) and live on-device (screenshot: the "Preview Demo (Debug)" button still renders correctly at the bottom of the Job Seeker Sign In screen).

## 6. Footer link mapping (Task 6)

| Column | Link | Destination | Status |
|---|---|---|---|
| Platform | Skill Up | `RoutePaths.skillUp` | Mapped, device-verified |
| Platform | Activities | `RoutePaths.activities` | Mapped |
| Platform | Resume Parsing | `RoutePaths.resumeBuilder` | Mapped |
| Platform | Grammar | `RoutePaths.grammar` | Mapped |
| Platform | Sitemap | `RoutePaths.sitemap` | Mapped (an existing, real Flutter route — opens the Skill-Up hub's own Sitemap tab, matching the web's own "not a separate page either" nature) |
| Job Seekers | Find Jobs | Same destination as the hero's own "Find Jobs" button | Mapped |
| Job Seekers | Resume & AI | `RoutePaths.resumeBuilder` | Mapped |
| Job Seekers | Interviews | `RoutePaths.resumeBuilder` (identical href on the real web too) | Mapped |
| Job Seekers | Skills & Training | `RoutePaths.skillUp` | Mapped |
| Job Seekers | Create Account | `onRegister` | Mapped |
| Employers | Employer Dashboard / Manage Jobs / Candidates / Applications | `onEmployerLogin` (matching the real web redirecting a logged-out visitor to employer login for all 4) | Mapped |
| Employers | Register Company | `onEmployerRegister` | Mapped |
| Company | CareerBuddy Pro | `RoutePaths.pro` | Mapped, device-verified |
| Company | About Us (`#why`) | — | **Not mapped — remaining gap.** An in-page anchor on the web with no distinct Flutter screen; not reproduced rather than inventing a placeholder. |
| Company | Ask Buddy (`#buddy`) | — | **Not mapped — remaining gap, but with an existing equivalent.** The persistent `BuddyChatbotOverlay` floating on every screen already serves this purpose in spirit; not reproduced as a separate footer link since it isn't a distinct destination to navigate to. |

## 7. Responsive layouts checked and actual results

- **Widget-test-verified** at 320px, 360px, 390px, and 430px width (`home_hero_test.dart`, `home_screen_test.dart`): no overflow exceptions at any width, including 320px — which previously had a documented, pre-existing overflow in the old `PortalCard` that this rebuild also resolves as a natural consequence of the new layout (not a separately-scoped fix).
- Two real overflow bugs were found and fixed during this phase's own testing (not pre-existing — introduced by this phase's own new widgets, caught before being considered done): the hero's eyebrow badge and the trust strip's item rows both initially overflowed at narrow widths because their `Text` children weren't wrapped in `Flexible`; fixed by adding `Flexible` so the text wraps instead of forcing a fixed intrinsic width.
- **Device-verified** (see §8) on a real physical Android phone at its native width: hero, trust strip (wraps into 2 rows cleanly), both story cards, and the new footer all rendered without visible overflow or clipping.
- Not separately tested at a tablet/wider width this phase (out of scope — the task's own target widths are phone-only, matching every other screen in this app).

## 8. Test commands and real results

```
flutter test test/features/home/                                → 30/30 passing
flutter test test/shared/widgets/app_top_bar_test.dart \
             test/shared/widgets/app_footer_test.dart            → 7/7 passing
flutter test                                                      → 2304 passing, 0 failing
flutter analyze                                                   → 7 issues (identical pre-existing warnings; 0 new)
```

The full-suite count (2304) is **up from Phase 36's baseline of 2299** — net +5 new/updated test cases covering the rebuilt story sections and the new landing-specific footer, with no test weakened or removed to make this pass (the one old assertion set describing the previous stale-template card copy was replaced with one describing the actual current copy, which is a correction, not a removal of coverage).

## 9. Device verification

**Performed, on the same physical device used in Phases 35/36** (`RMX5004`, Android 16, confirmed connected via `adb devices`). A fresh debug APK with this phase's changes was built (`flutter build apk --debug`) and installed (`adb install -r`).

- Launched the app; the device's existing authenticated session (the user's own prior login, not touched or re-entered by this phase) landed on the Dashboard, confirming session persistence continues to work after the reinstall.
- Navigated to Home via the drawer: the authenticated-student hero rendered correctly (gradient background, gradient headline text, correct buttons, logo in the top bar) followed immediately by the new landing footer.
- Logged out via the existing, unmodified Logout action (not a bypass — a normal, already-wired app feature) to inspect the full guest experience: hero → trust strip (wraps into 2 rows, no overflow) → job-seeker story card (eyebrow, headline, body, 4-item checklist, gradient CTA, secondary Login link, navy content panel with 3 mini-cards) → employer story card (beginning to render correctly, same structure, light panel) → footer (all 4 columns, correct links, correct logo).
- Confirmed the Job Seeker Sign In screen and its "Preview Demo (Debug)" button are completely unchanged.
- Did **not** test a release or profile build this phase — not required by this phase's task list, and the debug build is what every device check above used.

No screenshot content shown above or saved includes any credential, session token, or other sensitive value; the only account-identifying detail incidentally visible on-screen was the already-known test username from prior phases' own verification reports.

**Correction to the Phase 35 audit, found by tracing the full CSS cascade this phase** (not merely the HTML markup): `landing.html`'s hero contains a photo-panel illustration and 3 floating "quote" callouts in its raw markup, but a later, still-active CSS block (`.hero .hero-visual { visibility: hidden }`, further set to `display: none` at `≤960px` — a breakpoint this app's phone-only target widths are always inside) means **neither element is ever shown on the real site at any mobile width**, and even at desktop widths the markup is replaced by an unrelated, purely decorative background image. This was confirmed by reading the full `<style>` block's cascade, not just the hero's `<section>` markup. Task 2 asked for these elements "if present in the current source" — they are present in the markup but not in what actually renders at this app's target widths, so they were correctly not reproduced; implementing them would have added visual content the real site itself never shows on a phone.

## 10. Remaining parity gaps

- "About Us" and "Ask Buddy" footer links (see §6) — no distinct Flutter destination; documented rather than faked.
- The web's Journey timeline, Choose-Your-Path cards, Feature Grid, testimonials, and Final-CTA sections (all further down `landing.html`, below the sections this phase's task list covered) remain unimplemented — unchanged from before this phase, and out of this phase's explicit scope (hero/cards/logo/colors/trust-strip/footer only).
- The 6 design-token mismatches identified in the Phase 35 visual parity matrix (focus-ring color, `warning`/`border`/`textPrimary` tokens, card radius, outline-button resting border) were **not** addressed this phase — Task 5 explicitly scoped color/token work to the landing page itself, and the hero/cards above already use landing-page-correct colors directly; the broader shared-token question is unchanged and remains a separate decision.
- The richer landing-specific footer is shown to both guest and authenticated-student visitors (matching the real `landing.html` having no footer-specific auth conditional), but is **not** extended to the authenticated-employer home branch, which keeps the pre-existing `AuthenticatedHomeBody`/`PortalHeroCard` design entirely unchanged — correct, since an authenticated employer never reaches `landing.html` on the real site at all (confirmed: `home()` redirects an employer session to `job_home` first).
- Guest-only role pills ("I'm a Job Seeker" / "I'm an Employer", `landing.html:6556-6563`) were not added to the hero — out of this phase's explicit task list, and adding them would require making the shared `HomeHero` widget auth-aware for the first time, a larger change than this phase's scope.

## 11. Confirmation of boundaries respected

- Neither Django reference directory (`Career_Buddy_LMS/`, `royalStaffing_CB01/`) was modified — both remain outside this repository's git root entirely.
- No backend code, API contract, database schema, or migration was touched.
- No authentication, session-handling, environment-configuration, or role-check file was modified (`lib/features/auth/`, `lib/app/config/environment.dart` untouched this phase).
- The debug-preview gate (`kDebugMode` check in `login_screen.dart`) was not touched and is confirmed working unchanged, both in source and live on-device.
- No existing route was removed; no route's destination screen was changed, only 2 button labels and the visible-but-functionally-identical secondary login links described in §5.
- No Play Store upload, deployment, or signing-configuration change was made or attempted; only a local debug build was built and installed for verification.
- All pre-existing uncommitted work from Phases 24-36 remains exactly as it was — confirmed by `git status` before and after this phase showing no unexpected additions or removals beyond this phase's own described changes (plus the 2 incidental, documented, behavior-preserving brace fixes in §3).

## Completion

Per this phase's own scope boundary: stopping here. No Skill-Up gating, free-form Create Resume builder, or any other Phase 35-roadmap item has been started. Awaiting approval before any further phase.
