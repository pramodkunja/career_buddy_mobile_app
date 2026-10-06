# Career Buddy LMS — Web Static Content Inventory

Every hardcoded/static content source found in the web application during
Phase 0 discovery, and whether Flutter reproduces it exactly, partially,
not at all, or fetches it dynamically instead.

**Web source modified: NO.**

| Content source | Web location | Flutter location | Reproduction |
|---|---|---|---|
| Grammar topics (9: noun, pronoun, verb, adjective, adverb, conjunction, tenses, sentence-structure, types-of-sentences) — full text: definitions, role_items, summary tables, rule boxes, examples, practice exercises | `subject_views.py` `SUBJECT_TOPICS`/`SUBJECT_TOPIC_CARDS` | `assets/data/grammar_data.json` | **Exact** — field-for-field match confirmed, all 9 topics present (contrary to the initial assumption that this list might be incomplete) |
| Grammar slide images (PNG decks, one per topic) | `protected_media/subjectslides/<slug>/*.png` | Fetched dynamically via `ApiEndpoints.subjectSlideImage` | Dynamic (correct — these are real per-account-agnostic static assets served by the same authenticated endpoint on both platforms) |
| Grammar videos (mp4, one per topic) | `protected_media/subjectvideos/<slug>.mp4` | Fetched dynamically via `ApiEndpoints.subjectVideo` | Dynamic |
| Skill-Up hero stats (48/3/3/100%, hardcoded copy) | Static SPA `static/001 Career Buddy/index.html` | `skill_up_data.dart` (`heroStats`) | **Exact**, byte-identical confirmed |
| Skill-Up content tree (3 sections, 19 subsections, ~64 lesson cards) | Same static SPA, parsed live for counts | `skill_up_data.dart` (hand-transcribed) | **Partial / at-risk** — Flutter's copy is manually maintained, not derived. The Django side has `riya_bot/skillup_catalog.py` specifically built to avoid this exact problem (auto-parses the real SPA for the chatbot); Flutter has no equivalent auto-sync. A future lesson add/rename/remove on the web will silently desync `skill_up_data.dart` unless updated by hand. Also: Flutter's own doc comment claims "48" lesson pages; a direct count of the real SPA found 64 — worth reconciling. |
| Resume templates (3: Modern Professional, Executive Tech, Minimalist Career — static downloadable `.docx` files + preview images) | `resume_match_result.html:312-455` | `_ResumeTemplatesSection` (`resume_builder_screen.dart`) | **Exact** — same 3 templates, same asset filenames/paths, confirmed 1:1 |
| Login/registration page branding copy ("Welcome Back!", feature checklist, etc.) | `templates/users/login.html`, `register.html` | `login_screen.dart`, `register_screen.dart` | **Exact**, hand-transcribed with pixel-parity doc comments cross-checked against `style.css` |
| Roleplay topic config (`TOPIC_PRACTICE_CONFIG`: Storytelling/Situations/Roleplay cards) | `riya_bot` config, rendered by `roleplay_home.html` | `RoleplayTopicsData` (`roleplay_topics_data.dart`) | **Exact**, static bundled data matching the web's own static config |
| JAM curated topics (easy/medium/hard) | `templates/jam/topics.html`, backed by `Topic` model (dynamic DB rows, not hardcoded) | fetched dynamically via `jamTopics` endpoint | Dynamic (correct — these are real DB-backed, not static web content) |
| Mock test question banks (OOP, 24 subjects, AMCAT, CoCubes) | Static HTML pages under `static/.../TechCenter/` + JSON question endpoints | Fetched dynamically via the real `{oop-quiz,quiz,amcat,cocubes}/questions/` endpoints | Dynamic (correct) |
| Certifications subject list (~27 subjects across English/Aptitude/Tech) | `skillup_assessment/subjects.py` | Fetched dynamically via `certificationsStatus` API | Dynamic (correct) |
| Footer copy ("Master Business English for the global workplace", "Activities / Sub-Activities / Interactive Exercises" strip, copyright) | `templates/base.html:249-281` | Not found as a distinct Flutter widget | **Not reproduced** — minor, cosmetic; not a functional gap |
| Navbar brand mark (SVG logo + "Career Buddy" wordmark) | `templates/base.html:91-101` | `login_screen.dart`'s `_BrandingPane`, `app_nav_drawer.dart` header | **Exact** |
| Employer registration industry choices (8 options) | `accounts_app/forms.py` | `kEmployerIndustryOptions` | **Exact** |
| Student registration choice lists (gender, education level, blood group, industry — 4 separate lists) | `users/models.py` `GENDER_CHOICES`/`EDUCATION_CHOICES`/`BLOOD_GROUP_CHOICES`/`INDUSTRY_CHOICES` | `student_registration_data.dart` (`kGenderOptions` etc.) | **Exact**, verbatim value/label pairs |
| Password complexity rules (live checklist: 8 chars, upper/lower/number/special/no-common) | `templates/includes/password_requirements.html` + `users/password_validators.py` | `Validators.employerPassword`, `_PasswordRequirements` widget (reset-password screen) | **Exact** |
| Subscription plan pricing/copy (Free/Normal ₹499/Pro ₹999) | `templates/pro.html` | Not found — `/pro/` is entirely unimplemented | **Not reproduced** (tracked under the Subscriptions gap in `WEB_API_INVENTORY.md`) |
| Dashboard Quick Start category chips (7: Speaking/Writing/Vocabulary/Negotiation/Communication/Analysis/Workshop) | `templates/dashboard.html:282-304` | `quick_start_section.dart` | Believed exact (built in an earlier batch per the dashboard plan) — not re-verified line-by-line this pass |
| Subscription-expiry notice modal copy | `templates/base.html:289-343` | Not found | **Not reproduced** — site-wide modal shown when a plan is expired/expiring soon; no Flutter equivalent identified |

## Summary

- **Exact reproduction confirmed**: Grammar (all 9 topics), Skill-Up hero stats, resume templates, login/registration branding, roleplay topics, all registration/profile choice lists, password rules, navbar brand mark, employer industry list.
- **Dynamic (correctly not hardcoded)**: grammar media, JAM topics, mock test question banks, certification subjects — all correctly fetched live rather than duplicated as static content.
- **Partial / at-risk**: Skill-Up's lesson tree (`skill_up_data.dart`) — manually maintained with no auto-sync mechanism, unlike the web's own chatbot-facing catalog.
- **Not reproduced**: footer copy, subscription plan pricing/copy, subscription-expiry notice modal — all minor/cosmetic except the subscription pricing, which is already tracked as part of the larger Subscriptions/Payments gap.

**Web source modified: NO.**
