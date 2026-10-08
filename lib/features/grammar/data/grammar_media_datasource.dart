import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

/// Fetches Grammar's per-topic media — real slide-deck PNGs and the real
/// lesson `.mp4` — through the app's own authenticated Dio client, since
/// both `subject_slide_image`/`subject_video` are session-cookie-gated
/// (`@login_required`, confirmed live). Unlike Resume History's "View
/// File" (Batch 6), these are core lesson CONTENT meant to render inline,
/// not a secondary "open elsewhere" action, so they're fetched as bytes
/// here rather than handed to an external browser that wouldn't carry the
/// session cookie at all.
class GrammarMediaDataSource {
  GrammarMediaDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<Uint8List> fetchSlideImage(String slug, String fileName) async {
    try {
      final response = await _apiClient.dio.get<List<int>>(
        ApiEndpoints.subjectSlideImage(slug, fileName),
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? const []);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// The "Lesson slides" section's small illustration — generated fresh
  /// server-side on every request (plain XML text, not a binary asset), so
  /// fetched as a `String` rather than bytes, ready for `SvgPicture.string`.
  Future<String> fetchIllustrationSvg(String slug, int index) async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.subjectIllustration(slug, index),
        options: Options(responseType: ResponseType.plain),
      );
      return response.data ?? '';
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// Downloads the topic's video to a local temp file and returns its
  /// path. `video_player` needs a seekable local source; downloading once
  /// up front (rather than proxying a range-request stream) is the
  /// simplest correct way to get real seek support through Dio's own
  /// cookie-jar-authenticated client.
  Future<String> fetchVideoToTempFile(String slug) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/grammar_video_$slug.mp4');
      await _apiClient.dio.download(ApiEndpoints.subjectVideo(slug), file.path);
      return file.path;
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }
}
