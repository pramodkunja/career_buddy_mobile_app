import 'dart:convert';
import 'dart:typed_data';

import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/features/aria_chat/data/datasources/aria_remote_datasource.dart';
import 'package:career_buddy_lms/features/aria_chat/domain/entities/aria_chat_message.dart';
import 'package:career_buddy_lms/features/aria_chat/domain/entities/aria_stream_event.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_http_client_adapter.dart';

const _jsonHeaders = {
  'content-type': ['application/json'],
};

class _CapturingHttpClientAdapter implements HttpClientAdapter {
  _CapturingHttpClientAdapter({required this.statusCode, this.body = ''});

  final int statusCode;
  final String body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(body, statusCode, headers: _jsonHeaders);
  }

  @override
  void close({bool force = false}) {}
}

/// Simulates a connectivity failure (no server reachable at all) — the
/// adapter itself throws, same as `dio`'s real `IOHttpClientAdapter` would
/// on a `SocketException`.
class _ThrowingHttpClientAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
  }

  @override
  void close({bool force = false}) {}
}

AriaRemoteDataSource _dataSource({required int statusCode, required String body, HttpClientAdapter? adapter}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = adapter ?? FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: _jsonHeaders)
    ..interceptors.add(ApiExceptionsInterceptor());
  return AriaRemoteDataSource(ApiClient.forTesting(dio));
}

void main() {
  group('AriaRemoteDataSource.sendMessage', () {
    test('parses a successful reply, including actions and source', () async {
      final ds = _dataSource(
        statusCode: 200,
        body: jsonEncode({
          'reply': 'Hi! How can I help?',
          'message': 'Hi! How can I help?',
          'actions': [
            {'key': 'resume_builder', 'label': 'Resume Builder', 'route': '/resume-builder/'},
          ],
          'source': 'ai',
          'success': true,
          'speak': true,
          'audio': null,
        }),
      );

      final reply = await ds.sendMessage(
        message: 'hello',
        page: 'home',
        path: '/home',
        isEmployer: false,
        conversationId: 'conv-1',
        history: const [],
      );

      expect(reply.reply, 'Hi! How can I help?');
      expect(reply.source, 'ai');
      expect(reply.actions, hasLength(1));
      expect(reply.actions.single.key, 'resume_builder');
      expect(reply.actions.single.label, 'Resume Builder');
      expect(reply.actions.single.route, '/resume-builder/');
    });

    test('falls back to "message" when "reply" is absent', () async {
      final ds = _dataSource(statusCode: 200, body: jsonEncode({'message': 'Fallback text', 'success': true}));

      final reply = await ds.sendMessage(
        message: 'hi',
        page: 'home',
        path: '/home',
        isEmployer: false,
        conversationId: 'conv-1',
        history: const [],
      );

      expect(reply.reply, 'Fallback text');
    });

    test('a 200 response with "success": false throws with the server\'s error message', () async {
      final ds = _dataSource(
        statusCode: 200,
        body: jsonEncode({'success': false, 'error': 'Something went wrong on our end. Please try again.'}),
      );

      await expectLater(
        ds.sendMessage(
          message: 'hi',
          page: 'home',
          path: '/home',
          isEmployer: false,
          conversationId: 'conv-1',
          history: const [],
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Something went wrong on our end. Please try again.',
          ),
        ),
      );
    });

    test('throws UnexpectedResponseException when the body is not a JSON object', () async {
      final ds = _dataSource(statusCode: 200, body: '"just a string"');

      await expectLater(
        ds.sendMessage(
          message: 'hi',
          page: 'home',
          path: '/home',
          isEmployer: false,
          conversationId: 'conv-1',
          history: const [],
        ),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test('a non-200 status maps to a typed AppException via the shared interceptor', () async {
      final ds = _dataSource(statusCode: 500, body: '');

      await expectLater(
        ds.sendMessage(
          message: 'hi',
          page: 'home',
          path: '/home',
          isEmployer: false,
          conversationId: 'conv-1',
          history: const [],
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test('sends the exact request shape as JSON, including history and conversation_id', () async {
      final adapter = _CapturingHttpClientAdapter(statusCode: 200, body: jsonEncode({'reply': 'ok', 'success': true}));
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);

      await ds.sendMessage(
        message: 'What is Skill Up?',
        page: 'skill_up',
        path: '/skill-up',
        isEmployer: true,
        conversationId: 'conv-42',
        history: const [
          AriaChatMessage(role: AriaMessageRole.assistant, content: 'Hello there!'),
          AriaChatMessage(role: AriaMessageRole.user, content: 'Hi'),
        ],
      );

      expect(adapter.lastRequest, isNotNull);
      // Must be sent as real JSON (application/json), not Dio's default
      // form-url-encoded body — the Django view only ever calls
      // json.loads(request.body).
      expect(adapter.lastRequest!.contentType, contains('application/json'));

      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sent['message'], 'What is Skill Up?');
      expect(sent['page'], 'skill_up');
      expect(sent['path'], '/skill-up');
      expect(sent['hash'], '');
      expect(sent['input_mode'], 'text');
      expect(sent['language'], 'english');
      expect(sent['is_employer'], true);
      expect(sent['conversation_id'], 'conv-42');
      expect(sent['history'], [
        {'role': 'assistant', 'content': 'Hello there!'},
        {'role': 'user', 'content': 'Hi'},
      ]);
    });
  });

  group('AriaRemoteDataSource.sendMessageStream', () {
    AriaRemoteDataSource streamDataSource(String sseBody, {int statusCode = 200}) {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: statusCode,
          body: sseBody,
          headers: {
            'content-type': ['text/event-stream'],
          },
        )
        ..interceptors.add(ApiExceptionsInterceptor());
      return AriaRemoteDataSource(ApiClient.forTesting(dio));
    }

    Future<List<dynamic>> collect(AriaRemoteDataSource ds) => ds
        .sendMessageStream(
          message: 'hi',
          page: 'home',
          path: '/home',
          isEmployer: false,
          conversationId: 'conv-1',
          history: const [],
          language: 'english',
        )
        .toList();

    test('parses streaming tokens followed by a done-complete event', () async {
      final ds = streamDataSource(
        'data: {"t": "Hel"}\n\n'
        'data: {"t": "lo"}\n\n'
        'data: {"done": true, "reply": "Hello", "actions": [], "source": "ai"}\n\n'
        'data: [DONE]\n\n',
      );

      final events = await collect(ds);

      expect(events, hasLength(3));
      expect((events[0] as AriaStreamToken).raw, 'Hel');
      expect((events[1] as AriaStreamToken).raw, 'lo');
      final complete = events[2] as AriaStreamComplete;
      expect(complete.reply.reply, 'Hello');
      expect(complete.reply.source, 'ai');
    });

    test('parses a fast-path single complete event with no preceding tokens', () async {
      final ds = streamDataSource(
        'data: {"reply": "Opening home.", "actions": [{"key": "home", "label": "Home", "route": "/"}], "source": "intent"}\n\n'
        'data: [DONE]\n\n',
      );

      final events = await collect(ds);

      expect(events, hasLength(1));
      final complete = events.single as AriaStreamComplete;
      expect(complete.reply.reply, 'Opening home.');
      expect(complete.reply.actions.single.key, 'home');
      expect(complete.reply.source, 'intent');
    });

    test('skips a malformed data line instead of failing the whole stream', () async {
      final ds = streamDataSource(
        'data: {"t": "Hel"}\n\n'
        'data: not-json-at-all\n\n'
        'data: {"t": "lo"}\n\n'
        'data: {"reply": "Hello", "actions": [], "source": "ai"}\n\n'
        'data: [DONE]\n\n',
      );

      final events = await collect(ds);

      expect(events, hasLength(3));
      expect((events[0] as AriaStreamToken).raw, 'Hel');
      expect((events[1] as AriaStreamToken).raw, 'lo');
    });

    test('throws UnexpectedResponseException if the stream ends with no complete event', () async {
      final ds = streamDataSource('data: {"t": "Hel"}\n\ndata: [DONE]\n\n');

      await expectLater(collect(ds), throwsA(isA<UnexpectedResponseException>()));
    });

    test('a non-200 status maps to a typed AppException via the shared interceptor', () async {
      final ds = streamDataSource('', statusCode: 500);

      await expectLater(collect(ds), throwsA(isA<ServerException>()));
    });

    test('sends the exact request shape including language and input_mode', () async {
      final adapter = _CapturingHttpClientAdapter(statusCode: 200, body: 'data: {"reply": "ok"}\n\ndata: [DONE]\n\n');
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(ApiExceptionsInterceptor());
      final ds = AriaRemoteDataSource(ApiClient.forTesting(dio));

      await ds
          .sendMessageStream(
            message: 'What is Skill Up?',
            page: 'skill_up',
            path: '/skill-up',
            isEmployer: true,
            conversationId: 'conv-42',
            history: const [AriaChatMessage(role: AriaMessageRole.user, content: 'Hi')],
            language: 'hindi',
          )
          .toList();

      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(adapter.lastRequest!.contentType, contains('application/json'));
      expect(sent['message'], 'What is Skill Up?');
      expect(sent['input_mode'], 'text');
      expect(sent['language'], 'hindi');
      expect(sent['is_employer'], true);
      expect(sent['conversation_id'], 'conv-42');
      expect(sent['history'], [
        {'role': 'user', 'content': 'Hi'},
      ]);
    });
  });

  group('AriaRemoteDataSource.transcribeVoice', () {
    test('parses a successful transcription, reading "text"/"source" at the top level (not under "data")', () async {
      final ds = _dataSource(
        statusCode: 200,
        body: jsonEncode({'success': true, 'text': 'What jobs are open?', 'source': 'sarvam'}),
      );

      final result = await ds.transcribeVoice(audioBase64: 'ZmFrZS1hdWRpbw==', mimeType: 'audio/m4a', language: 'english');

      expect(result.text, 'What jobs are open?');
      expect(result.source, 'sarvam');
    });

    test('a "success": false response throws with the server\'s error message', () async {
      final ds = _dataSource(
        statusCode: 200,
        body: jsonEncode({'success': false, 'error': 'Voice transcription failed.', 'source': 'stt_error'}),
      );

      await expectLater(
        ds.transcribeVoice(audioBase64: 'ZmFrZQ==', mimeType: 'audio/m4a', language: 'english'),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', 'Voice transcription failed.')),
      );
    });

    test('an empty transcript is returned as empty text, not an error', () async {
      final ds = _dataSource(statusCode: 200, body: jsonEncode({'success': true, 'text': '', 'source': 'sarvam'}));

      final result = await ds.transcribeVoice(audioBase64: 'ZmFrZQ==', mimeType: 'audio/m4a', language: 'english');

      expect(result.text, isEmpty);
    });

    test('throws UnexpectedResponseException when the body is not a JSON object', () async {
      final ds = _dataSource(statusCode: 200, body: '"just a string"');

      await expectLater(
        ds.transcribeVoice(audioBase64: 'ZmFrZQ==', mimeType: 'audio/m4a', language: 'english'),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test('a non-200 status maps to a typed AppException via the shared interceptor', () async {
      final ds = _dataSource(statusCode: 500, body: '');

      await expectLater(
        ds.transcribeVoice(audioBase64: 'ZmFrZQ==', mimeType: 'audio/m4a', language: 'english'),
        throwsA(isA<ServerException>()),
      );
    });

    test('a network exception propagates as a typed AppException', () async {
      final ds = AriaRemoteDataSource(
        ApiClient.forTesting(
          Dio(BaseOptions(baseUrl: 'http://test'))
            ..httpClientAdapter = _ThrowingHttpClientAdapter()
            ..interceptors.add(ApiExceptionsInterceptor()),
        ),
      );

      await expectLater(
        ds.transcribeVoice(audioBase64: 'ZmFrZQ==', mimeType: 'audio/m4a', language: 'english'),
        throwsA(isA<AppException>()),
      );
    });

    test('sends the exact request shape as JSON — audio/mime_type/language, no "data" wrapper, no file_name', () async {
      final adapter = _CapturingHttpClientAdapter(
        statusCode: 200,
        body: jsonEncode({'success': true, 'text': 'hi', 'source': 'sarvam'}),
      );
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);

      await ds.transcribeVoice(audioBase64: 'ZmFrZS1hdWRpbw==', mimeType: 'audio/m4a', language: 'hindi');

      expect(adapter.lastRequest!.contentType, contains('application/json'));
      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sent, {'audio': 'ZmFrZS1hdWRpbw==', 'mime_type': 'audio/m4a', 'language': 'hindi'});
    });
  });

  group('AriaRemoteDataSource.synthesizeSpeech', () {
    test('parses "audio" (base64) at the top level (not under "data") on success', () async {
      final ds = _dataSource(
        statusCode: 200,
        body: jsonEncode({'success': true, 'audio': 'ZmFrZS13YXY=', 'language': 'english', 'available': true}),
      );

      final audio = await ds.synthesizeSpeech(text: 'Hello there!', language: 'english');

      expect(audio, 'ZmFrZS13YXY=');
    });

    test('returns null (not an error) when the server has no audio to offer', () async {
      final ds = _dataSource(
        statusCode: 200,
        body: jsonEncode({'success': false, 'audio': null, 'language': 'english', 'available': false}),
      );

      final audio = await ds.synthesizeSpeech(text: 'Hello there!', language: 'english');

      expect(audio, isNull);
    });

    test('returns null when the body is not a JSON object', () async {
      final ds = _dataSource(statusCode: 200, body: '"just a string"');

      final audio = await ds.synthesizeSpeech(text: 'Hello there!', language: 'english');

      expect(audio, isNull);
    });

    test('returns null on a 4xx/5xx response rather than throwing', () async {
      final ds = _dataSource(statusCode: 400, body: jsonEncode({'error': 'text is required'}));

      final audio = await ds.synthesizeSpeech(text: '', language: 'english');

      expect(audio, isNull);
    });

    test('returns null on a network exception rather than throwing', () async {
      final ds = AriaRemoteDataSource(
        ApiClient.forTesting(
          Dio(BaseOptions(baseUrl: 'http://test'))
            ..httpClientAdapter = _ThrowingHttpClientAdapter()
            ..interceptors.add(ApiExceptionsInterceptor()),
        ),
      );

      final audio = await ds.synthesizeSpeech(text: 'Hello there!', language: 'english');

      expect(audio, isNull);
    });

    test('sends the exact request shape as JSON — text/language, "speaker" omitted so the server default applies', () async {
      final adapter = _CapturingHttpClientAdapter(
        statusCode: 200,
        body: jsonEncode({'success': true, 'audio': 'ZmFrZQ==', 'available': true}),
      );
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);

      await ds.synthesizeSpeech(text: 'Hello there!', language: 'hindi');

      expect(adapter.lastRequest!.contentType, contains('application/json'));
      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sent, {'text': 'Hello there!', 'language': 'hindi'});
    });
  });
}
