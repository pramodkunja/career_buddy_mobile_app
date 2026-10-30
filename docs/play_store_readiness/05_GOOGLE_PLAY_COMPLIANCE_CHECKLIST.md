# Document 5 — Google Play Compliance Checklist

Read-only preparation document. This is not Google's Data Safety form filled
out on the developer's behalf — it is a verified-evidence preparation
reference, with every unanswered question named explicitly. The business
must complete the actual Play Console declarations; this document tells
them, with evidence, what the truthful answers should be built from.

---

## A. Privacy Policy

- **Public HTTPS URL**: required by Google Play for every app. **Does not
  currently exist** — confirmed absent from both local Django template
  trees (Document 1 §1, Document 3 §A2); the live site was not checked.
  Must be published before submission.
- **Content**: see Document 3, Part B for the full factual outline.
- **Accessible without login**: must be a plain public page, not gated
  behind account creation.
- **Linked inside the app**: **not verified in this pass** whether any
  existing screen (e.g. registration) links to a Privacy Policy URL —
  `Requires confirmation`; if one doesn't exist, add a link once the page
  is published.

## B. Account deletion

- **In-app deletion path**: **does not exist** (Document 3, Part A1).
- **Public external deletion webpage**: **does not exist**; see Document 3,
  Part A6 for what to build and Document 4 for the sitemap entry. Google
  Play's Account Deletion policy accepts a web-based request flow as an
  alternative to an in-app one, **provided it actually results in deletion
  or clearly-disclosed data handling** — a form that only logs a request
  for manual processing should disclose that honestly in its own copy
  (do not imply instant automated deletion).
- **Required disclosures**: what is deleted vs. retained, and why — see
  Document 3's deletion capability matrix. As of this audit, essentially
  nothing is deletable by any existing mechanism; this is the most
  significant compliance gap found.
- **Backend deletion capability**: **confirmed absent** (Document 3, Part
  A2). Google Play's policy expects the described deletion process to
  actually work — publishing a request form without any backend capability
  to act on it is a **reputational and policy risk**, not merely an
  implementation nicety. Recommend treating backend deletion work as a
  near-term priority, not a someday item.
- **How to submit the URL in Play Console**: once a real public page
  exists, its URL goes in the "Delete account" field of the Data Safety
  section in Play Console. This is a configuration step for whoever manages
  the Play Console listing — no code change needed for the submission
  itself.

## C. Data Safety — mapping actual practices to Google Play's categories

This maps confirmed findings to Play's Data Safety categories. The business
must still complete the actual form; this is the evidence to complete it
truthfully.

| Play Data Safety category | Collected? | Shared with a third party? | Optional or required? | Evidence |
|---|---|---|---|---|
| Name | Yes | No (visible to employers in-product via candidate search, not "shared" in Play's third-party sense) | Required | Document 2, A1 |
| Email address | Yes | No | Required | Document 2, A1 |
| Phone number | Yes (candidate optional, employer HR contact required) | No | Mixed | Document 2, A1 |
| Physical address | Yes (city-level/free text, no structured address) | No | Optional | Document 2, A1 |
| **Government ID (Aadhaar/PAN/passport)** | Yes | No | Aadhaar required, PAN/passport optional | Document 2, A1 — flag as **sensitive data**, review Play's specific category for government ID numbers |
| Photos (selfie, avatar, company logo) | Yes | No | Optional | Document 2, A3 |
| **Audio** | Yes — AI Speaking, Buddy voice, Group Discussion, Timer, JAM, Roleplay, Mock Interview | Yes — **Sarvam AI** (and Google for some TTS) for voice features | Varies by feature; several audio-using features are plan-gated, not individually optional once reached | Document 2, A5/C2 |
| **Video** | Yes — **continuous Mock Interview recording** | No (first-party backend only; not shared with Sarvam or any third party) | Required for that specific feature (cannot complete Mock Interview without it) | Document 2, A6 — this is the most significant single item to get right in the Play declaration |
| Health information (blood group) | Yes, optional | No | Optional | Document 2, A1 — flag for review as health-adjacent |
| Financial info (payment) | Payment metadata only (order/payment IDs, amount, plan); **no card/bank/UPI data** | Yes — **Razorpay** | Required to subscribe; app is usable for free otherwise | Document 2, A7 |
| App activity (learning progress, scores, chat usage) | Yes | **Sarvam AI** receives chat/voice/resume content as described above; progress/scores are not shared externally | N/A — inherent to using the features | Document 2, A4/A5 |
| Files/documents (resumes, job-application attachments) | Yes | **Sarvam AI** receives resume text for ATS analysis | Required for the resume-dependent features | Document 2, A2/A3 |
| Device/crash/diagnostics data | **Not collected** — confirmed absent | N/A | N/A | Document 2, C1 |
| Analytics identifiers | **Not collected** — confirmed absent | N/A | N/A | Document 2, C1 |

- **Ephemeral processing**: Buddy/Riya chat conversation history is
  confirmed ephemeral (not stored server-side or client-side beyond the
  live session) — this is a genuine, source-backed fact the business can
  state confidently for that one data type. It does not extend to resume
  text (which is stored) or interview video (which is conditionally
  stored).
- **Encrypted in transit**: not independently verified in this pass whether
  all API traffic is HTTPS-only in production — `Requires confirmation`
  from whoever manages the production deployment/TLS configuration; this
  audit did not inspect server/network infrastructure.
- **User-requested deletion**: **cannot currently be offered truthfully**
  for almost every data category, per Document 3. Google Play's Data Safety
  form asks whether users can request data deletion — the honest current
  answer is "no, for most data," pending the backend work described in
  Document 3.

## D. App access (for Google's reviewers)

- Google reviewers will need: a working **candidate test account** (to
  reach Activities, Skill Up, Resume Builder, Mock Interview) and a working
  **employer test account** (to reach the employer portal). **This audit
  does not create or expose test credentials** — the business/QA team must
  provision these separately and supply them through Play Console's App
  Access form, not in any public document.
- **OTP instructions**: registration requires email OTP verification for
  both roles (Document 1 §3, Document 2). If reviewer accounts are
  pre-created (recommended, to avoid giving Google a live OTP-capable
  inbox), this is moot; if reviewers must register fresh accounts, the
  business needs a plan for reviewers to receive OTP codes.
- **Subscription access**: to reach Mock Interview and other Normal/Pro-
  gated features, reviewers need an account already on a paid plan, or the
  business should document the gating clearly so reviewers aren't confused
  by locked content — Google does not expect reviewers to make a real
  payment.
- **Instructions for reaching important features**: recommend a short
  written walkthrough (outside this document, since it may reference
  real credentials) covering: Resume Parsing → Mock Interview unlock path
  (ATS ≥90%), where Skill Up / Tech Center / Non-IT Center are found, and
  how to reach the Employer Dashboard from a separate employer account.

## E. Other policy areas requiring review

| Area | Applicability | Evidence |
|---|---|---|
| User-generated content | Yes — resumes, chat messages, job postings, interview answers | Document 1, Document 2 |
| AI-generated content | Yes — ATS scoring, mock-interview feedback, Buddy chat replies, AI-written practice feedback | Document 1 §Mock Interview, §ARIA chat |
| Payments/subscriptions | Yes — external gateway (Razorpay), not Google Play Billing; **flagged for dedicated Play payments-policy review**, not assessed as compliant/non-compliant by this audit | Document 2, A7 |
| Education/employment-related claims | Relevant — the app makes implicit claims about improving job prospects/interview readiness; recommend legal review of any marketing language implying guaranteed outcomes | Document 1 |
| Personal/sensitive data | Yes — Aadhaar/PAN/passport, resume content, interview video/audio, health-adjacent blood-group field | Document 2 |
| Children/minors | **No age-gate or minimum-age field exists anywhere** — requires an explicit business/legal decision; if the service isn't intended for minors, Play still expects this to be clearly stated and, ideally, enforced | Document 2, A1; Document 3 §16-17 |
| Permissions/sensitive device access | Camera and microphone, both with confirmed narrow, legitimate use | Document 2, Part D |

---

## F. Content rating and target audience

Not independently assessed in this source-code audit — content rating
questionnaires are answered based on in-app content (none of which appears
to include violence, explicit material, gambling, or similarly rated
content, based on everything inventoried in Document 1) and are a Play
Console task for whoever manages the listing, informed by this audit's
module inventory rather than re-derived here.

## G. Items requiring legal/business confirmation before submission (recap)

1. Published, public Privacy Policy URL (does not exist yet).
2. Published, public Account Deletion page (does not exist yet) — and a
   business decision on whether to invest in real backend deletion
   capability before or shortly after launch.
3. Real support/contact information (does not exist yet, anywhere).
4. Legal entity name/address for the Privacy Policy (likely already
   configured server-side — see Document 3).
5. A decision on `JobApplication` and `RazorpayPayment` retention policy
   after account deletion (currently inconsistent with typical financial-
   record retention norms).
6. A decision on minimum age / children's privacy stance.
7. A Play payments-policy review of the Razorpay-only (non-Play-Billing)
   subscription model.
8. Confirmation of whether all production API traffic is HTTPS-only
   (outside this codebase audit's scope).
9. Updating the iOS camera-permission description to accurately reflect
   continuous video recording, not just a "live check."
