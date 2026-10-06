# Career Buddy LMS — Complete Static Data Parity

Supersedes `WEB_STATIC_CONTENT_INVENTORY.md` as the authoritative record
(that file remains as supporting history). Every hardcoded web content
source found during discovery, with its exact Flutter source and whether
the match was independently re-verified for this document.

**Web source modified: NO.**

| Content | Web Source | Flutter Source | Match Status | Note |
|---|---|---|---|---|
| Grammar — 9 topics, full text (definitions, role_items, summary tables, rule boxes, examples, practice exercises) | `subject_views.py` `SUBJECT_TOPICS`/`SUBJECT_TOPIC_CARDS` | `assets/data/grammar_data.json` | **Exact match, re-verified this document** via a fresh, full-file (not excerpted) programmatic scan confirming exactly 9 unique topic slugs | Previously the single most-suspected under-count; now conclusively closed |
| Grammar media (slides/video) | `protected_media/subjectslides/`, `subjectvideos/` | Fetched dynamically | Correctly dynamic, not static-duplicated | — |
| Skill-Up hero stats (48/3/3/100%) | Static SPA `index.html` | `skill_up_data.dart` | Exact, byte-identical | — |
| Skill-Up lesson catalog (3 sections / 19 subsections / ~64 lesson cards) | Same static SPA | `skill_up_data.dart` (hand-transcribed) | **Partial / at-risk** | No auto-sync mechanism, unlike the web's own `riya_bot/skillup_catalog.py` built specifically to avoid this; a lesson add/rename/remove on web will silently desync Flutter. Also an unreconciled count discrepancy: Flutter's own doc comment says "48" pages, a direct SPA parse found 64 |
| Resume templates (3: Modern Professional, Executive Tech, Minimalist Career) | `resume_match_result.html:312-455` | `_ResumeTemplatesSection` | Exact — confirmed exactly 3 exist on web, exactly 3 in Flutter | Not a rich template gallery on either side — the web itself is an analyzer with 3 static downloads, not a from-scratch builder |
| Login/registration branding copy | `templates/users/login.html`, `register.html` | `login_screen.dart`, `register_screen.dart` | Exact, pixel-parity doc comments cross-checked against `style.css` | — |
| Roleplay topic config (Storytelling/Situations/Roleplay) | `riya_bot` `TOPIC_PRACTICE_CONFIG` | `roleplay_topics_data.dart` | Exact, static-to-static match | — |
| JAM topics, mock-test question banks, certification subjects | DB-backed (dynamic) | Fetched dynamically | Correctly dynamic | Not static content on either side — confirmed these are real DB rows, not hardcoded |
| Footer copy ("Master Business English...", Activities/Sub-Activities/Interactive-Exercises strip, copyright) | `templates/base.html:249-281` | Not found as a distinct widget | **Not reproduced** | Minor, cosmetic |
| Navbar brand mark (SVG + wordmark) | `templates/base.html:91-101` | `login_screen.dart`'s `_BrandingPane`, `app_nav_drawer.dart` | Exact | — |
| Registration/Profile choice lists (gender, education level, blood group, industry) | `users/models.py` (4 `*_CHOICES` lists) | `student_registration_data.dart` | Exact, verbatim value/label pairs | Cross-checked field-for-field this session while building Registration/Profile |
| Employer industry list (8 options) | `accounts_app/forms.py` | `kEmployerIndustryOptions` | Exact | — |
| Password complexity rules (8 chars, upper/lower/number/special/no-common) | `templates/includes/password_requirements.html`, `users/password_validators.py` | `Validators.employerPassword`, `_PasswordRequirements` widget | Exact | — |
| Dashboard Quick Start chips (7 categories) | `templates/dashboard.html:282-304` | `quick_start_section.dart` | Believed exact (built in an earlier batch) | **Not re-verified this pass** — flagging the gap in confidence honestly rather than claiming MATCH without evidence |
| Subscription plan pricing/copy | `templates/pro.html` | None — `/pro/` unimplemented | **Not reproduced** | Tracked as part of the larger Subscriptions gap |
| Subscription-expiry notice modal copy | `templates/base.html:289-343` | None found | **Not reproduced** | Site-wide modal, no Flutter equivalent identified |

## Items the web obtains dynamically (confirmed NOT hand-copied into Flutter as static content — correct behavior)

- Grammar slide/video assets (served via authenticated endpoints both sides).
- JAM curated topics (real DB `Topic` rows).
- Mock test question banks (real JSON endpoints, randomized server-side).
- Certification subject list and per-subject state (real API).
- Employer/job data (real HTML-scraped from live pages, not fabricated).

Where the web gets a value from the backend, Flutter gets it from the same
backend source in every case checked — no instance was found this session
of Flutter silently hardcoding a value the web computes dynamically.

**Web source modified: NO.**
