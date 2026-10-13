# Phase 13 — GST Invoice Link-Out Audit (Blocked)

Audit-only phase. **No Flutter code, test, or dependency was changed.** No
Django/web file was modified (read-only throughout). This report is the
only file created or changed this phase, and the parity matrix was left
unchanged (see §7 for why).

## Outcome up front

**Blocked — not implemented.** The web invoice route's destination,
authentication, and ownership rules are all fully and confidently verified
(Task 1, §1 below). The blocker is not uncertainty about the route — it is
that **no currently available data source gives the Flutter app the one
parameter the route requires** (the payment's Django primary key). This
was independently re-confirmed from source this phase (not assumed from
the Phase 11 audit), across every place a payment is ever rendered to a
client: the live dashboard HTML, the undeployed JSON `dashboard_api`
sibling, and every URL pattern in the project. None of them expose it. Per
this phase's own instruction, no workaround, guessed URL, or unrelated
substitute was implemented — the blocker is reported for project-owner
direction instead.

## 1. Verified web invoice flow (Task 1)

- **View**: `career_app/views.py:385-421`, `payment_invoice(request, pk)`.
  - `@login_required` (standard Django session-cookie auth, no separate
    token/API key).
  - Looks up `RazorpayPayment.objects.get_or_404(pk=pk)` — a plain Django
    auto-increment integer primary key (`career_app/models.py:162-190`'s
    `RazorpayPayment` model has no explicit `pk` override, so this is the
    default auto-id — **distinct from** `razorpay_payment_id`, the
    Razorpay-issued string transaction id like `pay_ABC123` that the
    dashboard already shows under "Transaction ID").
  - Ownership check: `if payment.user_id != request.user.id and not
    request.user.is_staff: raise Http404(...)` — a wrong/guessed `pk`
    returns a plain 404, not another user's invoice, so no enumeration
    risk exists on the web side for this app to inherit.
  - Response: renders `templates/career_app/gst_invoice.html` — a plain
    server-rendered **HTML page**, not a PDF, not JSON. The view's own doc
    comment states it is "print-ready — the customer saves it as a PDF
    from the browser" (client-side print-to-PDF, no server-side PDF
    generation to call instead).
  - No query parameters beyond the `pk` path segment; no other inputs.
- **URL**: `business_english_lms/urls.py:62`,
  `path('pro/invoice/<int:pk>/', career_views.payment_invoice,
  name='payment_invoice')` — confirmed the `<int:pk>` converter, i.e. the
  route itself only ever accepts an integer.
- **Where the link appears**: grepped every template in the repository for
  `payment_invoice` — the **only** match anywhere is
  `templates/emails/payment_receipt.html:62`'s "View GST Invoice" button,
  whose `href="{{ invoice_url }}"` is built once, server-side, at the
  moment a payment's receipt email is sent
  (`career_app/views.py:698` and the equivalent renewal-path call at
  `career_app/views.py:1773`: `invoice_url =
  request.build_absolute_uri(reverse('payment_invoice',
  args=[payment.pk]))`). **Confirmed, not assumed**: `dashboard.html`'s own
  Payment History table (`templates/dashboard.html:202-244`, read in full
  this phase) renders exactly five columns — Date, Plan Status, Amount,
  Method (hardcoded "Razorpay"), and Transaction ID
  (`payment.razorpay_payment_id`) — and nothing else; no `payment.pk`, no
  hidden attribute, no invoice link, anywhere in that markup.
- **Whether the pk is available any other way**: checked the undeployed
  JSON sibling too (`activities/views.py`'s `dashboard_api`, the
  mobile-shaped contract documented in
  `docs/BACKEND_CONTRACT_dashboard.md` but confirmed in earlier phases not
  to be live in production) — its own `payment_history` list
  (`activities/views.py:405-410`) serializes exactly `date`,
  `is_plan_active`, `amount_rupees`, `transaction_id` — **the same four
  fields as the HTML page, still no `pk`/`id`**. Grepped
  `business_english_lms/urls.py` for every `payment`/`billing`/`invoice`
  route — confirmed there is no other page (a dedicated "Billing History,"
  an account-settings page, etc.) that renders a payment list with its pk
  exposed. The payment's pk is transmitted to any client exactly once,
  ever, in the one email sent at payment time — never again, on any page,
  in any format.

## 2. Current Flutter state (Task 2)

- **No invoice action exists anywhere in Flutter** — confirmed via
  `grep -rniI "gst|invoice" lib/` (re-run fresh this phase): the only
  matches are the employer company-GSTIN registration field (unrelated —
  a different feature entirely) and the single doc-comment line in
  `lib/core/network/api_endpoints.dart:1024-1025`, which explicitly
  states no constant was added for `payment_invoice` since it was
  previously judged "neither relevant to this client" (the framing Phase
  11 reconsidered, not yet acted on).
- **`PaymentRecord`** (`lib/features/dashboard/domain/entities/payment_record.dart`)
  has exactly four fields — `date`, `isPlanActive`, `amountRupees`,
  `transactionId` — matching `dashboard.html`'s own rendered columns
  exactly, confirmed to have no `id`/`pk` field, consistent with (not a
  bug relative to) what the web page itself exposes.
  `dashboard_html_parser.dart`'s `_parsePaymentHistory` scrapes only these
  same four fields — there is nothing further to parse out, since the
  source markup itself carries nothing more.
- **No authenticated-WebView or external-browser-with-session pattern
  exists in this codebase today.** Checked both patterns this app already
  uses for "content from an authenticated/real page":
  - `webview_flutter` is used in exactly one place
    (`lib/features/skill_up/presentation/screens/skill_up_lesson_screen.dart`),
    loading Skill-Up's lesson pages — which are **unauthenticated, plain
    `static()`-served files** (confirmed in the Phase 9 audit), so that
    screen carries no session-cookie-sharing logic at all; it is not a
    precedent for serving an authenticated page.
  - Grammar's session-cookie-gated media (`grammar_media_datasource.dart`)
    is fetched as raw bytes through the app's own authenticated Dio/cookie
    jar and rendered natively (an image/video widget) — not loaded as a
    full HTML page in any browser or WebView.
  - Neither pattern, as it exists today, is "opening a Django URL in an
    external browser" — and per this phase's own caution, that would not
    work anyway: the system browser has its own, separate cookie store
    from the app's Dio cookie jar, so an external-browser open of
    `pro/invoice/<pk>/` would hit Django's login page, not the invoice,
    exactly the trap this phase's instructions warned against assuming
    away.

## 3. Why this blocks implementation (Task 3 — not performed)

Every one of Task 1's five verification points was fully established with
high confidence (route, auth, ownership, response shape, per-payment
association) — this is **not** a case of insufficient evidence about the
destination. The blocker is narrower and more specific: **the one dynamic
input the route requires (the payment's Django `pk`) has no path into the
Flutter app today**, confirmed across every page and every data contract
(live HTML, undeployed JSON) that could plausibly carry it.

Implementing "the smallest verified solution" would require either:
- Inventing/guessing a `pk` (e.g., assuming it correlates with Payment
  History's row order or date) — explicitly forbidden ("Do not guess URLs
  or invent endpoints," "Do not substitute an unverified URL"), and
  concretely unsafe besides: Django pks are assigned in creation order
  across **all** users' payments, not just this user's, so no stable,
  derivable relationship to a per-user row index exists; and
- A backend change (exposing `pk` on the dashboard page or the JSON
  contract) — explicitly out of scope this phase ("Do not change backend
  APIs, Django views, templates...").

Per this phase's own completion criteria, the correct action here is to
stop and report the blocker, not substitute a workaround.

## 4. Tests and verification

No code was changed this phase, so no new tests were written and no
build/analyze/test run was required to validate a change. As a baseline
sanity check only (confirming this audit itself didn't inadvertently touch
anything), `git status` was checked before and after:

```
git status --short -- lib/ test/ docs/
```
Result: identical before and after except for this new report file —
confirmed no Flutter source, test, or dependency file was touched.

## 5. Remaining limitations / what would unblock this

- **Unblocking requires one of**: (a) a backend change exposing each
  payment's `pk` (or an equally stable, owner-scoped identifier) on the
  dashboard's live HTML or the `dashboard_api` JSON contract — explicitly
  out of scope for a Flutter-only phase and would need backend-owner
  sign-off and a production deploy; or (b) a product decision that the
  existing email link is the intended and sufficient distribution channel
  for this feature on mobile too (i.e., accept that mobile users retrieve
  their GST invoice the same way web users without a dashboard link
  already do — via the receipt email, which mobile's own email client can
  already open in a normal browser where the user's own logged-in web
  session, if any, or a login prompt, would apply exactly as it does for
  any web user who receives that email) — this needs no code change at
  all, only a documentation/communication decision.
- Given (b) doesn't change any system behavior, there is nothing to
  implement or test for it; it would be an explicit acknowledgment that
  web itself already treats the invoice as "email-distributed, not
  dashboard-linked" (per Task 1's own finding) and that mobile matching
  that distribution channel is not a gap to close, rather than a Flutter
  change.
- No live device, emulator, or production account was used to produce any
  finding in this report — every claim is sourced from the file reads
  cited above, performed this phase.

## 6. Confirmations

- **Django/web repository was not modified** — read-only access only
  this phase; no production data was read, mutated, or exposed (no real
  payment id, user id, or invoice content from a live account appears
  anywhere in this report).
- **No Flutter application source, test, or dependency file was created,
  edited, or deleted.**
- No credentials, session cookies, or sensitive URLs were logged or
  included in this report — every URL cited is a route pattern
  (`pro/invoice/<int:pk>/`), never a real, resolvable instance of one.
- No build, release artifact, signing, or deploy step was run.
- No dependency was added (none was needed to reach this conclusion).

## 7. Parity matrix — no change made

`docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md`'s existing "GST invoice access"
row already states the exact blocker this phase independently re-confirmed
("A payment `pk` would need to be exposed in the scraped/JSON
payment-history data (currently absent on both scrape and the undeployed
JSON)") and already classifies the feature as **Missing**, with the
reasoning that web's own limited exposure (email-only) bounds the impact.
This phase's fresh verification **confirms, rather than contradicts or
supersedes**, that existing row — so per this phase's instruction to
update the matrix "only if the implementation or new evidence justifies a
status change," no edit was made.

---

Phase 13 complete as an audit: **blocked, documented, nothing implemented
or guessed.** Awaiting project-owner direction — specifically, a decision
between §5's options (a) a backend change to expose a stable payment
identifier (out of scope for a Flutter-only phase) or (b) treating the
existing email-distribution channel as sufficient and closing this gap
without any code change.
