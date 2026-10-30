# Document 4 — Website Team Requirements

*This document is written for the website development team, to forward
directly. It assumes no prior familiarity with the codebase.*

---

## Executive summary

**What is Career Buddy LMS?** A mobile app (and companion website,
careerbuddy4u.com) that helps job seekers build skills and resumes and find
jobs, and helps employers post jobs and find candidates. Both the app and
the website talk to the same backend system and the same accounts.

**Who uses it?** Two kinds of accounts: Candidates (job seekers / students)
and Employers (recruiters). A visitor can browse some pages without an
account.

**What can candidates do?** Learn English/communication skills and
technical skills, build and analyze a resume against a job description with
AI help, take an AI-driven mock interview (which records video and audio of
them), take practice tests, earn certificates, and apply to jobs.

**What can employers do?** Register a company, post jobs, review and manage
applicants, search the candidate database, and manage a company profile.

**What learning features are available?** English/Grammar/Vocabulary,
Aptitude, a Tech Center and a Non-IT Center (technical and non-technical
career-path learning), speaking/writing/listening/reading practice graded
by AI, group discussion practice, "Just A Minute" speaking practice, and a
certificate system.

**What data does the application handle?** Personal details (name, email,
phone, and for candidates, Aadhaar/PAN/passport numbers — see below),
education and work history, uploaded resumes (resume text is shared with an
AI provider for analysis), chat messages with the in-app AI assistant,
voice recordings for several learning exercises, **video and audio
recordings of mock interviews**, and payment records (handled by Razorpay —
card/bank details never reach this app directly). Full detail: Document 2.

**What legal pages are required?** A Privacy Policy, Terms and Conditions,
an Account Deletion / Data Deletion page, and — because the app takes
payments — a Refund and Cancellation Policy. See the sitemap below for
exactly what each needs.

**How should account deletion work, right now?** As a **request form**, not
a self-service deletion button — **the backend has no capability today to
actually delete an account or its data**. The form should collect a
request for a human to process manually, explain that plainly to the user,
and never ask for a password. See Document 3 for the full detail and for
what the backend would need to build before this could become automatic.

**What website URLs must be available before the first Play Store
release?**
1. A public, no-login Privacy Policy page (required by Google Play for
   every app).
2. A public Account Deletion / Data Deletion Request page (required by
   Google Play's Data Safety / Account Deletion policy).
3. Terms and Conditions (strongly recommended; required if the app's own
   Terms screen or registration flow references one).
4. A working Contact/Support page with a real email address (currently
   **missing entirely** — see below).

**Which details are still awaiting confirmation?** The legal entity
name/address for the Privacy Policy (likely already configured server-side
— see Document 3, Part B, item 2), a real support email/phone/address and a
named grievance contact (**currently missing from the entire codebase and
website**), exact data-retention periods, whether employer accounts have
their own paid tier, and whether the business wants Razorpay's external
payment flow reviewed against Google Play's payments policy before launch
(the app does not use Google Play Billing).

---

## Complete feature list

See Document 1 for the full module-by-module inventory. In summary:
Home, candidate and employer registration/login, candidate dashboard,
employer dashboard, resume parsing/ATS matching, two different resume
builders, AI mock interview, Activities (AI Speaking/Writing/Listening/
Reading, matching, bingo, fill-in-the-blank, timed exercises), mock tests
(OOP, subject quizzes, AMCAT, CoCubes), Skill Up hub (Grammar, Vocabulary,
Aptitude, Tech Center, Non-IT Center, Certifications), JAM (speaking
practice), Roleplay, Group Discussion, job posting and applicant tracking,
candidate search, company profile management, and a 3-tier subscription
(Free/Normal/Pro) via Razorpay.

---

## Recommended website sitemap

| # | Page | Purpose | Required content | Who supplies content | Public URL needed for Play Console? |
|---|---|---|---|---|---|
| 1 | Home / landing | App overview, download links | Already exists at careerbuddy4u.com | Business/marketing | No |
| 2 | About Career Buddy LMS | Company/product story | Business copy | Business | No |
| 3 | Features and Modules | What the app does | Can draw directly from Document 1 | Website team + this audit | No |
| 4 | Candidate / Job Seeker info | Marketing page for candidates | Business copy | Business | No |
| 5 | Employer / Recruiter info | Marketing page for employers | Business copy | Business | No |
| 6 | Learning & Skill Development info | Describes Skill Up/Tech Center/Non-IT Center | Can draw from Document 1 | Website team | No |
| 7 | Subscription / Pricing | Plan comparison | Real prices confirmed: Free/₹499 Normal/₹999 Pro, 1-year plans, +18% GST (Document 2, Part A7 cross-ref / Document 1 §1) | Business to confirm current pricing is still accurate | No |
| 8 | Contact Us / Support | A real way to reach support | **Currently nothing exists anywhere — a real email address (and ideally phone/address) must be supplied by the business before this page can be built honestly** | **Business — blocking gap** | Recommended |
| 9 | Privacy Policy | Legally required disclosure | See Document 3, Part B's full factual outline | Business/legal to fill confirmation items; website team to draft from the outline | **Yes — required by Google Play** |
| 10 | Account Deletion / Data Deletion Request | Lets a user request deletion | See Document 3, Part A6 — a **request-intake form**, not a working self-service deletion tool, until backend work closes the gap in Document 3 | Website team to build; business to confirm retention text; backend team if automation is ever wanted | **Yes — required by Google Play for apps with accounts** |
| 11 | Terms and Conditions | Legally required/standard | Business/legal drafting | Business/legal | Recommended |
| 12 | Refund and Cancellation Policy | Required since the app takes payments | Must honestly state: **no in-app cancellation flow exists**; refunds are a **manual, outside-the-app process** via Razorpay (Document 2, Part A7 / subscription findings) | Business/legal, informed by the actual flow | Recommended given payments are involved |
| 13 | Cookie Policy | Only if careerbuddy4u.com itself uses tracking cookies | Not audited in this pass (out of scope — this audit covered the mobile app) | Business/website team to check the live site separately | Only if applicable |
| 14 | Grievance / Privacy Contact | A named contact for privacy complaints | **Does not exist anywhere today** | **Business — blocking gap**, especially relevant under India's data-protection framework | Recommended |

---

## Privacy Policy requirements

See Document 3, Part B for the complete, section-by-section factual
outline — what's source-verified vs. what needs business/legal
confirmation. Highlights the website team should not miss:
- Candidate registration collects **Aadhaar (required), PAN, and passport
  numbers** — these are encrypted at rest, but this is still the most
  sensitive data category in the app and needs explicit, prominent
  disclosure.
- The Mock Interview feature **records continuous video and audio** of the
  candidate, uploaded to the backend — this needs explicit disclosure, not
  a vague "camera access" mention.
- Resume text and job-description text are sent to an external AI provider
  (Sarvam AI) for analysis; voice features also use Sarvam AI and, for some
  languages, Google.
- Payment is via Razorpay; card/bank/UPI details never reach Career Buddy
  LMS directly.
- No analytics or crash-reporting SDK is used — do not disclose one that
  doesn't exist, and don't be afraid to state its absence as a positive.

## Terms and Conditions requirements

Not independently audited in depth (out of this investigation's critical-
path scope), but should at minimum cover: acceptable use, the free/paid
plan structure (pricing confirmed above), the fact that Razorpay processes
payments on the app's behalf, intellectual property in uploaded resumes and
generated certificates, and a disclaimer about AI-generated content
(interview feedback, chat assistant replies, ATS scoring) being automated
assessments, not guarantees. This is a business/legal drafting task.

## Account deletion page requirements

See Document 3, Part A6 in full. In short: build a request form (name,
account email/username, optional reason, email-confirmation step), state
plainly that it submits a request for manual processing (not instant
deletion), never collect a password, and disclose what will be retained
(payment/tax records at minimum, pending a legal retention-period decision;
likely also shared `JobApplication` records already sent to an employer).

## Support/contact requirements

**This is a confirmed, blocking gap**: neither the app nor the website (as
far as this filesystem audit could see) contains a real support email,
phone number, address, or grievance contact anywhere. The only existing
"Contact Us" destination (in both the app and the site) is a footer with no
contact details at all. The business must supply real contact information
before Documents 3's deletion page, the Privacy Policy, or Google Play's
App Access/Data Safety sections can be completed honestly.

## Required public URLs (recap)

1. Privacy Policy (public, no login).
2. Account Deletion / Data Deletion Request (public, no login, Google Play
   requires this be reachable without installing the app).
3. Terms and Conditions (recommended).
4. Refund/Cancellation Policy (recommended, given payments exist).
5. A real Contact/Support page (currently has nothing to link to).

## Backend integrations needed

- **None are needed for a request-intake-style Account Deletion page** —
  it can be a simple form that emails/logs a request to support staff.
- **If the business wants real self-service deletion**, backend work is
  required first: an authenticated deletion/deactivation endpoint, a
  decision on `JobApplication` retention/anonymization, and a decision on
  `RazorpayPayment` retention (currently `CASCADE`s with the user, which
  conflicts with typical financial-record retention requirements). This is
  a development task for the backend team, not the website team, and is
  out of scope for this read-only audit to implement.
- No backend changes are needed for the Privacy Policy, Terms, or Pricing
  pages — these are static content pages informed by this audit's
  findings.

## Business/legal questions that must be answered before launch

1. What is the exact legal entity name and registered address for the
   Privacy Policy's "data controller" section? (Likely already on file in
   backend configuration — ask the backend team to supply
   `COMPANY_LEGAL_NAME`/`COMPANY_ADDRESS` from `settings.py` rather than
   drafting new ones.)
2. What real support email, phone number, and physical address should be
   published? (Currently none exist anywhere.)
3. Who is the named grievance/privacy officer, if the business wants one
   (commonly expected under India's data-protection framework)?
4. What is the intended data-retention period for each data category
   (resumes, chat logs, payment records, job applications)? No
   retention-policy code exists today — this is a business/legal decision,
   not something this audit could discover in source.
5. What should happen to a `JobApplication` record (which contains a
   candidate's name/email/phone/resume/salary) after the candidate's
   account is deleted? Today it survives untouched. This needs an explicit
   policy decision.
6. Is there a legally required retention period for payment/tax records
   (the `RazorpayPayment`/GST-invoice data) that should override the
   current behavior of deleting them along with the account?
7. Does the business intend any minimum age for registration? No
   date-of-birth field or age gate exists anywhere today.
8. Should the external Razorpay payment flow (rather than Google Play
   Billing) be reviewed against Google Play's payments policy before
   submission? This audit only confirms which mechanism exists — it does
   not assess Play policy compliance.
9. Is there an intended in-app subscription cancellation feature? None
   exists today; refunds are currently a manual, outside-the-app process.
10. Should the iOS camera-permission description be updated to accurately
    describe the Mock Interview's continuous video recording, rather than
    the current "live camera check" wording?
