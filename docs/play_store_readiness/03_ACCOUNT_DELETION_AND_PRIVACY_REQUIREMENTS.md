# Document 3 — Account Deletion Audit & Privacy Policy Requirements

Read-only audit. No deletion request was created, submitted, or simulated.
No file, record, or account was modified anywhere to produce this document.

---

## Part A — Account deletion audit (CRITICAL finding: no mechanism exists)

### A1. Flutter app: no account-deletion UI exists anywhere

A full-tree search (`delete account`, `deactivate account`, `remove
account`, and variants) across `lib/` returned **zero matches**. Confirmed
specifically:
- No `settings` feature/screen directory exists at all.
- `profile_screen.dart` contains only `logout()` calls — no delete/
  deactivate action.
- `lib/shared/widgets/app_nav_drawer.dart` has no account-management menu
  item beyond the existing Login/Logout/Company Profile items.
- No `delete_account`/`deactivate_account` method exists anywhere in the
  `auth` feature's data sources, repositories, or controllers.

**Conclusion: the Flutter app currently offers no account-deletion entry
point of any kind, for either candidate or employer accounts.**

### A2. Django backend: no account-deletion endpoint exists

A full search of every app's `views.py`/`urls.py` for deletion logic near
"account"/"user"/"profile" found only three unrelated hits:

- `jam_app/views.py:103-104` — `reset_progress` (`jam:reset_progress`): a
  **feature-level "Danger Zone" reset** that permanently deletes a user's
  JAM (practice-session) history only, gated by login + CSRF + a confirm
  dialog. **This is not an account-deletion mechanism** — it deletes JAM
  sessions/scores, nothing else — and it is not currently reachable from
  the Flutter app at all.
- `activities/views.py:1051-1053` — lets a user delete one of their own
  exercise attempts. Not account-related.
- `users/views.py:220` — an OTP cache-key cleanup. Not account-related.

No `is_deleted`/`deleted_at`/soft-delete flag exists on any model in the
project. The `User` model is Django's own unmodified default. No view
anywhere deactivates an account on user request, and no admin-only
deletion action was specially wired beyond Django's own stock superuser
capability (not a user-facing or website-facing feature).

No public account-deletion webpage, route, or even textual mention
("delete my account", "right to be forgotten", "GDPR", "data removal")
exists anywhere in either Django project's `templates/`.

**Conclusion: the backend has no account-deletion endpoint, no
deactivation workflow, and no soft-delete mechanism of any kind.** The only
comparable precedent anywhere in the codebase is JAM's unrelated
"reset progress" feature, which at least demonstrates a working
login-gated-POST-plus-confirm-dialog pattern a future deletion feature
could follow architecturally.

### A3. What a hypothetical `User.delete()` would cascade to today

No user-facing trigger for this exists. This table is a read of the
actual foreign-key `on_delete` behavior, to inform what gaps a future
deletion feature would need to close.

| Model | Relationship to `User` | `on_delete` | Effect |
|---|---|---|---|
| `users.UserProfile` (profile, resume, resume_text, plan/subscription flags) | OneToOne | `CASCADE` | Row deleted; **the physical resume/avatar file on disk is not deleted** — no cleanup signal exists, so it becomes an orphaned file |
| `jobs_app.EmployerProfile` | OneToOne | `CASCADE` | Deleted, cascading further |
| `jobs_app.JobPosting` | ForeignKey(EmployerProfile) | `CASCADE` | Every posting by that employer is deleted, which **also deletes every `JobApplication` to those postings — including applications from other candidates who never asked for their data to be removed** |
| `jobs_app.JobApplication` (candidate's own applications) | `applicant_user = ForeignKey(User, null=True)` | `SET_NULL` | **The application row is NOT deleted** — only the link to the user is nulled. The row, including applicant name, email, phone, a separately-uploaded resume, cover letter, skills, and salary figures, **persists indefinitely, tied to the employer's posting, with no link back to the (now-gone) account.** This is a real, confirmed data-retention gap. |
| `career_app.RazorpayPayment` (payment/invoice ledger) | ForeignKey | `CASCADE` | Payment/transaction records, **including a GST tax-invoice serial that the model's own code comment says "must never shift,"** would be permanently deleted along with the user — inconsistent with typical multi-year statutory retention requirements for financial/tax records |
| `skillup_assessment.QuizAttempt`/`Certificate` | ForeignKey | `CASCADE` | Deleted with the user; generated certificate PDFs on disk are, by the same reasoning as resumes, not automatically cleaned up |
| AI/Riya chat history | No persistence model exists at all | N/A | Nothing to delete — it was never stored server-side in the first place (see Document 2, Part A5) |
| JAM practice history | — | — | Already deletable **independently of the account**, via the existing (web-only) "reset progress" feature |

### A4. Deletion capability matrix

| Data/record | Current deletion behavior | Can be deleted? | Retention requirement | Unknowns |
|---|---|---|---|---|
| User account (credentials, username) | No deletion/deactivation workflow exists | **No** | Requires business confirmation | Whether any manual (Admin/shell) process is used operationally today |
| Candidate `UserProfile` | Would cascade only if a deletion trigger existed (it doesn't) | **No** | Requires business confirmation | Resume/avatar files would be orphaned on disk |
| Employer `EmployerProfile` + job postings | Same; also destroys unrelated candidates' application records | **No** | Requires business confirmation | Whether this side-effect is acceptable at all, legally |
| `JobApplication` PII snapshot | **Survives even a hypothetical account deletion** | **No** | Requires an explicit retention/anonymization decision | The single largest confirmed right-to-erasure gap |
| Payment/transaction records | Would cascade-delete (no trigger exists today) | **No** | Likely yes — multi-year statutory retention for tax/financial records (exact period requires legal confirmation) | Whether the current `CASCADE` is intentional |
| Skill-Up quiz/certificate records | Would cascade-delete (no trigger exists) | **No** | Requires business confirmation | Certificate PDFs would be orphaned on disk |
| AI/Riya conversation history | Nothing to delete — not persisted server-side | **N/A** | None identified server-side | Whether Sarvam AI retains it on its own infrastructure — outside this codebase |
| JAM practice history | User-triggered permanent deletion **already works**, but only for this one feature, and only on the website | **Yes**, for this feature only | None identified | Whether to surface this in Flutter, or leave it web-only |

### A5. Does any backend workflow exist that a website deletion form could call?

**No.** There is no account-deletion endpoint, no deactivation endpoint,
and no API a public website form could submit to. A website "Account
Deletion Request" page built today could, at most, **collect a request for
a human to act on manually** — it cannot perform the deletion itself,
because no backend capability exists to call.

**Per the audit brief's own instruction**: a deletion-request webpage
must not collect the user's password, and must not claim automatic or
immediate deletion unless and until a real backend workflow is built to
back that claim.

### A6. Required website functionality (proposed, not implemented)

Given the confirmed absence of any backend deletion workflow, the website
team should build a **request-intake page**, not a self-service deletion
tool, until backend work closes the gap above. Recommended content:

- A short explanation that submitting the form sends a deletion **request**
  to the support team for manual processing — not an instant deletion.
- Fields: full name, the email or username associated with the account
  (enough for support staff to locate the account), and an optional reason.
- **Do not** collect a password.
- Verification: send a confirmation link to the email on file before the
  request is actioned (a lightweight, standard pattern — exact mechanism is
  a website-build decision, not a backend change).
- A clear statement of consequences: what will happen to profile data,
  resumes, and so on — pending the business's actual decisions below.
- A clear statement of **what will be retained and why** — at minimum,
  payment/tax records required by law and, pending a business decision,
  any `JobApplication` records already shared with an employer.
- A confirmation screen/email acknowledging the request was received.
- Contact/support details (currently missing from the business — see
  Document 2's Support/Grievance finding; must be supplied before this page
  can launch).
- No request-tracking/status page can be promised unless the business
  commits to operating one manually, since no backend ticketing exists.

**This page cannot be marked "complete" in Play Console's Account Deletion
field as a functioning deletion mechanism** until backend work exists to
actually act on these requests — see Document 5.

---

## Part B — Privacy Policy factual outline

For each section: what is **source-verified** vs. what **requires business/
legal confirmation**. This is a factual outline for drafting, not a
finished policy, and not legal advice.

1. **Application and service description** — source-verified; see
   Document 1 §1.
2. **Data controller / responsible organization** — **requires
   confirmation**, but with a strong lead: `royalStaffing_CB01/
   business_english_lms/settings.py` already defines configuration names
   `COMPANY_LEGAL_NAME`, `COMPANY_ADDRESS`, `COMPANY_EMAIL`, `COMPANY_GSTIN`
   (their actual values were deliberately not read or disclosed by this
   audit as business-sensitive configuration). **The business should pull
   the exact legal name/address/email directly from that file** to populate
   this section, rather than treating it as entirely unknown.
3. **Information collected** — source-verified; see Document 2, Parts A-B.
4. **Information users provide** — source-verified; registration,
   job-posting, resume, payment flows (Document 2).
5. **Automatically collected information** — source-verified as largely
   absent (no analytics/crash SDK); session cookie behavior is
   source-verified (Document 2, A4).
6. **Resume/document information** — source-verified, including the
   no-login-required file-serving characteristic (Document 2, A3).
7. **AI-related data processing** — source-verified for Sarvam AI and
   Google TTS (Document 2, A5); **requires confirmation** for those
   vendors' own retention/training terms.
8. **Payment and subscription data** — source-verified (Document 2, A7).
9. **Purposes of processing** — source-verified from each field's actual
   use (job matching, candidate search, AI analysis, billing).
10. **Legal basis** (consent/contract/legitimate interest, etc.) —
    **requires legal review**; not a code question.
11. **Data storage and security** — partially source-verified (session
    cookie is plain file storage, not Keychain/Keystore; Aadhaar/PAN/
    passport are Fernet-encrypted at rest; resumes are served from an
    unauthenticated, hash-protected URL). **Do not claim "all data is
    encrypted"** — only the three specific fields above are confirmed
    encrypted.
12. **Third-party service providers** — source-verified: Razorpay, Sarvam
    AI, Google (TTS). See Document 2, Part C.
13. **Data sharing and disclosure** — source-verified for the above three
    providers, plus the fact that candidate profile/resume data is visible
    to employers via candidate search (a first-party, in-product sharing
    the Policy should describe plainly).
14. **Data retention** — **largely unverified**: no retention-policy code
    or scheduled-deletion job was found anywhere in either Django project.
    State plainly that retention periods are **Unknown / Requires
    confirmation** rather than inventing a period.
15. **Account deletion** — source-verified as **not currently available**;
    see Part A above. The Policy should describe the actual current state
    (request-based, manually processed) honestly, not an automated
    capability that doesn't exist.
16. **User rights and privacy requests** — **requires legal confirmation**
    of which rights the business intends to honor and how (access,
    correction, deletion-request, data export) — some (data export) were
    not found implemented anywhere in source and would need a business
    decision before being promised.
17. **Children's privacy / age restrictions** — **no age-gate or minimum-
    age field exists anywhere in the registration flow** (no date-of-birth
    field exists at all, confirmed in Document 2 A1) — requires an explicit
    business/legal decision on the intended minimum age and how (if at all)
    it will be enforced or merely stated.
18. **International data transfers** — **requires confirmation**: where
    Sarvam AI's and Razorpay's infrastructure is physically located is
    outside this codebase.
19. **Cookies and website tracking** — out of this mobile-app-focused
    audit's direct scope; the website team should separately audit
    careerbuddy4u.com's own cookie usage if one hasn't been done.
20. **Changes to the Privacy Policy** — standard boilerplate; a business/
    legal drafting decision, not a code question.
21. **Contact information / grievance contact** — **confirmed missing**:
    no support email, phone, address, or named grievance officer exists
    anywhere in the inspected source (see Document 2 and the Support
    finding below). This must be supplied by the business before
    publishing a compliant Privacy Policy.

**Statements this audit explicitly avoids making, per the brief's own
instruction**, and which the business/legal team must not make either
without independent verification: "we never share data," "all information
is encrypted," "all data is permanently deleted immediately," "we do not
use analytics," "AI providers never retain user data." None of these claims
is demonstrable from source, and several are directly contradicted by
confirmed findings above (e.g., resume text IS shared with Sarvam AI;
only three specific fields are encrypted, not "all" data).
