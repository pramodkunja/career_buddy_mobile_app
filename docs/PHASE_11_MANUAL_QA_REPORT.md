# Phase 11 — Test Account Access and End-to-End QA Completion

## 1. Preserve the working environment

Read `docs/PHASE_10_TEST_ENVIRONMENT_AND_QA_REPORT.md` and
`docs/PHASE_8_RELEASE_READINESS_CHECKLIST.md` before acting. Confirmed,
before making any change:
- **Mobile_app git status**: identical to Phase 10's end-state (same 11
  modified files, same untracked paths, last commit still `03964b6`).
- **Career_Buddy_LMS (web, read-only) git status**: identical to every
  prior phase's observation — the same pre-existing, uncommitted
  `dashboard_api`/`activities_api` work, untouched by this phase.
- **Emulator**: still running (PID 55429, `Pixel_9a`, `emulator-5554`,
  confirmed via `adb devices` → `device`).
- **Local Django dev server**: still running (PID 56123,
  `0.0.0.0:8000`, confirmed reachable: `curl http://127.0.0.1:8000/` →
  `200`).

Both were reused as-is — **no AVD wipe, no app uninstall, no server
restart** — since nothing about them needed to change for this phase's
work.

## 2. Obtaining legitimate test access — result: no authorized account available

Searched, read-only, for any project-documented development/test account or
approved provisioning procedure:
- `README.md`: no mention of a test/demo account anywhere in "Getting
  Started" or elsewhere.
- All Django management commands (`users/management/commands/`,
  `career_app/`, etc.): `seed_candidates`, `seed_jobs`, `seed_resumes`,
  `seed_it_jobs`, `seed_process_questions`, `populate_activities`,
  `import_question_bank`, `import_interview_questions` — these seed
  **content** (candidate resumes for employer search, job postings, LMS
  activities), not login-capable user accounts with known credentials. No
  `seed_user`/`create_test_account`-style command exists.
- `.env.example` (a template, not a secret — safe to read): documents every
  *setting name* a deployer must configure, but defines no in-repo
  demo/test login credentials.
- Searched the codebase for a `DEBUG`-gated OTP bypass (the kind of thing
  that would let a dev environment skip email verification legitimately):
  **none exists**. Email-OTP verification is unconditional.
- `EMAIL_BACKEND` defaults to a real SMTP backend
  (`django.core.mail.backends.smtp.EmailBackend` via ZeptoMail) — not a
  console/test backend — so completing new-candidate registration in this
  environment would require actually sending a real email through a live
  third-party SMTP account to a mailbox this session cannot read.

**Per the task's explicit instruction, this phase stops here rather than
working around it**: no private user record was inspected, no existing
user's credentials were extracted, no OTP was bypassed, and no backend
code or SMTP setting was modified to skip verification. This is the exact
same conclusion Phase 10 reached, now additionally confirmed by a direct
documentation/codebase search rather than inferred from the signup
screen alone.

**Exact prerequisite, for the project owner or administrator** (either one
resolves this):
1. An approved test mailbox (e.g. a real inbox this session could be given
   temporary, scoped read access to, or an email forwarding/relay the
   project owner monitors and relays the OTP code from) to complete the
   existing Job Seeker and Employer registration flows legitimately, **or**
2. Existing test-account credentials (username/email + password) for a Job
   Seeker account and, separately, an Employer account — and, for premium-
   feature checks specifically, an account already on a paid tier — handed
   to this session directly by someone authorized to access that account
   data (this session cannot and did not look them up itself).

## 3. Real-device QA — unchanged from Phase 10, for the one reason above

Since no valid test access became available (§2), the checklist results
are **unchanged from Phase 10** — repeated here for completeness rather
than re-executed, since nothing about the blocking condition changed:

| Item | Result | Note |
|---|---|---|
| Successful Job Seeker login + dashboard | **BLOCKED** | No valid account (§2) |
| Employer login + role-specific navigation | **BLOCKED** | Same — no Employer test account either |
| Core learning activities (live) | **BLOCKED** | Requires an authenticated session |
| Session persistence across app restart | **BLOCKED** | Requires a real session to persist |
| Logout + protected-route redirection | **BLOCKED** (logout specifically) / **PASS** (protected-route redirection, unauthenticated) | Phase 10 already confirmed an unauthenticated user hitting a protected route is correctly redirected to login — re-applies here unchanged; logging *out* of a real session cannot be tested without first logging in |
| Subscription plan display | **BLOCKED** | Requires reaching `/pro` without a guard redirect, i.e. requires auth |
| Subscription checkout (Razorpay test mode) | **BLOCKED** | Requires both an account and confirmed Razorpay test keys — neither available; **not tested, and not claimed as tested** |
| Premium features (paid-tier account) | **BLOCKED** | No paid-tier test account available or obtainable this phase |

No flow above was fabricated, assumed, or inferred from automated-test
behavior. Everything marked BLOCKED is blocked for the single, concrete
reason in §2.

## 4. TTS investigation — root cause identified, no secrets exposed

Read the actual server-side view (`riya_bot/views.py`, `riya_tts`,
read-only) to determine the real cause of the `400` observed in Phase 10,
rather than continuing to speculate:

```python
def riya_tts(request):
    try:
        body = json.loads(request.body)
        text = body.get("text", "").strip()
        ...
        api_key = getattr(settings, "SARVAM_API_KEY", "")
        if not text or not api_key:
            return JsonResponse({"error": "Missing text or API key."}, status=400)
        ...
```

and `business_english_lms/settings.py`:
```python
SARVAM_API_KEY = config('SARVAM_API_KEY', default='')
```

**Finding**: the 400 response body is exactly `{"error": "Missing text or
API key."}`, returned whenever *either* `text` is empty *or* `api_key` is
falsy. Cross-checked the Flutter caller
(`lib/features/aria_chat/data/datasources/aria_remote_datasource.dart:219-234`,
`synthesizeSpeech`): it sends a correctly-formed JSON body
(`{'text': text, 'language': language}` with `Headers.jsonContentType`),
and `text` is always the real, non-empty reply/greeting content at the
point this is called — so an empty `text` is not the cause here. That
leaves `api_key` empty as the only remaining explanation, and
`SARVAM_API_KEY` defaults to an **empty string** when not set in `.env` —
exactly the same self-diagnosing "not configured" pattern Phase 3 already
documented for Razorpay's `RAZORPAY_KEY_ID`/`SECRET`.

**Conclusion, per the task's required framing**: this is a **local
development-environment configuration issue** (a Sarvam API key not
populated in this machine's local `.env`), **not a Flutter defect and not
a server-side bug** — the Django view's own validation and error message
are working exactly as designed. No API key value was read, printed, or
exposed anywhere in this investigation; only the *code path* that produces
the 400 was inspected, plus the settings line showing the key's *default*
when absent (an empty string, not a secret).

**Flutter-side behavior under this failure, re-confirmed correct**:
`synthesizeSpeech` returns `null` on `success != true` (line 229) rather
than throwing, and the caller already falls back to on-device TTS/a muted
indicator — exactly what Phase 10's screenshot showed (a crossed-out
speaker icon, no crash, no hang). **No Flutter code was changed**, since
nothing here constitutes a reproducible Flutter-side defect.

**Sanitized log evidence** (identical to what Phase 10 captured, re-cited
here as the "actual HTTP 400 response" the task asks for):
```
HTTP POST /api/voice/tts/ 400 [0.03, 127.0.0.1:64861]
WARNING  django.channels.server HTTP POST /api/voice/tts/ 400 [...]
```
(Django's access log records status/timing/client address only; it does
not log request or response bodies, so no further sanitization was
needed — nothing beyond this line was ever present to redact.)

## 5. Validation and report

- `flutter analyze`: **clean, no issues.**
- `flutter test`: **1885/1885 passing**, 0 skipped, 0 failing — unchanged
  from Phase 7–10 (no source file was modified this phase; the TTS
  investigation was read-only on both sides).

## Outstanding access requirements (carried forward, now the sole blocker)

The **only** thing standing between this engagement and completing
Task 3's full checklist is §2's exact prerequisite: an approved test
mailbox, or directly-provided test credentials (Job Seeker, Employer, and
a paid-tier account for premium-feature checks), supplied by someone
authorized to provide them. Nothing else in the environment is blocking —
the emulator and backend are both live and working (confirmed in §1 and
by Phase 10's ARIA/route-guard/login-error findings).

## Final status

No new QA ground was covered in §3 beyond Phase 10, because the one
blocking condition from Phase 10 (no usable test account) did not change
and this phase correctly declined to work around it — it searched
documentation and code thoroughly first, rather than assuming the
blocker, and the search confirmed the blocker is real and exact. §4 made
genuine, code-level progress: the TTS 400 is now a **confirmed
root-caused local configuration gap**, not an open question, and not a
Flutter defect requiring any fix. `flutter analyze` is clean and
`flutter test` remains at **1885/1885 passing**. Git status in both
repositories, and the running emulator/backend, are exactly as they were
at the start of this phase.
