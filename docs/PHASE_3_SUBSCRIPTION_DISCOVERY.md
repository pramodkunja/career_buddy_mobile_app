# Phase 3 — Subscription Discovery Report (Checkpoint A)

Read-only re-verification against the current Django source, directly (not
inherited from Phase 1's report without re-checking). No file in either
project was modified to produce this report. The web repo's working tree is
unchanged from Phase 1/2 (same uncommitted `dashboard_api`/`activity_*_api`
additions, unrelated to subscription — re-confirmed, not relied upon below).

## 1. Verified backend contracts

All five `/pro/*` routes (`business_english_lms/urls.py:55-62`):

| Method | Path | View | Name |
|---|---|---|---|
| GET | `/pro/` | `career_app.views.pro_page` | `pro_page` |
| POST | `/pro/toggle/` | `career_app.views.toggle_pro_status` | `toggle_pro_status` |
| POST | `/pro/create-order/` | `career_app.views.create_razorpay_order` | `create_razorpay_order` |
| POST | `/pro/verify-payment/` | `career_app.views.verify_razorpay_payment` | `verify_razorpay_payment` |
| POST | `/pro/webhook/razorpay/` | `career_app.views.razorpay_webhook` | `razorpay_webhook` (server-to-server only, irrelevant to a mobile client) |
| GET | `/pro/invoice/<int:pk>/` | `career_app.views.payment_invoice` | `payment_invoice` (HTML invoice, out of scope) |

**`pro_page`** (`career_app/views.py:159-180`): `@login_required`. Renders
`pro.html` with `current_plan`, `subscription_active`, `subscription_expiry`,
`renewal_window`, `days_left` — **HTML only, no JSON variant exists**.
Confirmed by reading the full view body: it calls `render(...)` and returns
nothing else. This is the authoritative re-check Checkpoint A asked for —
the conclusion is unchanged from Phase 1.

**`create_razorpay_order`** (`career_app/views.py:452-520`):
`@login_required @require_POST`. Reads `request.POST.get('plan_type')` —
**requires `application/x-www-form-urlencoded`**, not a JSON body (Django's
`request.POST` is never populated from a raw JSON body). Confirmed against
the real web client's own call (`templates/pro.html:436-440`): `fetch(...,
{headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body:
'plan_type=' + encodeURIComponent(plan)})`.
- Success (200): `{success: true, order_id, amount (int, paise), currency: "INR", key_id, plan_type, plan_label, user_name, user_email}`.
- 400 `{success:false, error:"Invalid plan."}` — `plan_type` not in `PLAN_PRICING`.
- 429 `{success:false, error:"Too many payment attempts..."}` — rate-limited, 10/min/user (`ORDER_RATE_LIMIT_PER_MINUTE`).
- 400 `{success:false, error:"You are on the X Plan. Switching to a lower plan is not allowed while your subscription is active."}` — downgrade blocked.
- 500 `{success:false, error:"Payment is not configured."}` — `RAZORPAY_KEY_ID`/`SECRET` unset server-side.
- 502 `{success:false, error:"Could not start payment. Please try again."}` — Razorpay API call itself failed.

**`verify_razorpay_payment`** (`career_app/views.py:523-708`):
`@login_required @require_POST`, same form-encoded requirement. Fields:
`plan_type`, `razorpay_payment_id`, `razorpay_order_id`, `razorpay_signature`.
- Success (200): `{success: true, plan_type}`.
- 400 `{success:false, error:"Missing payment details."}`.
- 400 `{success:false, error:"Payment verification failed."}` — covers: bad HMAC signature, order/user ownership mismatch, non-INR currency, invalid plan note, amount mismatch (several distinct server-side causes collapse to this one client-facing message).
- 400 `{success:false, error:"This payment has already been used."}` — replayed `razorpay_payment_id` (checked twice: an initial `exists()` check, then a DB unique-constraint race-guard inside the activation transaction).
- **200** `{success:false, pending:true, error:"..."}` — two distinct causes (Razorpay order-fetch unreachable; order not yet `status=='paid'`). **This is a 200, not an error status** — a client must read the body's `success`/`pending` fields, not just the HTTP status, to tell a real failure from "captured, confirming shortly."
- 400 `{success:false, error:"You are on the X Plan, so this Y payment could not be applied. It has been recorded..."}` — race condition (two tabs/devices buying different tiers at once); money is real and ledgered server-side as `refund_required`, but the plan is not activated.

**Authentication/CSRF for all four POST/GET `/pro/*` views**: none carry
`@csrf_exempt` — standard Django CSRF applies (`X-CSRFToken` header + the
`csrftoken` cookie +, per `ApiClient`'s own documented HTTPS requirement, a
same-origin `Referer` header). This is **already the exact mechanism**
`ApiClient` (`lib/core/network/api_client.dart`) sets up globally today — no
new CSRF-handling code is needed, only the same
`Headers.formUrlEncodedContentType` + `readCookie('csrftoken')` pattern
already used by `lib/features/auth/data/datasources/auth_remote_datasource.dart`
(form-encoded) rather than the `FormData`/plain-Map-as-JSON pattern used
elsewhere for endpoints that read `request.body`/JSON — **using the wrong
content type here would silently 400 with "Invalid plan." on every call**,
since `request.POST` would simply be empty.

**Payment mode**: `career_app/views.py:216` comment confirms Razorpay is
wired for **TEST mode** currently. `RAZORPAY_KEY_ID`/`RAZORPAY_KEY_SECRET`
are read from environment config (`business_english_lms/settings.py:275-276`,
via `config(..., default='')`) — a local `.env` file exists (not read, to
avoid handling secrets) but whether it actually populates these two values
was not and should not be determined by inspecting its contents; `create_razorpay_order`
itself already reports `"Payment is not configured."` (500) if they're empty, so this
is self-diagnosing at runtime rather than something to infer from the file.

**`_can_access_interview`** (`career_app/views.py:127-130`):
`_get_user_plan(user) in ('normal', 'pro')`. **`_get_user_plan`**
(`views.py:106-124`): unauthenticated → `'free'`; staff/superuser → `'pro'`;
else calls `profile.enforce_expiry()` (self-healing lapse check, see below)
then reads `profile.plan_type`, with one legacy-compat fallback (`is_pro=True`
+ `plan_type=='free'` → treated as `'pro'`). **`JOB_RECOMMENDATION_LIMITS`**
(`views.py:135`): `{'normal': 5, 'pro': None}` (unlimited).

**Expiry/self-healing** (`users/models.py:102-203`, re-read in full):
`PLAN_CHOICES = [('free','Free Plan'),('normal','Normal User'),('pro','Pro User')]`;
`UserProfile.plan_type` is "the single source of truth" (its own comment,
line 117-119); `subscription_start` + a fixed `SUBSCRIPTION_DURATION_DAYS = 365`
window; `subscription_expiry()`/`is_subscription_active()`/`is_expired()`/
`days_until_expiry()` are plain datetime arithmetic off those two fields;
`enforce_expiry()` auto-reverts a lapsed paid plan to Free and sets
`pending_expiry_notice=True` (a one-time flag, consumed by a popup on the
web — no mobile equivalent exists or is built in this phase, since there is
no endpoint to read the flag from); `can_downgrade_to_free()` blocks a
manual downgrade while a paid term is still active. `_activate_plan`
(`career_app/views.py:239-261`) distinguishes a same-tier **renewal**
(stacks the new year on the remaining time) from an **upgrade/first
purchase/lapsed-repurchase** (starts a fresh year from now) via
`PLAN_RANK`/`_is_plan_downgrade` (`views.py:228-236`) — a downgrade
(buying a lower tier while a higher one is active) is rejected both at order
creation and, as a final server-side guard, at verification time too.

## 2. Current subscription status availability — re-confirmed: no suitable endpoint exists

Re-checked directly, not inherited: `pro_page` returns HTML only (§1). The
uncommitted, unpushed `dashboard_api` (`activities/views.py:351-427`,
working-tree only, not relied upon) carries a `payment_history[].is_plan_active`
field — but this is **not** a reliable "current plan" signal: it's computed
per historical payment row as `status == 'captured' and (now - created_at).days <= 365`
(`activities/views.py:326`), a simple 365-day-since-that-specific-payment
check that does **not** account for `_activate_plan`'s own renewal-stacking
logic (a renewal carries forward remaining time, so the true expiry can
differ from "365 days after this payment's own timestamp"). It also carries
no `plan_type`/`subscription_expiry`/`days_left` at the top level at all.
**Conclusion: no JSON endpoint, committed or uncommitted, provides a
structured current-plan-status response.** Per the task's explicit
instruction, this phase does **not** derive plan status from HTML text or
fabricate a status lookup.

**API dependency specification, for the backend owner** (not implemented
here — this phase stops short, as instructed):
- `GET /pro/api/` (or similar), `@login_required`-equivalent returning
  `401 {"error": "..."}` for an anonymous JSON client (same reasoning
  already documented for `dashboard_api`'s own auth check, which avoids
  Django's default 302-to-login-page redirect being silently followed by
  Dio as a 200).
- Suggested response, built from fields that already exist on `UserProfile`/
  `career_app.views._get_user_plan` — nothing new to compute: `{"plan": "free"|"normal"|"pro", "is_active": bool, "subscription_start": iso8601|null, "subscription_expiry": iso8601|null, "days_until_expiry": int|null, "pending_expiry_notice": bool, "can_access_interview": bool, "job_recommendation_limit": int|null}`.
- Error responses: `401` unauthenticated; `200` with the above shape otherwise (no other failure mode expected, since it's a pure read of existing profile fields).

## 3. Plan details — re-verified against `templates/pro.html` directly (lines 140-360)

| | Free | Normal | Pro |
|---|---|---|---|
| Price | ₹0 | ₹499/yr (+18% GST → ₹588.82 total) | ₹999/yr (+18% GST → ₹1178.82 total) |
| Grammar Module | ✅ | ✅ | ✅ |
| Activities | Only 1 activity, no full section access | Full Activities section (Speaking/Writing/Negotiation/Roleplay) | Full Activities section |
| Dashboard & learning analytics | ❌ (not listed) | ✅ | ✅ |
| Resume Parsing & ATS Score | ✅ Unlimited (available on every plan) | ✅ Unlimited | ✅ Unlimited |
| AI Mock Interview | ❌ | ✅ | ✅ (Voice/Non-Voice/Service Desk + Technical) |
| Job recommendations | — | 5 (unlocked at ≥70 mock-interview score) | Unlimited (same ≥70 score gate) |
| Direct job applications w/ auto-attached resume | ❌ | ❌ (not listed) | ✅ |

GST is **not** shown on the plan-comparison cards themselves (`price-tag` on
each card shows the base price only) — it only appears client-side, computed
from the server-returned `amount` (paise) at the checkout-confirmation step
(`templates/pro.html:513,527`: `gstRs = totalRs - (totalRs/1.18)`), after
`create_razorpay_order` has already returned the authoritative total. A
Flutter screen must do the same: display the base price up front, and only
compute/show the GST breakdown once a real order response is in hand —
never invent a GST figure ahead of that.

Renewal copy (`pro.html:260-267,348-355`): offered only within
`RENEWAL_WINDOW_DAYS = 7` of expiry (`career_app/views.py:144,172`),
matching the "your plan expires soon" notice elsewhere — out of reach for
this phase anyway, since surfacing it depends on the same missing
status endpoint from §2.

## 4. Existing Flutter integration points (re-verified directly)

- `lib/app/router/route_paths.dart:248`: `pro = '/pro'`, with a comment
  already noting "No Pro/Membership screen exists in Flutter yet — placeholder."
- `lib/app/router/app_router.dart:341-349`: `/pro` → `ComingSoonScreen`.
- 9 real call sites already push `RoutePaths.pro` today (grep-confirmed):
  `activity_detail_screen.dart:314`, `sub_activity_detail_screen.dart:403`,
  `upgrade_required_dialog.dart:31`, `free_plan_banner.dart:56`,
  `gd_locked_view.dart:37`, `jam_locked_view.dart:41`,
  `roleplay_locked_view.dart:37`, `resume_builder_screen.dart:503,599`,
  plus the nav drawer (`app_nav_drawer.dart:134`, via a generically-named
  `_goComingSoon` helper that is in fact just `Navigator.pop` +
  `context.push(path)` — not a special placeholder-only mechanism, so
  replacing `/pro`'s router mapping alone correctly upgrades every one of
  these call sites with no further changes needed). ARIA chat also already
  maps its own `/pro/` action to this same route
  (`aria_action_routes.dart:117`, confirmed in Phase 1's bot-navigation
  analysis) and reads it back for welcome-panel section-keying
  (`aria_welcome_section.dart:62`).
- `lib/features/auth/domain/entities/auth_user.dart` carries no plan field
  (confirmed, re-read in full) — left untouched in this phase, since there
  is no status source to populate it from and the subscription feature does
  not need it (plan-comparison/checkout need no stored plan state, only the
  order/verify round trip).
- Mock Interview's existing gate (`resume_html_parser.dart:79-82`, scraping
  `'Try Interview'` out of HTML) and Activities' (`activities_html_parser.dart:67`,
  scraping `'Free Plan — choose any one'`) are **untouched by this phase** —
  they already work today (the server still enforces the real gate
  regardless of what the client infers) and reworking them is out of this
  phase's scope (§9, Non-negotiable rule 9: no broad refactoring).

## 5. Dependency decision: payment SDK

The web's own checkout (`templates/pro.html:421-530`) uses Razorpay's
**Standard Checkout** JS widget — `new Razorpay(options); currentRzp.open()`
— the standard integration pattern. For Flutter, the directly equivalent,
officially-documented integration is the `razorpay_flutter` package
(published by Team Razorpay itself), which wraps the native Android/iOS
Razorpay Checkout SDKs behind the same `key_id`/`order_id`/`amount`/
`prefill`/success-and-failure-callback shape the web JS object already uses
— confirmed by cross-referencing the web's own `options` object
(`key`, `amount`, `currency`, `order_id`, `prefill: {name, email}`,
`handler`) against that package's documented `Razorpay().open(options)` API,
which takes the same field names. No alternative was found that doesn't
either reimplement signature handling client-side (explicitly forbidden —
rule 4) or require a custom webview around Razorpay's own hosted checkout
page (more fragile than the native SDK, and not what the web itself does).
**Decision: `razorpay_flutter` is the correct, justified dependency** for
driving the actual payment UI — added only in Checkpoint B, and only for
that one, narrow purpose (opening Checkout and relaying its callback); it
is never given the order amount/plan to compute, only to echo back what the
server already returned.

## 6. Checkpoint A completion

No code was changed in this checkpoint. Confirmed supported, ready for
Checkpoint B: plan/pricing/feature display (static, verified copy); order
creation; payment verification (both already JSON, already compatible with
the existing Dio/CSRF/session stack, provided requests are sent
form-urlencoded, not as JSON). Confirmed **not** supported, and explicitly
out of scope for this phase: any "your current plan is X, expiring on Y"
display — no backend contract exists for it (§2's spec is left for the
backend owner's review, not implemented speculatively).
