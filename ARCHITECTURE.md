# Career Buddy LMS — Mobile App Architecture

The Flutter client for Career Buddy LMS. It lives entirely under `Mobile_app/`
and is independent of the Django backend and web frontend in
`Career_Buddy_LMS/` — nothing here modifies those.

## Backend integration reality

The Django backend (`users/urls.py`, `users/views.py`, `users/forms.py`)
serves server-rendered HTML with **session-cookie authentication**, not a
JSON/REST API. There is no `/api/` namespace, no token auth, and no "me"
endpoint to validate a session. Concretely:

- `core/network/api_client.dart` uses `dio_cookie_manager` + `PersistCookieJar`
  so Dio behaves like a browser: cookies the server sets are persisted (under
  the app's support directory) and replayed automatically.
- Login/logout (`features/auth/data/datasources/auth_remote_datasource.dart`)
  GET the login page first to receive Django's `csrftoken` cookie, then POST
  form-encoded data with `csrfmiddlewaretoken` (repeated in the
  `X-CSRFToken` header), and infer success from the HTTP status — **302 =
  success, 200 = re-rendered form = failure** — because there's no JSON
  response to parse. Redirects are NOT auto-followed on that POST
  (`followRedirects: false`); otherwise both outcomes would look like a 200
  on the destination page.
- `AuthUser` only carries the `username` submitted at login, since there's no
  profile endpoint to fetch a real user record from.
- `AuthRepository.restoreSession()` only reflects what was cached locally in
  secure storage at last login — it cannot confirm the server-side session is
  still valid. An expired session is only discovered when a later API call
  returns 401 (mapped to `UnauthorizedException`/`UnauthorizedFailure`).
- The backend renders one generic error for both "wrong credentials" and
  "employer account used on the student portal" (`LoginForm.clean()` in
  `users/forms.py`) — the datasource surfaces one generic message rather than
  scraping the rendered HTML for which case it was.

**Do not invent endpoints.** If a feature needs backend support that doesn't
exist yet, note it in that feature's code (or ask) instead of guessing a
contract. `core/network/api_endpoints.dart` only lists paths verified against
`users/urls.py`.

## Folder structure

```
lib/
  app/            App shell: theme, router, environment config
  core/           Cross-cutting: network, errors, storage, validators, utils
  shared/         Reusable UI widgets used by more than one feature
  features/<name>/
    data/         Datasources + repository implementations
    domain/       Entities + repository interfaces
    presentation/ Riverpod controllers/providers + screens/widgets
```

A feature only gets the `data/domain/presentation` split once it's complex
enough to need it (auth, dashboard). A simple feature can start as just
`presentation/screens/`.

## State management

Riverpod (`flutter_riverpod`), using `Notifier`/`NotifierProvider` for
mutable state (see `AuthController`) and plain `Provider` for
dependency wiring (repositories, datasources, services).

`ApiClient` construction is async (the cookie jar needs a filesystem
directory), so it's built once in `main()` and injected via
`ProviderScope(overrides: [apiClientProvider.overrideWithValue(...)])` rather
than every feature awaiting a `FutureProvider`.

## Networking

`core/network/api_client.dart` wraps a single `Dio` instance:
- `ApiExceptionsInterceptor` converts every `DioException` into an
  `AppException` subtype (`core/errors/exceptions.dart`) attached as
  `err.error`, so datasources never interpret Dio/HTTP details directly.
- `core/errors/exception_mapper.dart` converts an `AppException` into a
  user-facing `Failure` (`core/errors/failures.dart`) for the presentation
  layer to render — screens should never switch on raw exceptions.
- There is no bearer-token header today (the backend has none). If it grows
  a JWT/DRF API, add a request interceptor to `ApiClient` rather than
  changing every call site.

## Theming

`app/theme/` mirrors the web app's CSS tokens (`static/css/style.css`,
navy/gold pass) rather than inventing a new palette: navy `#14213D`
primary, blue `#185ADB→#1D4ED8` for CTAs, gold `#FCA311` accent, Outfit body
font / Newsreader display font (both via `google_fonts`, matching
`templates/base.html`). Screens read from `Theme.of(context)` /
`AppColors`/`AppSpacing`/`AppRadius` — no ad-hoc hex values in screens.

## Adding a new feature

1. Confirm the actual backend contract first (route, request/response shape,
   auth requirement) by reading the Django view/urls/template — never guess.
   If no JSON endpoint exists yet, don't invent one or scrape HTML — write up
   the minimum contract needed (see `docs/BACKEND_CONTRACT_dashboard.md` for
   the template) and build the Flutter side against it anyway; a 404 against
   the real backend is a normal, honest error state until the endpoint
   exists, not a blocker.
2. Add the route to `core/network/api_endpoints.dart`.
3. `features/<name>/domain/`: entities + a repository interface.
4. `features/<name>/data/`: a datasource (throws `AppException`s) + a
   repository implementation (catches them, returns `Result<T>`). If the
   response is a JSON object, add `data/models/` with defensive `fromJson`
   parsing (missing optional fields default safely; a malformed required
   field throws rather than silently defaulting — see
   `features/dashboard/data/models/dashboard_data_model.dart`).
5. `features/<name>/presentation/`: providers wiring the above, and screens
   built from `shared/widgets/`. Use a `Notifier` with a custom sealed state
   only when the screen has states beyond loading/success/error (like auth's
   `Unknown`/`Refreshing`); otherwise prefer `AsyncNotifier`, which already
   gives you that triad plus retry/refresh for free (see
   `features/dashboard/presentation/controllers/dashboard_controller.dart`).
6. Register the screen's route in `app/router/app_router.dart` and, if it
   needs an auth guard, extend `app/router/route_guards.dart`.
