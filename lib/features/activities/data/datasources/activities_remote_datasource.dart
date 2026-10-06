import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/activity_detail.dart';
import '../../domain/entities/activity_list_data.dart';
import '../../domain/entities/sub_activity_detail.dart';
import '../activities_html_parser.dart';

/// Scrapes the real, live `/activities/...` HTML pages — see
/// `ApiEndpoints.activityList`'s doc comment for why this doesn't call the
/// JSON siblings it was originally written against (confirmed live
/// `/activities/api/...` 404s, not deployed to production, the identical
/// "documented but undeployed" pattern already confirmed for the
/// dashboard — see `dashboard_html_parser.dart`).
class ActivitiesRemoteDataSource {
  ActivitiesRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<ActivityListData> getActivityList({String? category}) async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.activityListHtml,
        queryParameters: (category == null || category.isEmpty) ? null : {'category': category},
        options: Options(responseType: ResponseType.plain),
      );
      final html = response.data;
      if (html is! String) throw const UnexpectedResponseException();
      return parseActivityListHtml(html);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    } on FormatException {
      // A redirect-to-login page landed here instead (session expired) —
      // same reasoning as `DashboardRemoteDataSource`.
      throw const UnauthorizedException();
    }
  }

  /// See `ApiEndpoints.workshopDashboardHtml`'s doc comment — the real,
  /// ungated `/activities/workshop/` page, not [getActivityList] with a
  /// `category` filter (which silently returns 0 workshop cards for a Free
  /// Plan user, since that endpoint substitutes their fixed free-catalogue
  /// selection instead of honoring `?category=` for anyone but a full-access
  /// user).
  Future<ActivityListData> getWorkshopModules() async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.workshopDashboardHtml,
        options: Options(responseType: ResponseType.plain),
      );
      final html = response.data;
      if (html is! String) throw const UnexpectedResponseException();
      return parseActivityListHtml(html);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    } on FormatException {
      throw const UnauthorizedException();
    }
  }

  /// A negative [id] (see `parseActivityListHtml`'s doc comment on
  /// `ActivitySummary.id`) marks an activity this app was never able to
  /// derive a real detail-page id for in the first place — a workshop/AI
  /// module activity, whose list card's `href` points straight at its own
  /// dedicated page/exercise rather than `activity_detail`. There is
  /// nothing to `GET` for these; the fallback below is used directly.
  Future<ActivityDetail> getActivityDetail(int id) async {
    if (id < 0) return _activityDetailFallback(id);

    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.activityDetailHtml(id),
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (status) => status != null && ((status >= 200 && status < 300) || (status >= 300 && status < 400)),
        ),
      );

      if (response.statusCode != null && response.statusCode! >= 300) {
        final location = response.headers.value('location') ?? '';
        if (location.contains('/users/login')) throw const UnauthorizedException();
        if (location.contains('locked=1')) {
          throw const ForbiddenException('This activity requires an upgrade to access.');
        }
        // `activity_detail` redirects away before rendering `detail.html`
        // for workshop/AI-module activities too (confirmed by reading the
        // view directly) — same fallback as the negative-id case above,
        // reached here when a *positive* id (e.g. a direct deep link) also
        // turns out to be one of these.
        return _activityDetailFallback(id);
      }

      final html = response.data;
      if (html is! String) throw const UnexpectedResponseException();
      return parseActivityDetailHtml(html, id: id);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    } on FormatException {
      throw const UnauthorizedException();
    }
  }

  Future<ActivityDetail> _activityDetailFallback(int id) async {
    final list = await getActivityList();
    for (final summary in list.activities) {
      if (summary.id == id) return activityDetailFromSummary(summary);
    }
    throw const NotFoundException();
  }

  Future<SubActivityDetail> getSubActivityDetail(int activityId, int subActivityId) async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.subActivityDetailHtml(activityId, subActivityId),
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (status) => status != null && ((status >= 200 && status < 300) || (status >= 300 && status < 400)),
        ),
      );

      if (response.statusCode != null && response.statusCode! >= 300) {
        final location = response.headers.value('location') ?? '';
        if (location.contains('/users/login')) throw const UnauthorizedException();
        if (location.contains('locked=1')) {
          throw const ForbiddenException('This activity requires an upgrade to access.');
        }
        throw const UnexpectedResponseException();
      }

      final html = response.data;
      if (html is! String) throw const UnexpectedResponseException();
      return parseSubActivityDetailHtml(html, activityId: activityId);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    } on FormatException {
      throw const UnauthorizedException();
    }
  }

  /// Calls the web's own `mark_sub_complete` form target directly — there
  /// is no JSON sibling for this action (see `ApiEndpoints.markSubComplete`).
  /// Verified against `activities/views.py:mark_sub_complete`: `@login_required
  /// @require_POST`, no CSRF-exempt, unconditionally marks the sub-activity
  /// completed and redirects (302) back to its detail page — there is no
  /// "rejected" response shape to parse, only redirect-on-success.
  /// Mirrors `AuthRemoteDataSource.logout()`'s pattern (read the
  /// already-set `csrftoken` cookie, send it as a header, no need for the
  /// login flow's extra GET-first step since this is only ever reached by
  /// an already-authenticated session that has a token already).
  Future<void> markSubComplete(int subActivityId) async {
    try {
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final response = await _apiClient.dio.post(
        ApiEndpoints.markSubComplete(subActivityId),
        options: Options(
          followRedirects: false,
          // 302 is the view's only success shape; let every other status
          // (4xx/5xx) still throw so `ApiExceptionsInterceptor` maps it to
          // the right `AppException` (403 locked, 404 invalid id, etc.).
          validateStatus: (status) => status != null && (status == 302 || (status >= 200 && status < 300)),
          headers: {'X-CSRFToken': csrfToken ?? ''},
        ),
      );
      if (response.statusCode != 302) {
        throw const UnexpectedResponseException();
      }
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }
}
