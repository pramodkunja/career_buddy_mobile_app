# Phase 74 — Employer Identity & Company Profile Data Parity Audit

## Scope

Phase 73 found that the employer nav drawer's identity tile shows the
authenticated user's username and a generic business icon, while the real
updated Django site's employer sidebar shows the company name, company logo,
and a static "Recruiter Account" label — and deliberately deferred fixing it
pending an investigation into whether Flutter already has access to this
data. This phase performs that investigation and implements the smallest
safe correction the evidence supports.

## Investigation method

A read-only research subagent was dispatched first, with an explicit
instruction not to edit any file, to trace both the Django source and the
Flutter data flow and report back a field-mapping table and a Case A/B/C
conclusion. Its findings were then independently re-verified against the
actual source before any code was written: `templates/employer_base.html`
and `templates/employer/profile_form.html`'s own `{% extends %}` header were
read directly, and the exact Flutter files it named (`auth_user.dart`,
`employer_profile_html_parser.dart`, `employer_profile_form.dart`,
`employer_profile_controller.dart`, `auth_controller.dart`) were read in
full before any edit was made.

## Django identity source and field mapping

`templates/employer_base.html:198-213` (the real sidebar identity block):

```html
<div class="sidebar-company-icon">
    {% if request.user.employer_profile.company_logo %}
    <img src="{{ request.user.employer_profile.company_logo.url }}" alt="Company Logo"
        style="width: 100%; height: 100%; object-fit: cover; border-radius: inherit;">
    {% else %}
    <i class="fas fa-building"></i>
    {% endif %}
</div>
<h2 ... title="{{ request.user.employer_profile.company_name|default:'Employer Portal' }}">
    {{ request.user.employer_profile.company_name|default:"Employer Portal" }}
</h2>
<span class="badge ...">Recruiter Account</span>
```

| Website field | Django source | Flutter equivalent | Current availability |
|---|---|---|---|
| Company name | `EmployerProfile.company_name` (required `CharField`) | `EmployerProfileFormData.companyName` | Already parsed by `parseEmployerProfileFormHtml`, but only read by the Company Profile screen's own controller — not wired to the drawer |
| Company logo | `EmployerProfile.company_logo` (`ImageField`, blank/null allowed) | *(none, before this phase)* | Not fetched at all — the only Flutter-side logo field was write-only (`EmployerProfileSubmission.companyLogoPath`) |
| "Recruiter Account" label | Literal template text | *(none)* | Static string, not data — trivial to reproduce verbatim |
| Name/logo fallback | `|default:"Employer Portal"` filter; `{% else %}` icon | *(none, before this phase)* | The exact fallback text/behavior the real site uses when there's no profile yet |

The login/session flow was confirmed to carry none of this:
`AuthUser`'s own doc comment states the backend has no profile/"me" JSON
endpoint (session-cookie auth only) — this rules out Case A (data already on
the authenticated user object) entirely.

## The key finding: the Company Profile screen's own fetch already contains the sidebar markup

`templates/employer/profile_form.html:1` is `{% extends 'employer_base.html'
%}` — confirmed by reading the template's own first line directly. This
means the exact HTTP response Flutter already fetches for the Company
Profile screen (`GET /employer/employer/profile/edit/`, parsed today by
`parseEmployerProfileFormHtml` for the form's own fields) **already contains
the sidebar's identity-block markup too** — the same `<img ... alt="Company
Logo">` / `<h2>...company_name...</h2>` shown above — because Django renders
the full page (base template + content block) in one response.

This is a **Case B** situation for both fields, not Case C: an existing
repository/provider (`EmployerProfileRepository.getProfileForm` via
`employerProfileControllerProvider`) already fetches a response that
carries this data; it simply wasn't being extracted or read by the drawer.
No new endpoint, new request pattern, or second competing data source is
needed for either the name or the logo — both come from the one response the
drawer's own "Company Profile" tap already targets.

## Flutter data-flow findings

- `EmployerProfileController` (`AsyncNotifierProvider.family<...,
  bool>`, keyed by `isCreate`) already fetches and caches
  `EmployerProfileFormData` for `isCreate: false` whenever anything reads
  `employerProfileControllerProvider(false)`.
- `AuthController._invalidateUserScopedProviders()` already calls
  `ref.invalidate(employerProfileControllerProvider)` on every
  login/logout/register/loginEmployer/registerEmployer transition
  (`auth_controller.dart:113`, confirmed by direct reading) — the exact
  general-purpose cross-account-leak guard this app already uses for every
  other `.family` user-scoped controller (Dashboard, Resume history, etc.).
  Reading this provider from the drawer inherits that existing protection
  for free; no new invalidation logic was needed.
- The drawer's own existing "Company Profile" tap already assumes
  `isCreate: false` unconditionally (a pre-existing Phase 73 behavior, not
  introduced here) — reading `employerProfileControllerProvider(false)` for
  the identity tile is consistent with that existing assumption, not a new
  one.
- No existing image-rendering widget/avatar component for a profile photo
  exists in this codebase; the one existing `Image.network(...,
  errorBuilder: ...)` precedent (`employer_phone_input_field.dart`, for a
  country flag icon) was used as the direct model for the logo's fallback
  handling — a standard Flutter widget, not a new dependency.
- `resolveMediaUrl` (`core/media/media_url_resolver.dart`) is the
  already-established helper for exactly this kind of server-relative
  `MEDIA_URL` path (already used for resume/video URLs) — reused as-is, no
  new URL-resolution logic was written.

## Chosen implementation path and why it is safe

**Case B for both company name and company logo** — reuse the existing
`employerProfileControllerProvider(false)` / `parseEmployerProfileFormHtml`
fetch, extending the parser to also extract the logo URL already present in
the same already-fetched HTML response.

This is safe because:
- It introduces no new network request: the drawer watches the same
  provider/response the Company Profile screen already uses.
- It introduces no second, competing data source: company name is read from
  the same `EmployerProfileFormData.companyName` field the form itself
  displays; logo comes from the same response, scraped by the same parser
  function.
- Cross-session safety is inherited from an existing, independently-tested
  mechanism (`_invalidateUserScopedProviders`), not reinvented.
- The fallback behavior (generic icon + "Employer Portal" text) is not
  invented — it is the real site's own literal `|default:"Employer Portal"`
  text and `{% else %}` icon, used whenever the data hasn't loaded yet or no
  profile exists.

## Unsupported or ambiguous field mappings

None. Both fields needed for this phase (company name, company logo) were
confirmed available through the existing fetch; nothing was blocked.

## Work blocked by a missing API or data contract

None for this phase's scope. The real site's "Recruiter Account" label is a
static string, not a data field, so it required no data-flow investigation
— it was added verbatim.
