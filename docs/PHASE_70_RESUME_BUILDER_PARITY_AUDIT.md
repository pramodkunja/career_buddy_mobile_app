# Phase 70 — Create Resume Builder Parity Audit

**Scope.** Fresh, source-backed re-inspection of the updated Django website's Create Resume
builder against the Flutter builder's actual current implementation (not the Phase 67 audit's
findings, which this phase was told not to assume are still accurate). Investigation covered
the full Flutter implementation (`lib/features/resume/{domain,presentation}/.../create_resume_*`)
and the updated Django reference (`royalStaffing_CB01/career_app/create_resume.py`,
`royalStaffing_CB01/career_app/create_resume_views.py`, `royalStaffing_CB01/static/js/create_resume.js`).
The `Career_Buddy_LMS` (original, pre-update) reference was not needed — nothing here was
ambiguous enough to require it. Both Django reference trees were read only, never modified.

**Key structural finding.** The real website has no static HTML template for this builder —
`templates/landing.html`'s `#create-resume` div is an empty shell filled entirely by
`static/js/create_resume.js` (836 lines) via `innerHTML`. `career_app/create_resume_views.py`
(196 lines) is pure JSON API (`preview_api`, `pdf_download`, `pages_api`,
`drafts_list/detail/save/delete`) — no view renders resume-builder markup. The JS file is
therefore the authoritative "template" for field labels/order/types, cross-referenced with
`career_app/create_resume.py` for server-side `normalize()`/`validate()`/`build_document()`
logic and the `SECTIONS`/`REPEATABLE`/`ENTRY_FIELDS`/`ENTRY_REQUIRED`/`ADDITIONAL_FIELDS`/
`SECTION_OF`/`END_REQUIRED` tuples.

The real site has exactly **10 top-level tabs**, not the "5 implemented + 7 missing" the
Phase 67 audit described — because **Internships & Volunteering share one tab** (two
repeatable lists under two sub-headings) and **Languages & Additional Information share
another** (a repeatable list + 6 flat fields). The 7 section names in this phase's brief are
real, but they map onto **5 new tabs**, not 7. Building 7 separate top-level steps would
have invented a tab structure the website doesn't have; this implementation follows the
site's actual 5-new-tab structure instead.

## Parity matrix — all 10 sections

| # | Website heading (`create_resume.js`) | Source | Fields (order) | Required | Multi-entry | Flutter construct | Status |
|---|---|---|---|---|---|---|---|
| 1 | Personal Information | `create_resume.js:343-355`, `create_resume.py:54-63,105-108` | name\*, title\*, email\*, phone\*, city\*, state\*, country\*, linkedin, github, portfolio, website, **profile_url** ("Professional profile URL"), address | name/title/email/phone/city/state/country | single (`CreateResumePersonalInfo`) | `create_resume_personal_step.dart` | **Was PARTIAL → now MATCHED.** `profile_url` existed in the server contract and the real site's own form but was entirely absent from `CreateResumePersonalInfo` — a genuine, newly-found gap in a section the Phase 67 audit had called "matched". Added field (`create_resume_state.dart`), `toJson`/`fromJson`, and the form field (`create_resume_personal_step.dart`), positioned after Website exactly as the site orders it. |
| 2 | Professional Summary | `create_resume.js:356-358`, `create_resume.py:37-38,281-286` | single textarea, 1200 char max | none (min 50 chars only if non-empty) | n/a | `create_resume_summary_step.dart` | MATCHED (unchanged; re-verified, no drift) |
| 3 | Work Experience | `create_resume.js:91-94`, `create_resume.py:64-69,110-112,128-129` | company\*, title\*, type, location, department, start/end month+year + current, responsibilities\*, projects, achievements, tools | company, title, start_year | repeatable (≤20) | `create_resume_experience_step.dart` | MATCHED (unchanged; re-verified field-for-field, no drift) |
| 4 | Education | `create_resume.js:95-98`, `create_resume.py:70-73,113-114,130` | qualification\*, degree, specialization, institution\*, location, start/end year + current, grade, coursework, achievements | institution | repeatable (≤20) | `create_resume_education_step.dart` | MATCHED (unchanged; re-verified, no drift) |
| 5 | Skills | `create_resume.js:66-71` | 4 categories: technical/functional/soft/tools, chip list, comma-split add | none | n/a | `create_resume_skills_step.dart` | MATCHED at the data-model level (`CreateResumeSkills`, 4 keys unchanged). Widget-level reorder/edit-in-place interaction not re-audited this phase (out of this phase's named scope). |
| 6 | Projects | `create_resume.js:99-102`, `create_resume.py:74-77,115-116,131` | title\*, type, organization, start/end month+year + "Ongoing project", overview, role, url, responsibilities, technologies, outcomes | title | repeatable (≤20) | **NEW** `create_resume_projects_step.dart` | **Was MISSING → IMPLEMENTED.** All 11 fields, exact order, `current` flag for ongoing projects. |
| 7 | Certifications & Training | `create_resume.js:103-105`, `create_resume.py:78-79,117-118,132` | name\*, issuer\*, credential_id, issue month+year, expiry month+year, url, description | name, issuer | repeatable (≤20) | **NEW** `create_resume_certifications_step.dart` | **Was MISSING → IMPLEMENTED.** No "current" flag — certifications have no ongoing state, matching the real site. |
| 8 | Achievements & Awards | `create_resume.js:106-107`, `create_resume.py:80-81,119,133` | title\*, organization, month+year, description, url | title | repeatable (≤20) | **NEW** `create_resume_achievements_step.dart` | **Was MISSING → IMPLEMENTED.** |
| 9a | Internships & Volunteering → **Internships** sub-section | `create_resume.js:108-111,384`, `create_resume.py:82-85,120-121,134` | organization\*, title\*, location, start/end month+year + "Ongoing internship", responsibilities, projects, skills, achievements | organization, title, start_year | repeatable (≤20) | **NEW** `create_resume_internships_volunteering_step.dart` (`CreateResumeInternshipsVolunteeringStep`) | **Was MISSING → IMPLEMENTED.** Rendered under an "Internships" sub-heading inside the combined tab, matching the site exactly. End-date-required-unless-ongoing rule noted (server-enforced; see Backend-contract limitations). |
| 9b | Internships & Volunteering → **Volunteering** sub-section | `create_resume.js:112-114,385`, `create_resume.py:86-88,122-123,135,138` | organization\*, role\*, location, start/end month+year + "Currently volunteering", responsibilities, contributions, achievements | organization, role (**no start_year requirement**, unlike Internships) | repeatable (≤20) | **NEW** same file, `_VolunteeringFields` | **Was MISSING → IMPLEMENTED.** Rendered under a "Volunteering" sub-heading, same tab, right after Internships — the website has no separate top-level tab for this (`volunteering` is absent from `SECTIONS`; `SECTION_OF['volunteering'] == 'internships'`), so no separate Flutter step was created for it either. |
| 10a | Languages & Additional Information → **Languages** sub-section | `create_resume.js:386-396,66-71`, `create_resume.py:89,124,136` | name\* ("Language"), proficiency\* (select: Basic/Conversational/Intermediate/Professional/Native) | **both** name AND proficiency (the only section where the select itself is required-for-completeness) | repeatable (≤20) | **NEW** `create_resume_languages_additional_step.dart` (`CreateResumeLanguagesAdditionalStep`) | **Was MISSING → IMPLEMENTED.** Rendered as a simple inline row (name + proficiency dropdown + remove button) rather than wrapped in the shared collapsible entry-card, matching the real site's own bespoke (non-`entryList()`) renderer for this one section. |
| 10b | Languages & Additional Information → **Additional information** sub-section | `create_resume.js:72-73,397-398`, `create_resume.py:29-31,91-95` | memberships, publications, research, activities, hobbies, other — 6 flat textareas, in this exact order, each "(one point per line)" | none (flat dict, not repeatable — not part of `ENTRY_REQUIRED` at all) | single (`CreateResumeAdditionalInfo`) | **NEW** same file | **Was MISSING → IMPLEMENTED.** Confirmed as a flat dict (`additional` is absent from the `REPEATABLE` tuple), not a list — implemented as `CreateResumeAdditionalInfo` with 6 string fields, never as a repeatable entity. |

"A section is not considered complete simply because its heading is visible" — every row
above was verified by locating its editable fields in the Flutter builder, confirming the
field set/order/types/required-ness against the Django source, and (for all 5 new sections)
by live, on-device confirmation that fields accept input and that repeatable add/remove
produces/removes the correct entry (see the Implementation Report's "Emulator verification"
section).

## Gaps closed vs. deliberately out of scope

**Closed this phase:**
- `profile_url` added to Personal Information (Section 1) — a genuine gap, not one of the 7 named sections, found while re-verifying "already matched" sections per this phase's explicit instruction not to trust prior audits blindly.
- Sections 6, 7, 8, 9a, 9b, 10a, 10b — all newly implemented.

**Deliberately not changed (documented, not silently skipped):**
- **No Edit/Done collapse toggle, no manual ↑/↓ reorder, no "Sort newest first" link** for any of the 5 new sections, even though the real site's own JS (`entryList()`) implements this richer interaction for every repeatable section. The *existing* Experience/Education steps in this Flutter builder already use a simpler always-expanded-card pattern without this interaction. Adding reorder/collapse only to the 5 new sections while the two pre-existing repeatable sections lack it would have been an inconsistent, scope-expanding deviation — "implement the missing sections," not "redesign the repeatable-entry interaction model for the whole builder." This is a real, intentional UI simplification relative to the website, flagged here rather than silently present.
- **`order` field still sent as `const {}`** for every section, including the 5 new ones. The server defaults a missing section's order to `'auto'` (`create_resume.py:197`), which is exactly what "no reorder UI" means in practice — this is consistent with the no-reorder decision above, not an oversight.
- **Languages' case-insensitive duplicate-name check is not reproduced client-side.** This feature has an established, deliberate "no separate client-side validator — all field feedback comes from the server's `{field, section, message}` error envelope" design (documented in the Phase 39 report; confirmed again via `CreateResumeValidationError`'s own doc comment). Reimplementing one section's server-side business rule client-side would have broken that consistency. A duplicate language name will correctly surface as a server error on submit, exactly like every other validation rule in this builder.
- **Skills step's widget-level interaction (reorder/edit-in-place)** was not re-audited — it was outside the 7 named sections and the data model (`CreateResumeSkills`) was already confirmed unchanged.
- **Final-document section ordering** (`build_document()`'s experience-dependent section order for the rendered PDF/preview) is entirely server-side; Flutter just POSTs form state and renders back whatever the server returns, so no Flutter-side change was needed or made for this.

## Backend-contract limitations (documented, not worked around)

None of the 7 named sections required a backend contract change — `create_resume.py`'s
`ENTRY_FIELDS`/`ADDITIONAL_FIELDS`/`SECTIONS` already define all of `projects`,
`certifications`, `achievements`, `internships`, `volunteering`, `languages`, and `additional`
server-side; Flutter was simply not yet sending or parsing them. No endpoint, field, or
persistence behavior was invented — every new Flutter field name and JSON key matches the
server's own field names exactly (verified key-by-key against `ENTRY_FIELDS`/
`ADDITIONAL_FIELDS`). The one behavior intentionally left unenforced client-side (Languages'
duplicate-name rule) is a validation message, not a missing feature — the server still
enforces it and the generic error-display path already surfaces it.
