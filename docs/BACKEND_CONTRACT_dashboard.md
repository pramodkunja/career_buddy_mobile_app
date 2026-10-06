# Proposed backend contract: dashboard JSON API

**Status: not implemented.** This documents the minimum backend change
needed for the Flutter dashboard to show real data. No Django code has been
written for this — it needs review/approval before implementation.

## Why this is needed

The web student dashboard (`/dashboard/`, `activities/views.py`
`dashboard()`, `@login_required`, renders `templates/dashboard.html`) is
100% server-rendered HTML. There is no JSON endpoint returning this data, so
the Flutter dashboard has nothing to consume yet. This proposes a JSON
sibling that serializes the *exact same* data the HTML view already
computes — no new queries, no new business logic.

## Endpoint

**`GET /dashboard/api/`**

- Same data as `dashboard()`'s context — see `activities/views.py:91-334`
  for the source queries/fields being mirrored.
- **Auth: must return a clean 401, not a redirect.** Django's default
  `@login_required` sends anonymous requests a 302 to the login page. A
  JSON client following that redirect (as Dio does by default) receives a
  200 with an HTML body — indistinguishable from success without extra
  handling. Instead, check `request.user.is_authenticated` explicitly and
  return `JsonResponse({'error': 'Not authenticated'}, status=401)` for
  anonymous requests. (This is the same class of problem already solved on
  the Flutter side for `/users/login/`, where redirects are deliberately
  not auto-followed for the same reason.)
- No query parameters, no pagination (mirrors the HTML view, which has
  none).

## Response shape

```json
{
  "stats": {
    "completed_count": 3,
    "in_progress_count": 2,
    "total_activities": 20,
    "total_score": 145
  },
  "activities": [
    {
      "activity_id": 4,
      "title": "Business Vocabulary",
      "completion_rate": 60.0,
      "completed_sub_activities": 3,
      "total_sub_activities": 5,
      "started_at": "2026-09-01T10:00:00Z"
    }
  ],
  "recent_results": [
    {
      "title": "Negotiation Quiz",
      "activity_name": "Negotiation",
      "score": 8,
      "max_score": 10,
      "percentage": 80.0,
      "date": "2026-09-15T14:30:00Z"
    }
  ],
  "recommended_jobs": [
    {
      "title": "Customer Support Executive",
      "company_name": "Acme Corp",
      "skills": ["Communication", "English", "CRM"],
      "location": "Remote",
      "job_type": "Full-time",
      "experience_level": "0-1 years",
      "salary_display": "₹2.5L - ₹3.5L"
    }
  ],
  "payment_history": [
    {
      "date": "2026-08-01T00:00:00Z",
      "is_plan_active": true,
      "amount_rupees": 499,
      "transaction_id": "pay_ABC123"
    }
  ],
  "interview_score": 78
}
```

### Field sources (mirroring the existing view — nothing new)

| JSON field | Existing source |
|---|---|
| `stats.completed_count` | `completed_activity_count` (`activities/views.py:205-248`) |
| `stats.in_progress_count` | `in_progress_activity_count` (same loop) |
| `stats.total_activities` | `Activity.objects.filter(is_active=True).count()` (`activities/views.py:330`) |
| `stats.total_score` | sum of `UserExerciseResult.score` + `ScoreRecord.score` (`activities/views.py:273-275`) |
| `activities[]` | `activities_with_progress` (`activities/views.py:205-271`) — `activity_id`/`title` from the `Activity`, rest as computed there |
| `recent_results[]` | `recent_results` (`activities/views.py:153-191`, merged `UserExerciseResult` + `ScoreRecord`, top 5) |
| `recommended_jobs[]` | `recommended_jobs` (`career_app/views.py:39-99` via `activities/views.py:286-304`) — only non-empty when the user is eligible (passed AI interview, paid plan); return `[]` otherwise, no separate "not eligible" flag needed |
| `payment_history[]` | `payment_history` (`activities/views.py:308-321`, `RazorpayPayment`, top 10) |
| `interview_score` | `passed_session.total_score if passed_session else None` (`activities/views.py:283-297`) |

### Intentionally omitted (not needed by the mobile client yet)

- `activities[].direct_url` — a Django `reverse()`'d path; the Flutter app
  has no matching in-app destination for every activity type yet.
- Payment `method` — always the literal string `"Razorpay"` in the current
  template; the mobile UI can hardcode the same label instead of it being a
  wire field.

## Client-side behavior already built to consume this

- `DashboardRemoteDataSource` (`lib/features/dashboard/data/datasources/dashboard_remote_datasource.dart`)
  treats a non-JSON-object response body (e.g. HTML) as an
  `UnexpectedResponseException`, and a 401 as `UnauthorizedException` →
  triggers the existing sign-out flow. A 404 (the current reality, since
  this endpoint doesn't exist) is already mapped to `NotFoundFailure` by
  `ApiExceptionsInterceptor` and shown as a normal retryable error.
