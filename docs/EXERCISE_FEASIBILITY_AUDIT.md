# Exercise Feasibility Audit — W007 and W008–W023

**Read-only investigation. No Django/web file was modified to produce this
document.** All findings are from direct source inspection (file:line
citations throughout), not from re-stating prior audits without verification.

---

## 1. W007 Feasibility — Fill in the Blank

### HTML route
`GET /activities/exercise/<pk>/` → `activities/views.py:1328` `exercise_detail`
(`@login_required`, plain GET, returns full HTML — `templates/activities/exercise.html`).
For a default-flow exercise (fill_blank included) it is **not** redirected
elsewhere first (that only happens for workshop/module-type activities,
`activities/views.py:1333-1366`).

- **Auth**: Django session cookie (`@login_required`) — Flutter's existing
  `ApiClient` (`PersistCookieJar`) already carries this cookie automatically
  once a user has logged in via the existing W001 flow. No new auth
  mechanism needed.
- **Cookies required**: the standard `sessionid` cookie, already persisted.
- **CSRF for the GET itself**: none — Django only enforces CSRF on unsafe
  methods (POST/PUT/PATCH/DELETE). A GET needs no token.
- **Can Flutter's existing Dio/session setup reach it?** Yes, technically —
  it's an ordinary authenticated GET, no different in kind from any other
  page Flutter's `ApiClient` already reaches.
- **Response shape**: full HTML (`Content-Type: text/html`), not JSON. This
  is already a code path the app handles gracefully today: Dio's default
  transformer only JSON-decodes when the body parses as JSON; for HTML it
  falls back to returning the raw body as a Dart `String` — confirmed by
  reading `lib/core/network/api_envelope.dart:10-14`, which explicitly
  guards against exactly this case (`responseBody is! Map<String, dynamic>`
  → `UnexpectedResponseException`) and is exercised by an existing test
  (`ActivitiesRemoteDataSource.getActivityList treats a non-JSON body as
  unexpected, not success`). So receiving an HTML string back is not a
  crash risk — it's already a known, handled shape.
- **Does the HTML contain the complete Fill-in-the-Blank question data?**
  Yes — see Question 2.

### Can Flutter consume the existing HTML?

**Yes, but only a small, well-formed part of it — not the page as a whole.**
`exercise_detail` builds `questions_json` (`activities/views.py:1389-1403`,
a `json.dumps([...])` of every question's `id`, `text`, `type`, `options`,
`correct`, `explanation`, `left`, `right`) and embeds it verbatim as
`<script type="application/json" id="questions-data">{{ questions_json|safe }}</script>`
(`templates/activities/exercise.html:451`). This is a **real, valid JSON
document**, not markup that needs DOM/CSS-based scraping. A Flutter client
could fetch the page as text and extract just that block with a targeted
regex anchored on the stable `id="questions-data"` attribute — no HTML
parser package is required (confirmed: this project's `pubspec.yaml` has no
`html`/DOM-parsing dependency today, and none would be needed for this
narrow extraction).

This is meaningfully **more robust than typical HTML scraping** (no CSS
class chains, no DOM-depth assumptions, no JS-generated content to wait
for), but it is still **not a designed API contract**:
- The `id="questions-data"` attribute, the `questions_json` context key, and
  its field names are template/view implementation details with no
  stability guarantee, no versioning, and no test coverage protecting a
  non-browser consumer.
- The endpoint returns the **entire page** (breadcrumbs, language-switcher
  markup/JS, styling) — a Flutter client must fetch and discard all of that
  just to reach one script tag, which is wasteful and inelegant compared to
  a real API, even though it isn't fragile in the CSS-scraping sense.
- `exercise_detail` has a real side effect on every GET —
  `_claim_free_activity(request.user, activity)`
  (`activities/views.py:1336`) spends a Free-Plan user's single activity
  slot. This is *consistent* with how the web itself behaves (opening the
  page counts, same as it does for a browser user) and mirrors the
  side-effect-on-GET pattern already relied on elsewhere (e.g. W005's
  `progress.mark_started()`), so it is not a new problem — but it does mean
  "just peeking at the data" is never actually side-effect-free.

### Can Flutter use the existing POST?

**Yes, directly, with no changes.** `POST /activities/exercise/<pk>/submit/`
→ `activities/views.py:1413` `submit_exercise` (`@login_required @require_POST`).
Verified via `static/js/exercises.js:39-79` (`submitScore`), which is the
exact code the web page itself calls:

- Method: `POST`.
- Content-Type: `application/json`.
- Headers: `X-CSRFToken: <csrftoken cookie value>` — the exact same header
  name/mechanism already used by this project's `login`/`logout`/
  `markSubComplete` calls (`AuthRemoteDataSource`, W005's
  `ActivitiesRemoteDataSource.markSubComplete`). No new CSRF technique
  needed.
- Body: `{"score": <int>, "max_score": <int>, "answers": {"1": {"given":
  "...", "correct": "...", "result": "correct"|"wrong"}, ...}}` — keys are
  1-based question **position** strings (matching page order), not
  database ids.
- Response: `200 {"status": "ok", "score", "max_score", "percentage",
  "attempt", "customSummaryHtml"}` — no redirect, already pure JSON in/out.
- Errors: standard Django error codes (`403` if CSRF/locked, `404` if the
  exercise doesn't exist), all already mapped by the existing
  `ApiExceptionsInterceptor`.

This endpoint requires no HTML parsing to use — it is already a clean,
generic JSON action, and Fill-in-the-Blank answers can be submitted through
it exactly as the web does, with no new backend endpoint required.

### Can full W007 be reproduced?

Item-by-item, using **only** the existing GET (for its embedded JSON block)
and the existing POST:

| # | Requirement | Feasible? |
|---|---|---|
| 1 | Exercise title | Yes — in the same page (`exercise.title`), or already available via `sub_activity_detail_api`'s exercise summary. |
| 2 | Questions | Yes — via the `questions_json` script-tag extraction. |
| 3 | Text inputs | Yes — standard Flutter `TextField`, no web dependency. |
| 4 | Check buttons | Yes — pure UI, grading rule is known and copyable (`given.trim().toLowerCase() === correct.trim().toLowerCase()`, `static/js/exercises.js:211-212`). |
| 5 | Empty validation | Yes — same trivial client-side rule, matches web exactly. |
| 6 | Case-insensitive comparison | Yes — same rule, trivially reproducible. |
| 7 | Correct/incorrect state | Yes. |
| 8 | Correct-answer display | Yes — the correct answer is already in the extracted JSON (see Security section). |
| 9 | Score calculation | Yes — same client-side sum-of-corrects the web itself computes. |
| 10 | Final submission | Yes — via the existing `submit_exercise` POST, unchanged. |
| 11 | Result panel | Yes — the 6-tier message thresholds are hardcoded client logic (`static/js/exercises.js:89-108`), fully reproducible; POST response supplies score/max/percentage. |
| 12 | Previous score | **Not from this GET** — but already available today from `sub_activity_detail_api`'s existing `last_attempt` field on each exercise (already wired since W005), so this specific item is actually covered by an existing *proper* JSON API, not the scraped HTML. |
| 13 | Try Again | Yes — web does `location.reload()`; Flutter equivalent is simply re-running the same fetch-and-parse flow and resetting local state. |
| 14 | Back to Sub-Activity | Yes — existing Flutter navigation (already implemented, W005). |
| 15 | Exercise completion | Yes — a side effect of the existing POST (`submit_exercise` already updates `UserProgress`/`UserExerciseResult` — no client action needed beyond calling it). |

**Every single requirement is technically reproducible** using only the
existing GET+POST. The entire feasibility question therefore reduces to
whether extracting the `questions-data` script tag from a full HTML page is
an acceptable, durable data-access pattern for a shipping mobile app — see
Classification below.

### Security considerations (audit only — nothing "fixed")

- **The correct answers ARE sent to the browser before grading.** Verified
  directly: `questions_json` includes `'correct': q.correct_answer` for
  *every* question (`activities/views.py:1398`), and for fill_blank
  specifically the same value is also duplicated into
  `data-correct="{{ question.correct_answer }}"` on both the question card
  and the `<input>` element (`templates/activities/exercise.html:187,193`).
  A user can read every correct answer directly from page source before
  answering a single question, on the web today. This is a pre-existing
  characteristic of the web app, already flagged in this project's
  `docs/SECURITY_RECOMMENDATION_activities.md` from an earlier phase — not
  newly discovered here, and **not something this audit fixes or
  recommends fixing** (out of scope, read-only task).
- **Score is calculated in JavaScript**, client-side
  (`static/js/exercises.js:211-245`).
- **Django trusts the submitted score verbatim** for `fill_blank` (and
  `mcq`/`matching`/`bingo`) — confirmed by reading `submit_exercise`
  (`activities/views.py:1413-1526`): the AI-grading branch only applies
  `if exercise.exercise_type in ('writing', 'timer')`; every other type's
  `score`/`max_score` from the request body is stored as-is
  (`UserExerciseResult.objects.create(..., score=score, max_score=max_score, ...)`,
  lines 1501-1508). Django does **not** independently verify fill_blank
  answers.
- This means a Flutter implementation built on this flow would faithfully
  **inherit** the same client-trust characteristic the web already has —
  it would not be introducing a new vulnerability, only reproducing an
  existing one. Documented, not fixed, per this task's explicit
  instruction.

### Final classification: **OPTION B — Technically possible but fragile**

The existing GET's embedded `questions-data` JSON block plus the existing
`submit_exercise` POST can genuinely support every piece of W007's
functionality without any backend change. The extraction technique is
notably safer than classic CSS/DOM scraping (a stable element id, a real
JSON payload, no dependency on visual markup or JS-rendered content).

However, it remains fragile in ways that matter for a shipping application:
- It's an **undocumented, unversioned coupling** to `exercise_detail`'s
  specific template implementation. Nothing prevents a future web change
  (renaming the script tag id, restructuring `questions_json`, or altering
  `exercise_detail`'s control flow) from silently breaking the mobile
  client, since this consumption pattern is invisible to and unconsidered
  by whoever maintains the web template.
  - This is one file across the entire app; the web-project maintainers may
   reasonably not consider or test for downstream consumers when they change it.
- It requires fetching and discarding an entire HTML page (styling,
  breadcrumb, language-dropdown script, etc.) just to reach one script
  block — heavier and less elegant than a designed endpoint, though not
  functionally broken.
- It inherits the web's own pre-existing security posture (answers visible
  pre-submission, client-trusted score) rather than improving on it —
  reasonable for parity, but worth being explicit that mobile would not be
  more secure than web here.

**Recommendation for a submission-ready application**: this approach should
be treated as a **documented, deliberate trade-off**, not a default
pattern to reach for casually — reasonable to adopt only with the
awareness that any web template change to `exercise.html` could silently
break it, with no compiler/test signal on the web side to catch it.

---

## 2. W008–W023 Feasibility Matrix

| ID | Screen | Web Route | Data Source | Submission | Classification | Implementable Now? | Main Blocker |
|---|---|---|---|---|---|---|---|
| W008 | Matching | `GET /activities/exercise/<pk>/` (`matching` branch) | `questions_json` script tag (`left`/`right`/`correct` per question) — same mechanism as W007 | Existing `POST .../submit/` (client-trusted score) | **B** | Same terms as W007 | No JSON read API; answer pairing exposed in page source pre-submit |
| W009 | Bingo | `GET /activities/exercise/<pk>/` (`bingo` branch) | `bingo_json` script tag (`word`/`definition` pairs) | Existing `POST .../submit/` (client-trusted score) | **B** | Same terms as W007 | No JSON read API; full word/definition key present in page source |
| W010 | Ordering | *(none reachable)* | N/A | N/A | **E — Dead/Not Applicable** | No | `exercises.js` has a full `initOrdering()` handler wired into the type dispatcher (`case 'ordering': initOrdering(); break;`), but `exercise.html` has **no** `{% elif exercise_type == 'ordering' %}` branch at all — independently re-confirmed by direct grep, not assumed from a prior audit. The function runs and no-ops against elements that don't exist. |
| W011 | Writing (default-flow, DB-backed prompt) | `GET /activities/exercise/<pk>/` (`writing` branch) | `questions_json` (real `Question.question_text` rows) | Existing `POST .../submit/` — **server-side AI re-grading** via Sarvam, conditional on `SARVAM_API_KEY` being configured | **B** (favorable — grading is authoritative when the key is set) | Same read-side terms as W007 | No JSON read API for the prompt text |
| W012 | Timer | `GET /activities/exercise/<pk>/` (`timer` branch) | `questions_json` (real `Question.question_text` rows) | Existing `POST .../submit/` — same conditional server-side AI re-grading as Writing | **B**, plus an extra blocker | No | No JSON read API for the prompt, **and** the transcript is produced by the **browser's native `SpeechRecognition` API** (`static/js/exercises.js:1142-1166`) — Flutter has no built-in equivalent; would need a third-party STT plugin. Raw audio is never uploaded to the server (only the text transcript is submitted). |
| W013 | Workshop Dashboard | `GET /activities/workshop/` | `activity_list_api` already returns workshop-category activities (filter client-side on `category == "workshop"`) | N/A (pure launcher, no exercise content of its own) | **A**, with one gap | Mostly yes | The HTML view computes a `direct_url` (`/gd/`, `/jam/`, `/roleplay/`) from a title-keyword match (`activities/views.py:870-874`) that **is not included** in `activity_list_api`'s JSON — a Flutter client would need to replicate the same 3 keyword rules client-side (trivial, not a data-availability blocker). |
| W014 | AI Speaking | `GET /activities/exercise/<pk>/` (module-template route) + `POST /activities/exercise/<pk>/analyze/speaking/` | **None** — the prompt list is hardcoded directly in `speaking.js` (20 topics, multi-language), not sourced from the DB at all | **Existing, genuinely clean JSON API** (`analyze_speaking`) — multipart audio upload, **server-side authoritative scoring** (score computed from Sarvam AI response and persisted *before* being returned) | **B (favorable)** | Submit: yes. Full screen: only by duplicating the same static prompt list into Flutter | No read API, but the missing data is static, non-secret content — the same "duplicate the constant" pattern already used for W005's Learning Tips card, not risky scraping |
| W015 | AI Writing (module) | Same pattern as W014, `.../analyze/writing/` | **None** — prompt hardcoded directly in `writing.html` template text | Existing, clean JSON API (`analyze_writing`), text-only body, server-authoritative scoring | **B (favorable)** | Submit: yes. Full screen: duplicate the static prompt | Same as W014 |
| W016 | AI Listening | Same pattern, `.../analyze/listening/` | **None** — story hardcoded in `listening.js`, read aloud via browser `speechSynthesis` (no server audio) | **Blocked even on write** — `analyze_listening` requires a fresh `attempt_token` minted only by `exercise_detail`'s HTML render (`secrets.token_hex(16)` per page load) and validated against `request.session[...]`; no JSON endpoint mints this token | **C** | **No** | Anti-replay token is architecturally tied to rendering the HTML page first — reproducing this without a new backend endpoint isn't possible under this task's constraints |
| W017 | AI Reading | Same pattern, `.../analyze/reading/` | **None** — passage hardcoded in `reading.js` | Existing, clean JSON API (`analyze_reading`), multipart audio, server-authoritative scoring | **B (favorable)** | Submit: yes. Full screen: duplicate the static passage | Same as W014 |
| W018 | Roleplay Home | `GET /roleplay/` | `TOPIC_PRACTICE_CONFIG` — a hardcoded Python dict, not DB-driven; static picker page, no exercise content itself | N/A | **A** (it's just a menu) | Yes | None of substance — 3 static cards |
| W019 | Roleplay Practice | `GET /roleplay/<feature>/` + `POST /roleplay/practice/` (generate) + `POST /roleplay/analyze/` (score) | No persisted session exists server-side at all — nothing to "read back" | **Both action endpoints are genuinely clean, already-existing JSON APIs** (form-in, JSON-out); `analyze_roleplay` computes `score_25` server-side and writes `ScoreRecord(module='roleplay')` | **B (favorable)** | Generate+score: yes, directly. Full turn-taking UX: needs native STT/TTS | Turn-taking relies entirely on the browser's `SpeechSynthesisUtterance`/`SpeechRecognition` — same STT/TTS gap as W012. CSRF: reuses the same already-persisted `csrftoken` cookie this app's session already carries (no extra page load needed, same as W005's `markSubComplete`) |
| W020 | Mock Test — OOP Mastery | `GET /activities/oop-quiz/questions/` + `POST /activities/oop-quiz/submit/` | **Real JSON API** — flat JSON question bank, 50 random of 300, answers withheld until grading | **Real JSON API**, fully server-side grading (`chosen == q["answer"]` compared against the full bank server-side) | **A** | **Yes, immediately** | None — no HTML/scraping/new-endpoint needed at all |
| W021 | Mock Test — Subject Quiz (~24 subjects) | `GET /activities/quiz/<subject>/questions/` + `POST /activities/quiz/<subject>/submit/` | Same pattern as W020, one flat JSON bank per subject, parameterized | Same pattern, server-side grading | **A** | **Yes, immediately** | None — a single generic Flutter screen parameterized by `subject` covers all ~24 subjects with zero backend work |
| W022 | Mock Test — AMCAT | `GET /activities/amcat/questions/` + `POST /activities/amcat/submit/` | Real JSON API, 5 sections (quant/english/logical/personality/domain) from one 500-question bank | Real JSON API, server-side grading, per-section + overall breakdown | **A** | **Yes** (more UI work: 5 sequential timed sections, one final submit) | None on the data/API side — only added client-side flow complexity |
| W023 | Mock Test — CoCubes | `GET /activities/cocubes/questions/` + `POST /activities/cocubes/submit/` | Real JSON API, 4 sections from an 803-question bank — **confirmed 100% MCQ**, including "Programming" (a stale code comment in `urls.py` claims a free-text component; independently verified false — no `type:"code"` question exists in the live data, and the page's own visible copy says "scored like the other sections") | Real JSON API, server-side grading | **A** | **Yes** | None |

---

## 3. Recommended Next Development Path

Strictly by technical implementability — **not** by product value, per the
task's explicit instruction.

1. **W020–W023 Mock Tests (OOP, Subject Quiz ×~24, AMCAT, CoCubes)** — the
   only group with real, already-existing, server-authoritative JSON APIs
   on both the read and write side, with zero HTML-scraping and zero new
   backend work. Technically the cleanest, lowest-risk implementation in
   the entire audited set. A single generic "mock test" screen
   (question list + timer UI + submit) parameterized by endpoint pair
   would cover OOP, all ~24 subjects, AMCAT, and CoCubes with shared code —
   only the multi-section sequencing (AMCAT/CoCubes) adds real UI work
   beyond the single-section case (OOP/Subject Quiz).
2. **W013 Workshop Dashboard** — already almost entirely covered by the
   existing `activity_list_api`; only needs the same 3-keyword
   category→route mapping already used by the web to be duplicated
   client-side (no scraping, no new endpoint).
3. **W014 AI Speaking / W015 AI Writing / W017 AI Reading** — genuinely
   clean, already-existing, server-authoritative JSON submit endpoints.
   The only gap is duplicating a short, static, non-secret prompt list
   into Flutter (the same low-risk pattern already used for W005's
   Learning Tips) — meaningfully safer than scraping embedded HTML/JSON,
   since there's no live server-rendered structure being depended on at
   all, just a fixed list of strings.
4. **W019 Roleplay Practice / W018 Roleplay Home** — same favorable
   write-side situation as the AI modules (clean JSON generate+analyze
   endpoints, no session to fetch), but requires native STT/TTS to
   reproduce the turn-taking loop — more mobile-side engineering effort
   than #3, comparable backend risk.
5. **W007 Fill in the Blank / W008 Matching / W009 Bingo / W011 Writing
   (default-flow) / W012 Timer** — all technically reproducible via the
   embedded-script-tag extraction technique, but this is the most fragile
   pattern in the whole audit (undocumented coupling to `exercise.html`'s
   template structure). W012 additionally needs the same STT capability
   gap as Roleplay. If pursued, all five should share one extraction
   utility rather than five separate implementations, to minimize the
   number of places a future web template change could silently break.
6. **W016 AI Listening** — not implementable at all under the "no new
   backend endpoints" constraint; its anti-replay token can only be minted
   by rendering the HTML page, and there is no way to substitute for that
   without either a new endpoint or scraping a token out of HTML on every
   attempt (fragile in a different, session-continuity-dependent way from
   the script-tag cases above).
7. **W010 Ordering** — not applicable; confirmed dead on the web itself.

---

## 4. Flutter Changes

**Documentation only.** No Flutter production code was created or modified
by this task — this is a read-only investigation and planning exercise, as
instructed. One file was added:

- `docs/EXERCISE_FEASIBILITY_AUDIT.md` (this file)

---

## 5. Tests

`flutter analyze`: no issues (unchanged — no code was touched).
Full Flutter test suite: **208/208 passing**, unchanged from baseline —
no implementation changes were made, so the test count is identical to
before this task.

---

## 6. Web Integrity

`git status`/`git diff` against
`/Users/kunjapramodmahajan/Flutter Projects/Career_Buddy_LMS/Career_Buddy_LMS/`
were checked before finishing this task.

**No files inside the Django/web project were modified.**
