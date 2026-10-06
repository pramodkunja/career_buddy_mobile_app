# Career Buddy LMS — Web Flow Map (Phase 0)

Derived directly from the Django source (read-only). Companion to
`docs/WEB_SCREEN_INVENTORY.md`, which has the full route-by-route detail and
Flutter cross-reference. `[✓]` = Flutter has a verified-looking equivalent,
`[✗]` = no Flutter screen exists, `[~]` = partial/placeholder.

```
Public Home ( / )                                                          [~ top section only]
├── [logged out]
│   ├── Job Seeker Portal card
│   │   ├── Login (/users/login/)                                          [✓]
│   │   │   ├── success → / (home, authenticated)
│   │   │   ├── failure → error banner; 5x → IP/username lockout (15 min)
│   │   │   ├── "Forgot password?" → Password Reset (3-page flow)          [✗ all 3 pages]
│   │   │   └── "Create Free Candidate Account" → Registration             [✗]
│   │   │       └── email-OTP widget (send/verify) → auto-login → /
│   │   └── Employer Portal card → see EMPLOYER tree below
│   └── ARIA/Buddy widget (global launcher, every page)                    [~ only ~10 screens]
│
├── [logged in, student]
│   ├── navbar → Profile (/users/profile/, Overview + Edit tabs)           [✗]
│   ├── navbar → Logout (POST) → / (logged out)                           [✓, fixed this session]
│   ├── Dashboard (/dashboard/)                                            [✓ UI; BACKEND/DEPLOYMENT GAP on /dashboard/api/ — see PRODUCTION_E2E_VERIFICATION_REPORT.md]
│   │   ├── stats, activity progress, recent results
│   │   ├── Recommended Jobs → Jobs tree
│   │   └── Payment History (read-only list)                              [✓ list only, no invoice detail]
│   │
│   ├── Activities (/activities/)                                         [✓]
│   │   ├── Activity Detail → Sub-Activity → Exercise
│   │   │   ├── MCQ (real JSON API)                                       [✓]
│   │   │   ├── Fill-Blank / Matching / Bingo / Generic-Writing / Timer
│   │   │   │   (HTML-scraped, no JSON API — architecturally fragile)     [✓ but fragile]
│   │   │   ├── Ordering — no render branch on web OR Flutter              [dead, both sides]
│   │   │   ├── AI Speaking / Writing / Listening / Reading modules       [✓]
│   │   │   └── Delete a past attempt                                      [✗]
│   │   └── Workshop Dashboard → GD / JAM / Roleplay cards                 [✓]
│   │
│   ├── Grammar (/subject/) — 9 topics, all media types                    [✓ essentially complete]
│   │
│   ├── Skill-Up (/skill-up/) — 3 sections, ~64 real lesson pages          [✓ content; data hand-copied, drift risk]
│   │   └── Certifications (27 subjects: not_attempted→locked/eligible→certified)
│   │       └── name entry → PDF generate/regenerate/download              [✓]
│   │
│   ├── Resume Builder (/resume-builder/)                                  [✓]
│   │   ├── Upload → ATS score + JD match → 3 static resume templates      [✓ 1:1]
│   │   ├── Resume History                                                 [~ "View File" breaks session]
│   │   └── AI Mock Interview (camera-gated, anti-malpractice, 20 Qs)      [✓ except live face-detection]
│   │       └── Analytics/Results (HTML-scraped, fragile)                  [✓ but fragile]
│   │
│   ├── Subscriptions (/pro/) — Free / Normal / Pro plans                  [✗ ~0% — biggest gap]
│   │   ├── Razorpay checkout (create-order → verify-payment)              [✗ no SDK dependency at all]
│   │   └── GST Invoice                                                    [✗]
│   │
│   ├── JAM (/jam/)                                                        [✓ practice + 3-stage assessment]
│   │   ├── History (regular + assessment tabs)                            [✗ UI]
│   │   ├── Profile Settings                                               [✗]
│   │   └── Delete session/assessment, Reset progress                      [✗]
│   │
│   ├── Roleplay (/roleplay/)                                              [✓ no gaps found]
│   │
│   ├── Group Discussion (/gd/) — WebSocket-based live rooms                [✓ 1:1 protocol, +1 real improvement]
│   │
│   ├── Jobs (via /employer/employer/job-openings/ grid, also Dashboard's Recommended Jobs)
│   │   ├── Job Detail (branches employer/student render)                  [✗]
│   │   ├── Apply → email notifications both sides
│   │   ├── Quick Apply (from Resume Builder → Job Match)                  [✗]
│   │   └── My Application Detail (deep-linked from status emails)         [✗]
│   │
│   └── ARIA/Buddy chat
│       ├── Text send → non-streaming reply                                [✓]
│       ├── Streaming reply (the real web path, SSE)                       [✗]
│       ├── Voice input/output (STT/TTS)                                   [✗]
│       ├── Language selector (en/hi/vi/ar/ru)                             [✗ hardcoded English]
│       └── Action chips → auto-navigate (web) vs resend-as-message (Flutter, deliberate divergence)
│
└── [logged in, employer session]
    → home() redirects server-side to /employer-home/, never renders student home.html


EMPLOYER PORTAL (/employer-home/, /employer/...)
├── [anon] Register (OTP-verified) → auto-login → Employer Home            [✓]
├── [anon] Login → session['portal']='employer' → Employer Home            [✓]
├── [auth] Employer Dashboard (/employer/employer/dashboard/)               [✓ read-only]
│   ├── [incomplete profile: missing GST/PAN] → forced redirect → Create Company Profile
│   ├── Stats: Total Jobs / Active / Applications
│   └── My Job Postings table, per row:
│       ├── Applications count badge → Job Applications (per-job)          [✗ NO ROUTE]
│       ├── Edit → Edit Job                                                [✗ NO ROUTE]
│       └── Delete (confirm dialog) → POST delete                          [✗ NO ROUTE]
├── sidebar (present on every employer/* page):
│   ├── Post New Job                                                       [~ ComingSoonScreen]
│   ├── All Applications                                                   [~ ComingSoonScreen]
│   │   └── "Review Submission" → Application Detail                       [✗ NO ROUTE — most consequential gap]
│   │       └── status change → candidate notified by email
│   ├── Company Profile (edit)                                             [~ ComingSoonScreen, no create/edit distinction]
│   ├── Job Openings (browse ALL active jobs, tab-filtered)                 [~ ComingSoonScreen]
│   │   └── card → Job Detail (employer view — no apply form shown)
│   ├── Candidate Search                                                    [~ ComingSoonScreen]
│   │   └── (orphaned) CSV export — no UI link even on web
│   └── Logout (shared global users:logout, NOT the dead accounts_app:job_logout)  [✓]
```

## Cross-Cutting Notes

- **Certificate routes** appear in both the Skill-Up (§D) and Resume/Subscriptions
  (§F) discovery passes since `skillup_assessment` sits structurally near both —
  they're the same live endpoints, not duplicated features.
- **The 4 AI-graded exercise analyze endpoints** (`analyze_speaking/writing/
  listening/reading`) were independently confirmed complete by both the Activities
  agent and the AI-features/ARIA agent — consistent findings, not a discrepancy.
- **Dead/orphaned web routes** (`job_logout`, `jobs_app.urls`/`job_list()`,
  candidate CSV export, `resume_userguide.html`, the Skill-Up `HP/` folder, the
  `ordering` exercise type, `/subject/illustrations/`) are real Django URLs that
  exist in source but are unreachable from any live page — these are **not**
  Flutter gaps and should not be implemented; they're recorded here only so a
  future pass doesn't waste time chasing them.
