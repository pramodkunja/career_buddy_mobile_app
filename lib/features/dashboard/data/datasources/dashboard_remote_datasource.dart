import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/dashboard_data.dart';
import '../dashboard_html_parser.dart';

/// Scrapes the real, live `/dashboard/` HTML page — see
/// `ApiEndpoints.dashboard`'s doc comment for why this doesn't call the
/// JSON sibling it was originally written against (that endpoint exists in
/// source but was confirmed, live, not deployed to production).
class DashboardRemoteDataSource {
  DashboardRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<DashboardData> getDashboard() async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.dashboardHtml,
        options: Options(responseType: ResponseType.plain),
      );
      final html = response.data;
      if (html is! String) throw const UnexpectedResponseException();
      return parseDashboardHtml(html);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    } on FormatException {
      // Most commonly: a redirect-to-login landed here instead (session
      // expired) — `isDashboardHtml` found none of the real page's markup,
      // surfaced honestly rather than as a confusing parse error, same
      // reasoning as every other HTML-scraped data source in this app.
      throw const UnauthorizedException();
    }
  }
}
