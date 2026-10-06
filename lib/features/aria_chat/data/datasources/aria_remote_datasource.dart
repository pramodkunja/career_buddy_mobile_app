import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/aria_chat_message.dart';
import '../../domain/entities/aria_chat_reply.dart';
import '../../domain/entities/aria_stream_event.dart';
import '../../domain/entities/aria_voice.dart';

const _genericErrorMessage = "Something went wrong on our end. Please try again.";

/// Talks to `ApiEndpoints.riyaChat` (`riya_bot/views.py:riya_chat`) — see
/// that constant's doc comment for the full, source-verified contract.
///
/// Dio's default request transformer form-url-encodes a plain
/// `Map<String, dynamic>` unless the content type is explicitly set to
/// JSON (`Transformer.defaultTransformRequest`) — the view only ever calls
/// `json.loads(request.body)`, so [Options.contentType] is set explicitly
/// below; sending the default form-encoded body would make every call
/// 500 with the view's generic error.
class AriaRemoteDataSource {
  AriaRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<AriaChatReply> sendMessage({
    required String message,
    required String page,
    required String path,
    required bool isEmployer,
    required String conversationId,
    required List<AriaChatMessage> history,
  }) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        ApiEndpoints.riyaChat,
        data: {
          'message': message,
          'page': page,
          'path': path,
          'hash': '',
          'input_mode': 'text',
          'language': 'english',
          'is_employer': isEmployer,
          'conversation_id': conversationId,
          'history': [
            for (final turn in history)
              {
                'role': turn.role == AriaMessageRole.user ? 'user' : 'assistant',
                'content': turn.content,
              },
          ],
        },
        options: Options(contentType: Headers.jsonContentType),
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnexpectedResponseException();
      }

      if (data['success'] == false) {
        final message = data['error'] as String? ?? _genericErrorMessage;
        throw ValidationException(const {}, message);
      }

      final reply = data['reply'] as String? ?? data['message'] as String? ?? '';
      final actionsJson = data['actions'] as List<dynamic>? ?? const [];
      final actions = [
        for (final entry in actionsJson)
          if (entry is Map<String, dynamic>) AriaChatAction.fromJson(entry),
      ];

      return AriaChatReply(reply: reply, actions: actions, source: data['source'] as String?);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// Talks to `ApiEndpoints.riyaChatStream` — see that constant's doc
  /// comment for the full, source-verified SSE contract. Yields
  /// [AriaStreamToken] for every `{"t": ...}` event, then exactly one
  /// [AriaStreamComplete] for whichever complete-event shape the server
  /// sends, then closes the stream — mirroring the real `[DONE]` sentinel
  /// without surfacing it as its own event (nothing downstream needs it).
  ///
  /// A malformed `data:` line (fails `jsonDecode`) is skipped rather than
  /// failing the whole stream — the real web's own parser does the same
  /// (`try { parsed = JSON.parse(data); } catch { continue; }`,
  /// `BOTscript.js`). A connection that closes before any complete event
  /// arrived surfaces as an [UnexpectedResponseException] thrown into the
  /// stream, same failure shape [sendMessage] already uses for a bad
  /// response.
  Stream<AriaStreamEvent> sendMessageStream({
    required String message,
    required String page,
    required String path,
    required bool isEmployer,
    required String conversationId,
    required List<AriaChatMessage> history,
    required String language,
  }) async* {
    Response<ResponseBody> response;
    try {
      response = await _apiClient.dio.post<ResponseBody>(
        ApiEndpoints.riyaChatStream,
        data: {
          'message': message,
          'page': page,
          'path': path,
          'hash': '',
          'input_mode': 'text',
          'language': language,
          'is_employer': isEmployer,
          'conversation_id': conversationId,
          'history': [
            for (final turn in history)
              {
                'role': turn.role == AriaMessageRole.user ? 'user' : 'assistant',
                'content': turn.content,
              },
          ],
        },
        options: Options(contentType: Headers.jsonContentType, responseType: ResponseType.stream),
      );
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }

    final byteStream = response.data?.stream;
    if (byteStream == null) throw const UnexpectedResponseException();

    var sawComplete = false;
    try {
      final lines = const LineSplitter().bind(utf8.decoder.bind(byteStream));
      await for (final line in lines) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data: ')) continue;
        final payload = trimmed.substring(6).trim();
        if (payload == '[DONE]') break;

        final Map<String, dynamic> parsed;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is! Map<String, dynamic>) continue;
          parsed = decoded;
        } on FormatException {
          continue;
        }

        if (parsed.containsKey('reply') || parsed['done'] == true) {
          final actionsJson = parsed['actions'] as List<dynamic>? ?? const [];
          final actions = [
            for (final entry in actionsJson)
              if (entry is Map<String, dynamic>) AriaChatAction.fromJson(entry),
          ];
          yield AriaStreamComplete(
            AriaChatReply(
              reply: parsed['reply'] as String? ?? '',
              actions: actions,
              source: parsed['source'] as String?,
            ),
          );
          sawComplete = true;
        } else if (parsed['t'] is String) {
          yield AriaStreamToken(parsed['t'] as String);
        }
      }
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }

    if (!sawComplete) throw const UnexpectedResponseException();
  }

  /// `ApiEndpoints.riyaVoiceTranscribe` — see that constant's doc comment
  /// for the full contract, including the confirmed real-web bug this
  /// client deliberately does not reproduce (reads `text` at the top
  /// level, not `data.text`).
  Future<AriaVoiceTranscription> transcribeVoice({
    required String audioBase64,
    required String mimeType,
    required String language,
  }) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        ApiEndpoints.riyaVoiceTranscribe,
        data: {'audio': audioBase64, 'mime_type': mimeType, 'language': language},
        options: Options(contentType: Headers.jsonContentType),
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) throw const UnexpectedResponseException();

      if (data['success'] != true) {
        final message = data['error'] as String? ?? 'Voice transcription is temporarily unavailable.';
        throw ValidationException(const {}, message);
      }

      final text = (data['text'] as String? ?? '').trim();
      return AriaVoiceTranscription(text: text, source: data['source'] as String? ?? 'sarvam');
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `ApiEndpoints.riyaTts` — see that constant's doc comment for the full
  /// contract, including the confirmed real-web bug this client
  /// deliberately does not reproduce (reads `audio` at the top level, not
  /// `data.audio`). Returns `null` (not an error) whenever the server has
  /// no audio to offer — matching the real `{success, available}` both
  /// being `false` for a non-error "nothing to play" response — so the
  /// caller can fall back to on-device voice synthesis exactly like the
  /// real web's own `.catch(() => speakWithBrowser(text))` does.
  Future<String?> synthesizeSpeech({required String text, required String language}) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        ApiEndpoints.riyaTts,
        data: {'text': text, 'language': language},
        options: Options(contentType: Headers.jsonContentType, validateStatus: (_) => true),
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      if (data['success'] != true) return null;
      return data['audio'] as String?;
    } on DioException {
      return null;
    }
  }
}
