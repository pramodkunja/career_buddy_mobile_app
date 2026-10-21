# Landing Page — Complete Web-to-Mobile Parity Report

## 1. Source files and reference sections inspected

**Visual reference**: `CareerBuddy – Learn. Grow. Get Hired.pdf` (supplied by the user) — read in full, then rendered page-by-page at 3x resolution (PyMuPDF, since this environment has no `pdftoppm`/poppler) and inspected in 24 vertical slices. The PDF turned out to be actual mobile-width screenshots of the live site (not a desktop mockup), which made it a direct visual ground truth rather than something to interpret.

**Web source** (`royalStaffing_CB01`, read-only): `templates/landing.html` (hero through footer, every section's markup read directly — line ranges cited in each new widget's own doc comment), `core/navigation.py` (the `nav_go` gateway's full `NAV_MAP`, used to source every new CTA's real destination rather than guessing), `templates/includes/site_nav.html`.

**Prior Flutter work inspected**: `docs/PHASE_40_CB_CHANGES_COMPLETE_PARITY_MATRIX.md`/`_IMPLEMENTATION_ROADMAP.md`/`_AUDIT_REPORT.md`, `docs/PHASE_37_LANDING_PAGE_UI_REBUILD_REPORT.md` (the actual Phase 37 report — no file named `PHASE_37_LANDING_PAGE_REPORT.md` exists, confirmed by listing `docs/`), the existing `lib/features/home/presentation/**` source (not assumed complete — read in full before changing anything), and the current `docs/PHASE_42_CREATE_RESUME_GUEST_SAVE_REPORT.md` (preserved; see §4).

## 2. Sections found, initial state, and final state

| Section (checklist ref) | Initial state (before this phase) | Final state |
|---|---|---|
| A. Header and hero | Mostly present (Phase 37): logo, hero heading/description, 3 CTAs, trust strip. Missing: the 2 "I'm a Job Seeker"/"I'm an Employer" role pills (explicitly flagged as a gap in Phase 37's own report). | Role pills added, routed to the same registration destinations the real pills use. Everything else unchanged. |
| B. Platform overview | Missing entirely. | Implemented — 6 cards, real copy, real per-card destinations sourced from `core/navigation.py`'s `NAV_MAP`. |
| C. Career journey | Missing entirely. | Implemented — 6-step horizontal scroller (Learn → Practice → Build Profile → Prepare → Find Opportunities → Apply & Grow), matching the real site's own horizontally-scrolling layout. |
| D. Choose Your Path | Missing entirely. | Implemented — 2 cards (IT / Non-IT Job Seeker), real copy. |
| E. Job-seeker / Employer sections | Already implemented (Phase 37), confirmed still correct and unchanged by this phase. | Unchanged. |
| F. (Employer, part of E above) | Already implemented. | Unchanged. |
| G. Skill Up | Missing entirely (only a nav-drawer link existed). | Implemented — 8-row list (7 categories + Browse All), each routed to its real `NAV_MAP` destination. |
| H. Resume and AI | Missing entirely. | Implemented by reusing the existing `PortalCard` widget (the real `#resume` section uses the identical `.story` layout as `#job-seeker`/`#employer`) — no new visual component needed. |
| I. Meet Buddy | Missing entirely. | Implemented — 6-card grid + a real, working "Ask Buddy" button that opens the actual chat panel. |
| J. About CareerBuddy | Missing entirely. | Implemented — 8 numbered cards with the real cycling accent-color top borders. |
| K. Resume maker | Missing entirely. | Implemented as a **teaser** (template chips + description + a "Create Resume" button into the real, already-built full-screen builder) — the real web embeds the full interactive builder inline; this phase deliberately does not duplicate that builder a second time on the landing page (see §4). |
| L. Tutorials | Missing entirely. | Implemented — journey-step chips, 9 "What can you do with CareerBuddy?" cards, 5 **real** featured tutorial videos (see §6 for live playback verification). |
| M. Testimonials | Missing entirely. | Implemented — 3 job-seeker + 3 employer testimonial cards, verbatim real content. |
| N. Footer and floating assistant | Footer already implemented (Phase 37); "Ask Buddy" and "About Us" were explicitly left out as "no distinct Flutter screen." | "Ask Buddy" now added to the footer's Company column, wired to the same working chat-panel trigger as the new Meet Buddy section. "About Us" still intentionally omitted (see §8). |

## 3. Files changed and why

**New files** (`lib/features/home/presentation/widgets/`): `home_section_header.dart` (shared eyebrow/heading pattern, reused by 7 new sections), `home_feature_grid.dart` (shared card grid, reused by Platform Overview and Meet Buddy — both use the real site's identical `.feature-card` markup), `home_platform_overview.dart`, `home_career_journey.dart`, `home_choose_path.dart`, `home_skill_up_teaser.dart`, `home_meet_buddy_section.dart`, `home_about_section.dart`, `home_resume_maker_teaser.dart`, `home_tutorials_section.dart`, `home_tutorial_video_dialog.dart` (plays the 5 real tutorial videos). New file `lib/features/home/domain/home_tutorial_video_url.dart` (the real static-file URL pattern, mirroring the existing `skill_up_lesson_url.dart` convention).

**Modified files**: `home_hero.dart` (added the 2 role pills), `public_home_body.dart` (composes all new sections, in the real page's own order), `home_landing_footer.dart` (added the "Ask Buddy" link; converted to `ConsumerWidget` to reach the new trigger), `home_screen.dart` (wires the new `onAskBuddy` callback), `shared/widgets/buddy_chatbot_overlay.dart` (added `buddyOverlayOpenRequestProvider`, a small Riverpod `Notifier<int>` that lets the new "Meet Buddy"/"Ask Buddy" buttons open the *existing* chat panel from elsewhere on the page — see its own doc comment for why this was the correct minimal mechanism rather than duplicating chat-panel logic).

**Phase 42 preserved, untouched**: `create_resume_builder_controller.dart`, `create_resume_builder_screen.dart`, `resume_providers.dart`, and the 3 new Phase 42 data/domain files remain exactly as that phase left them — confirmed via `git status` before and after this phase's work, and the guest-save fix was exercised live during this phase's own interaction testing (§6) without any regression.

**Test files**: `test/features/home/presentation/screens/home_screen_test.dart` — 5 pre-existing tests updated to use `.first`/`.last`/`ensureVisible` where the new content legitimately introduced duplicate text or pushed existing elements further down the page (documented inline in each change, not a silent weakening — every updated assertion still checks the same real behavior it always did); 5 new tests added covering the new sections' presence and 4 of their interactions. `test/app/client_flow_test.dart` — 1 line added (`ensureVisible`) for the same reason, no assertion changed.

## 4. Visual changes made

Every new section's colors, icons, and copy were sourced directly from the real markup's literal values (inline `style="background:...;color:..."` hex codes, not approximated) — documented with exact citations in each widget's own doc comment. Reused the existing `AppColors`/`AppSpacing`/`AppRadius` tokens and the existing `PortalCard`/`HomeSectionHeader` patterns throughout rather than introducing a parallel style system. No dark-mode work, no new animation, no decorative gradients beyond what the hero/footer already had from Phase 37.

**Deliberate fidelity decisions** (not literal 1:1 reproductions, each justified):
- The real `.jr-steps` journey uses looping GIF illustrations (`static/img/journey/*.gif`); reproduced as colored icon circles instead, matching this app's existing convention (every other section already uses Material icons, not downloaded web illustration assets).
- The real Choose-Your-Path/Resume-maker/Resources sections' exact pixel decorations (e.g. the resume-maker's live interactive form) were intentionally not pixel-cloned — see §8's explicit scope decisions.

## 5. Functionality and navigation verified

All of the following were tested **live on the running emulator** (not just source-read or unit-tested), as a guest (no account used or fabricated):

| Action | Verified destination |
|---|---|
| Get Started Free | Real "Create Account" registration screen |
| Create Resume (hero) | Real Create Resume builder, reachable with no login |
| Create Resume (new resume-maker teaser) | Same real builder |
| Find Jobs | Redirects to real Login screen (dashboard is auth-protected — correct, matches the real web's own `@login_required`) |
| Check Your Resume (Platform Overview + Resume & AI card) | Redirects to real Login screen (resume parsing is auth-protected) |
| IT Job Seeker (Choose Your Path) | Redirects to real Login screen (Role Picker is auth-protected in this app — a documented, pre-existing stricter-than-web posture, not introduced by this phase) |
| Ask Buddy (Meet Buddy section) | Opens the real chat panel — **confirmed via a live debug trace that the actual provider/listener chain fires correctly** (see §9 for why this needed extra verification) |
| Featured Tutorial card ("How to Create Your Resume") | Opens the video dialog and **plays the real production video live over the network** — confirmed by the decoded frame showing the real recorded walkthrough (sample resume "Riya Sharma", step 1/9 progress bar) |
| Hamburger menu → nav drawer | Opens correctly, unchanged guest items (Home / Job Seeker Login / Employer Login) |
| Full-suite automated tests | Skill Up row → Activities screen; IT Job Seeker → Role Picker; Ask Buddy → chat panel open; Featured Tutorial → dialog opens (see `home_screen_test.dart`'s new "landing-page parity — new sections" group) |

No restricted/authenticated-only flow was tested with a real account — none of this phase's new content requires one; every guest-reachable destination above was confirmed to either open correctly or correctly redirect to Login, with no authentication bypassed.

## 6. Tests executed and actual results

```
flutter test test/features/home/                                → 69/69 passing
flutter test test/features/home/presentation/screens/home_screen_test.dart → 28/28 passing
flutter test test/app/client_flow_test.dart                     → 4/4 passing
flutter test (full suite)                                       → 2380 passing, 0 failing
flutter analyze                                                 → 8 issues — identical to the pre-Phase-42 baseline, none new
```

**Baseline comparison** (stated baseline: 2,375 passing / 0 failing / 8 analyzer issues, after Phase 42): net **+5** tests, all in `home_screen_test.dart`'s new section-coverage group. No existing test was deleted or had its assertions weakened — the 5 pre-existing tests touched were updated only to add `.first`/`.last`/`ensureVisible` where new, legitimate content now shares a label or sits further down the page; each still asserts exactly the same real behavior it did before (documented inline at each change).

**Real bugs found and fixed during this phase's own work** (not device-specific — these were genuine layout bugs caught before reaching the emulator):
- A `RenderFlex` horizontal overflow in `home_feature_grid.dart`'s action-link row, for longer labels like "Start a mock interview" — fixed by wrapping the label in `Flexible`.
- A `RenderFlex` vertical overflow in `home_career_journey.dart`'s step column at certain text-scale factors — fixed by increasing the scroller's fixed height.

## 7. Emulator/device details and installation

- **Device**: `emulator-5554`, "sdk gphone16k arm64", Android 17 (API 37), screen 1080×2424 @ 420dpi.
- **Storage**: confirmed via `adb shell df /data` — 92-93% full throughout this session (consistent with the history noted in the task: Phase 39/42 both hit `INSUFFICIENT_STORAGE` here). **Non-destructive remedy used**: uninstalling this app's own previous debug build (`adb uninstall com.sriainfotech.career_buddy_lms`) before each fresh install — this is routine app-update housekeeping, not a wipe of emulator or user data, and was explicitly not a factory reset/recreate of the AVD. This freed ~250MB each time, enough to install the ~180MB debug APK. The emulator's own data (other than this one app's prior install) was never touched.
- **Installation**: succeeded twice this phase (once for the main implementation, once after adding temporary diagnostic logging — see §9). Both installs were followed by a cold `force-stop` + relaunch (not just bringing an existing process to the foreground) before taking the first "hero" screenshot, to guarantee the screenshots reflect an actual fresh launch of the current build, not stale in-memory state.
- **Startup check**: `adb logcat` was captured across the full session (launch, scrolling, every tap) and contains zero Flutter exceptions, zero `FATAL`, and zero asset-loading errors — only one unrelated system-level `NullBinder` log line present on every Android emulator boot, confirmed unrelated to this app.

## 8. Screenshots captured and where they are stored

16 representative screenshots (of the full working set captured during verification) are saved at:

`/private/tmp/claude-501/-Users-kunjapramodmahajan-Flutter-Projects-Career-Buddy-LMS/c536c444-170e-4e2d-b1fa-059604770772/scratchpad/phase_landing_parity_screenshots/`

These are session-scratchpad files (raw `adb exec-out screencap` PNGs), not committed to the Flutter project's own repository — consistent with this project's existing convention of not checking device-screenshot binaries into source control.

| File | Shows |
|---|---|
| `01_hero.png` | Header, hero, trust strip (cold launch) |
| `03_platform_cards.png` | Platform Overview + start of Career Journey |
| `04b_choose_path_cards.png` | Choose Your Path cards + start of Job Seeker section |
| `05_employer.png` | Job Seeker story panel + start of Employer section |
| `06_meet_buddy.png` | Meet Buddy cards |
| `07_about.png` | About CareerBuddy cards + Resume maker teaser |
| `08_testimonials.png` | A testimonial card + footer start |
| `09_footer_bottom.png` | Full footer incl. new "Ask Buddy" link |
| `23_find_featured.png` | Featured Tutorials cards |
| `24_video_dialog.png` | **Live** tutorial video playing a real decoded frame |
| `debug_after_tap2.png` | Ask Buddy → chat panel opened live |
| `10_tap_get_started.png`, `11_tap_create_resume.png`, `12_tap_it_job_seeker.png`, `14_check_your_resume.png` | Navigation-result screens for each tested CTA |
| `calibrate_drawer.png` | Mobile nav drawer open |

## 9. Remaining visual mismatches and unsupported web-only behavior

- **Floating Buddy overlay visually overlaps some new section content** (e.g. the Platform Overview heading, Meet Buddy's own cards) at the exact scroll position where the launcher happens to sit. This is pre-existing `BuddyChatbotOverlay` positioning (`right:10,bottom:15`, unchanged by this phase) — it does the same thing on every other screen in the app, not something introduced by the new sections. Not fixed here: repositioning a heavily-tested, app-wide shared widget was out of this phase's scope (landing-page sections only) and carries real regression risk across dozens of other screens.
- **Footer copyright line crowding**: at some widths the "© 2026 CareerBuddy..." and "careerbuddy4u.com" texts (a pre-existing Phase 37 `Wrap` with `spaceBetween`) sit close together with little visual gap. Minor, pre-existing, not touched.
- **Choose Your Path / IT & Non-IT cards both open the same generic Role Picker**, not a literal department-by-department browsing experience the way the real web's `/careers/it/`, `/careers/non-it/` pages do. This is the same, already-documented Phase 40 finding (the real department/role-browsing home-page entry point has no Flutter equivalent yet — planned separately as Phase 43) — this phase's cards correctly point at the closest existing, justified destination rather than inventing new browsing UI.
- **"Skills" is not wired from these new sections**: consistent with the existing, already-documented, honest "Coming soon" state in the Role Picker's own action sheet (a prior, separate phase's decision) — not something this phase touched or needed to re-decide.
- **"About Us" footer link remains unreproduced** — it is a same-page anchor on the real site; this app has no in-page footer-to-section-scroll mechanism, and the content itself is already fully present earlier on the same scrollable page via the new About CareerBuddy section.
- Of the real `careerBuddyTutorials` array's 37 entries, only the 5 with a real file on disk are reproduced — the other 32 (which the real site itself shows as "coming soon" placeholders) are intentionally not built, per the task's own "do not pretend unavailable media is playable" instruction.

## 10. Environmental limitations and what was blocked

- No authenticated test account was used or fabricated — every new section this phase adds is guest-facing by design (matching the existing `PublicHomeBody`/`AuthenticatedHomeBody` split Phase 37 already established), so nothing in this phase's scope required one.
- A genuine mid-session debugging detour is worth disclosing plainly rather than smoothing over: several manual `adb shell input tap` coordinate estimates (made by eye against the Read tool's scaled screenshot preview) were initially off by 100-200 physical pixels for the "Ask Buddy" button specifically, which looked at first like the new `buddyOverlayOpenRequestProvider` mechanism might not work on-device despite its passing unit test. This was resolved conclusively — not assumed away — by programmatically scanning the actual screenshot's pixel data (Python/PIL) for the button's real on-screen bounding box, then adding temporary `debugPrint` diagnostics (removed before the final build) that confirmed the real tap→provider→panel chain fires correctly. The final, reported "Ask Buddy" and tutorial-video verifications in §5/§6 reflect the corrected coordinates and are genuine, confirmed results, not the earlier misleading negative ones.
- No `pdftoppm`/poppler was available in this environment for rendering the reference PDF; `pymupdf` was installed via `pip3` and used instead, with no other change to the environment.

## Completion

Per this task's own definition of done: all applicable sections (A-N) are implemented and reachable from the real running app; existing navigation/access rules are intact and were verified not to be bypassed; the full page was inspected end-to-end via emulator screenshots; the two genuine layout bugs found during inspection were corrected and re-verified; the required navigation actions were checked live on the emulator; the full automated suite and analyzer were run and compared against baseline; remaining gaps are documented above rather than hidden. Stopping here per this task's own instruction — waiting for the next instruction before any further phase.
