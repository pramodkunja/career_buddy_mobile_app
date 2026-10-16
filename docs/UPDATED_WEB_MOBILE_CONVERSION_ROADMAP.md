# Updated Web → Mobile Conversion Roadmap (Phase 35)

Target: 27 October 2026. This is the prioritized, phase-wise plan requested by the Phase 35 directive, synthesizing the diagnosis, screen inventory, and both parity matrices produced this phase.

## Executive summary

- **Login timeout — root cause confirmed, fixed.** A debug build's default `EnvironmentConfig` pointed at `10.0.2.2`/`127.0.0.1` (the Android-emulator loopback alias), which is unreachable from a real physical device. Every network call — including login — hung until Dio's 15-second timeout fired, surfacing as the exact reported message, "The request took too long. Please try again." Confirmed via static code trace, a pulled/decompiled APK (debug build markers present, no AOT `libapp.so`), `adb dumpsys package` showing the `DEBUGGABLE` flag, and a live screenshot of the error with a real, previously-verified working account entered. Fix: the no-flag default now resolves to the real, positively-verified production backend instead of the dev address; `ENV=dev` remains available but must be requested explicitly. Full detail and evidence trail: `PHASE_35_LOGIN_AND_DEBUG_PREVIEW_DIAGNOSIS.md`. **Not yet re-verified live on-device after the fix** — the physical device used for diagnosis disconnected before a second test could be run.
- **"Preview Demo (Debug)" button — not a bug.** It is already correctly gated by `kDebugMode`, a Dart compile-time constant that is eliminated entirely from release/profile builds. Its visibility was simply further evidence of the same debug-build root cause above, not a separate defect. No code change was needed or made.
- **Major missing landing-page changes**: the hero's color scheme is inverted relative to the current site (web is light/blue-accent, Flutter is dark-navy/gold); the hero's real-photo-plus-callout visual panel has no Flutter equivalent; the job-seeker/employer section (`PortalCard`) is built against an old, already-removed template rather than the live one; there is no real logo/brand-mark asset anywhere in the app (a generic icon substitutes for it); the landing page's own rich 5-column footer (distinct from the shared site footer, which does match correctly) is not reproduced. Full detail: `UPDATED_WEB_FLUTTER_VISUAL_PARITY_MATRIX.md`.
- **Most significant missing/outdated screens or workflows**: the entire free-form "Create Resume" builder (7 web routes, including signed-in draft persistence) has no Flutter equivalent at all — this is the single largest functional gap on the site, distinct from the already-implemented Manual Resume Builder and AI Resume Parsing features. Client-side Skill-Up free-plan content gating is also missing, which is a reachable broken state for Free-plan users today, not merely cosmetic. Full detail: `UPDATED_WEB_FLUTTER_FUNCTIONAL_PARITY_MATRIX.md` and `UPDATED_WEB_COMPLETE_SCREEN_INVENTORY.md`.
- **What's realistically achievable before 27 Oct 2026**: the P0 login/debug-preview fix is already done. A landing-page visual pass (hero recolor + button label + logo asset swap, the smallest-effort/highest-visibility items) and the Skill-Up gating fix are plausible within the window. The full "Create Resume" builder is a multi-screen feature with new backend-contract verification needs and should be scoped as its own phase rather than rushed — attempting it in the remaining time risks an incomplete, untested feature shipping instead of a polished smaller set of fixes.
- **Verification basis for every finding**: *source-verified* (read directly from the updated Django templates/views/CSS and the current Flutter code) — all findings in both parity matrices and the screen inventory. *Automated-test-verified* — the environment-default fix and its 3 explicit `--dart-define` test runs, plus the full regression suite. *Device-verified* — only the login-timeout symptom itself and the debug-preview button's visibility, captured on one physical Android device before it disconnected; no other screen or fix was device-verified this phase. *Still unverified* — a live re-test of the login fix after the environment-default change; any on-device visual comparison of the landing page or any other screen; Phase 15 items 11, 12, 17, 18 (carried forward, not re-checked this phase); whether the plans/pricing page content is live-sourced or stale.

## Phase-wise plan

### P0 — Login timeout & debug preview (this phase, DONE)

- **Files changed**: `lib/app/config/environment.dart`, `test/app/config/environment_test.dart`.
- **Outcome**: default environment (no `--dart-define=ENV=...`) now resolves to production instead of dev.
- **Tests**: `environment_test.dart` passes under all 3 explicit `ENV` values; full regression suite re-run clean (see Final verification below for the latest count).
- **Device test needed, not yet done**: install a freshly built debug APK with the new default on a physical device and confirm login completes rather than timing out, using only an already-authorized account the user provides — no fabricated credentials.
- **Dependencies**: none — this phase is self-contained and already complete pending the one remaining device re-test.

### P1 — Highest-priority visual and functional gaps

**P1-a: Landing-page hero and brand-asset fixes** (visual, contained, no backend dependency)
- Files: `lib/features/home/presentation/widgets/home_hero.dart`, `lib/app/theme/app_colors.dart` (for the content-vs-chrome palette distinction), `lib/shared/widgets/app_top_bar.dart`, `lib/shared/widgets/app_footer.dart`, plus new asset files for the logo.
- Web reference: `landing.html:22-36, 6536-6608`; logo PNGs from the web's static assets.
- Outcome: hero recolored to the light/blue content palette; CTA label corrected to "Get Started Free"; real logo asset in place of the generic icon.
- Acceptance criteria: hero visually matches the web's color scheme and button copy; logo renders in both top bar and footer; no regression to existing hero navigation/button behavior; existing hero-related tests still pass, new widget test added for button label.
- Device/manual test: visual check on at least one emulator/device.
- Risk/effort: low-medium effort, no backend dependency, low risk.

**P1-b: `PortalCard` rebuild from the live template** (visual + minor copy)
- Files: `lib/features/home/presentation/widgets/portal_card.dart`.
- Web reference: `landing.html:6839-6945` (current — not the removed `templates/home.html:305-513` the widget currently mirrors).
- Outcome: correct headlines/body copy/4-bullet checklists; drop the now-unsupported stat-number bubbles.
- Acceptance criteria: content matches current web copy; existing card tap-navigation behavior unchanged.
- Risk/effort: low effort, low risk, copy-only change plus layout adjustment.

**P1-c: Landing-page footer** (new widget, visual)
- Files: new widget under `lib/features/home/presentation/widgets/`.
- Web reference: `landing.html:7349-7402` (5-column, 18-link footer, distinct from the shared `AppFooter`).
- Outcome: home screen shows the richer landing-specific footer in addition to (or replacing, for the home screen only) the shared footer — needs a product decision on whether both appear or one supersedes the other for this screen; default recommendation is to keep the shared `AppFooter` elsewhere and show this richer one only on the home screen, since that is what the web itself does.
- Risk/effort: medium effort (new component + navigation wiring for 18 links, many of which may route to screens not yet built), low risk.

**P1-d: Skill-Up free-plan content gating**
- Files: likely `lib/features/skill_up/presentation/` controllers/screens, pending a full trace (not yet done this phase — current state is "grep found nothing," not "confirmed absent after full trace").
- Backend dependency: the server-side restriction is confirmed to already exist; this is purely a client-side UX/error-handling gap.
- Outcome: a Free-plan user tapping a gated lesson sees a clear, correctly-worded upgrade/locked state instead of an unhandled error.
- Acceptance criteria: gated content shows a clear locked state; ungated content unaffected; a focused test added once the exact current failure mode is confirmed.
- Risk/effort: effort depends on findings of the not-yet-done full trace — should be scoped as its own small investigation step before implementation.

**P1-e: The "Create Resume" free-form builder** — scope as its own dedicated phase, not squeezed into this one
- Files: new feature directory, e.g. `lib/features/create_resume/` (domain/data/presentation layers, mirroring existing feature structure).
- Backend contract to verify first: `career_app/create_resume_views.py`'s 7 routes — request/response shapes for preview, PDF generation, page data, and the 4 draft-CRUD endpoints (`ResumeDraft` model).
- Acceptance criteria: free-form section editing, live preview, PDF export, and signed-in draft save/list/load/delete all work against the real (not invented) backend contract; existing Manual Resume Builder and AI Parsing flows unaffected; the home-screen choice-sheet (Phase 34) updated to include this third option once built.
- Device/manual test: full flow test with an authorized account once available.
- Dependencies: none blocking, but large enough that it should not start without explicit approval given the deadline.
- Risk/effort: **high** — a genuinely new, multi-screen feature with its own persistence model; the biggest single risk to the 27 Oct deadline if attempted carelessly.

### P2 — Secondary gaps

| Item | Files/area | Backend dependency | Effort/risk |
|---|---|---|---|
| Streaming TTS for Aria/Buddy | voice feature's TTS call site | Swap to `/api/voice/tts/stream/`, already live | Low-medium effort; real UX improvement (latency) |
| Design-token mismatches (focus ring, warning/border/textPrimary colors, card radius) | `app_theme.dart`, `app_colors.dart` | None | Low effort, low risk, mostly a product confirmation question first |
| Career-track landing pages | new screens | None (public content) | Medium effort, low priority (marketing content) |
| Resume-apply-via-parsed-data | resume feature | `resume_apply_job` endpoint | Medium effort |
| Plans/pricing content verification | subscription screens | Verify `pro_page` content sourcing | Low effort investigation first |
| GST payment invoice download | payment history area | `payment_invoice` endpoint | Low-medium effort |

### P3 — Low-priority / minor

Exercise-attempt deletion, certificate edit-name sub-flow confirmation, trust-strip below hero. None of these block core functionality or visual credibility.

### Final verification (ongoing, repeat before any release)

- Re-run `flutter analyze` and the full `flutter test` suite after every phase above. Freshly re-run at the end of this phase (2026-10-16): **2299 tests passing, 0 failing, 7 analyzer warnings** (same pre-existing warnings as every prior phase — no new issues introduced). The small shift down from the pre-Phase-35 baseline is a documented, explained structural artifact of asymmetric branch test counts between the old `dev`-default and new `production`-default test file, not a coverage loss — both branches' tests still exist and pass under their respective explicit `--dart-define` runs (see the diagnosis report for detail).
- Device/auth/visual re-check once a physical device is available again: re-test login with the new default; visually compare the landing page once P1-a/b/c land; confirm Skill-Up gating once P1-d lands.
- Do not claim "100% parity," "fully working," or "all screens verified" at any point — report exactly what was source-verified, test-verified, or device-verified, and name what remains open, as this document and its companions do throughout.

## Explicit scope note on "not everything needs a 1:1 port"

Several web-only, server-side, or desktop-navigation-only routes are intentionally not planned for any mobile phase: Django admin, the `nav_go` desktop-menu shim, protected-media internal serving routes, the Razorpay server-to-server webhook, and the dev-only pro-status toggle. These are correctly out of scope for a native mobile client and are not tracked as gaps anywhere in this roadmap or its companion documents.

## Stop point

Per the Phase 35 directive's own instructions, this phase stops here for review. No P1+ implementation (landing-page rebuild, Create Resume builder, design-token fixes, Skill-Up gating, or any other item above) has been started. Awaiting explicit approval before beginning any of the phases listed above, and in particular before starting P1-e given its size relative to the deadline.
