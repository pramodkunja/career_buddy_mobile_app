import 'dart:async';
import 'dart:convert';

import 'package:career_buddy_lms/features/group_discussion/data/gd_websocket_service.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/entities/gd_report.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/entities/gd_speaker.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/entities/gd_ws_event.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/services/gd_realtime_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A minimal fake [WebSocketSink] that just records what's sent — the
/// "plain `StreamController` pair" the WebSocket-service test guidance
/// calls for, on the sending side.
class _FakeSink implements WebSocketSink {
  final List<dynamic> sent = [];
  final _doneCompleter = Completer<void>();

  @override
  void add(dynamic data) => sent.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) async {}

  @override
  Future get done => _doneCompleter.future;

  @override
  Future close([int? closeCode, String? closeReason]) async {
    if (!_doneCompleter.isCompleted) _doneCompleter.complete();
  }
}

/// A fake [WebSocketChannel] wired directly over a plain
/// [StreamController] — no real socket involved. [incoming] lets the test
/// simulate frames "arriving from the server"; [readyCompleter] lets a test
/// simulate a connection that never/fails to establish. `with
/// StreamChannelMixin` supplies `WebSocketChannel`'s other inherited
/// `StreamChannel` members (`cast`/`pipe`/etc.) for free, exactly like the
/// real `IOWebSocketChannel` gets them.
class _FakeWebSocketChannel with StreamChannelMixin implements WebSocketChannel {
  _FakeWebSocketChannel({Completer<void>? readyCompleter})
    : incoming = StreamController<dynamic>(),
      _sink = _FakeSink(),
      _readyCompleter = readyCompleter ?? (Completer<void>()..complete());

  final StreamController<dynamic> incoming;
  final _FakeSink _sink;
  final Completer<void> _readyCompleter;

  _FakeSink get fakeSink => _sink;

  @override
  Stream get stream => incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  Future<void> get ready => _readyCompleter.future;

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;
}

void main() {
  group('GdWebSocketService', () {
    late _FakeWebSocketChannel channel;
    late Uri capturedUri;
    late Map<String, dynamic>? capturedHeaders;
    late GdWebSocketService service;

    void setUpService({Completer<void>? readyCompleter}) {
      channel = _FakeWebSocketChannel(readyCompleter: readyCompleter);
      service = GdWebSocketService(
        channelOpener: (uri, {headers}) {
          capturedUri = uri;
          capturedHeaders = headers;
          return channel;
        },
      );
    }

    test('connect() opens the channel with the session cookie in the Cookie header', () async {
      setUpService();
      final statuses = <GdConnectionStatus>[];
      service.connectionStatus.listen(statuses.add);

      await service.connect(uri: Uri.parse('ws://test/ws/GD_app/9/'), cookieHeader: 'sessionid=abc123');
      await Future<void>.delayed(Duration.zero);

      expect(capturedUri, Uri.parse('ws://test/ws/GD_app/9/'));
      expect(capturedHeaders, {'Cookie': 'sessionid=abc123'});
      expect(statuses, [GdConnectionStatus.connecting, GdConnectionStatus.connected]);
    });

    test('a failed handshake (ready throws) is reported as lost, never left hanging', () async {
      final readyCompleter = Completer<void>();
      setUpService(readyCompleter: readyCompleter);
      readyCompleter.completeError(Exception('handshake failed'));
      final statuses = <GdConnectionStatus>[];
      service.connectionStatus.listen(statuses.add);

      await service.connect(uri: Uri.parse('ws://test/ws/GD_app/9/'), cookieHeader: '');
      await Future<void>.delayed(Duration.zero);

      expect(statuses, [GdConnectionStatus.connecting, GdConnectionStatus.lost]);
    });

    test('the socket closing on its own (no disconnect() call) is reported as lost', () async {
      setUpService();
      await service.connect(uri: Uri.parse('ws://test/ws/GD_app/9/'), cookieHeader: '');
      final statuses = <GdConnectionStatus>[];
      service.connectionStatus.listen(statuses.add);

      await channel.incoming.close();
      await Future<void>.delayed(Duration.zero);

      expect(statuses, [GdConnectionStatus.lost]);
    });

    test('disconnect() reports idle, not lost', () async {
      setUpService();
      await service.connect(uri: Uri.parse('ws://test/ws/GD_app/9/'), cookieHeader: '');
      final statuses = <GdConnectionStatus>[];
      service.connectionStatus.listen(statuses.add);

      await service.disconnect();
      await Future<void>.delayed(Duration.zero);

      expect(statuses, [GdConnectionStatus.idle]);
    });

    test('parses a status event', () async {
      setUpService();
      await service.connect(uri: Uri.parse('ws://test/ws/GD_app/9/'), cookieHeader: '');
      final events = <GdWsEvent>[];
      service.events.listen(events.add);

      channel.incoming.add(jsonEncode({'type': 'status', 'status': 'started', 'topic': 'AI jobs'}));
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      final event = events.single as GdStatusEvent;
      expect(event.status, 'started');
      expect(event.topic, 'AI jobs');
    });

    test('parses a typing event', () async {
      setUpService();
      await service.connect(uri: Uri.parse('ws://test/ws/GD_app/9/'), cookieHeader: '');
      final events = <GdWsEvent>[];
      service.events.listen(events.add);

      channel.incoming.add(
        jsonEncode({'type': 'typing', 'speaker': 'alex', 'speaker_name': 'Alex', 'avatar': '🔵', 'color': '#4F8EF7'}),
      );
      await Future<void>.delayed(Duration.zero);

      final event = events.single as GdTypingEvent;
      expect(event.speaker, GdSpeaker.alex);
      expect(event.speakerName, 'Alex');
      expect(event.colorHex, '#4F8EF7');
    });

    test('parses a message event', () async {
      setUpService();
      await service.connect(uri: Uri.parse('ws://test/ws/GD_app/9/'), cookieHeader: '');
      final events = <GdWsEvent>[];
      service.events.listen(events.add);

      channel.incoming.add(
        jsonEncode({
          'type': 'message',
          'speaker': 'maya',
          'speaker_name': 'Maya',
          'avatar': '🟣',
          'color': '#C471ED',
          'content': 'Imagine if we flip this...',
          'is_user': false,
        }),
      );
      await Future<void>.delayed(Duration.zero);

      final event = events.single as GdMessageEvent;
      expect(event.message.speaker, GdSpeaker.maya);
      expect(event.message.content, 'Imagine if we flip this...');
      expect(event.message.isUser, isFalse);
    });

    test('parses a report event', () async {
      setUpService();
      await service.connect(uri: Uri.parse('ws://test/ws/GD_app/9/'), cookieHeader: '');
      final events = <GdWsEvent>[];
      service.events.listen(events.add);

      channel.incoming.add(
        jsonEncode({
          'type': 'report',
          'report': {
            'overall_score': 80,
            'fluency': {'score': 20, 'feedback': 'Good.'},
            'grammar': {'score': 20, 'feedback': 'Good.'},
            'relevance': {'score': 20, 'feedback': 'Good.'},
            'confidence': {'score': 20, 'feedback': 'Good.'},
            'strengths': ['Clarity'],
            'improvements': ['Pace'],
            'summary': 'Well done.',
          },
        }),
      );
      await Future<void>.delayed(Duration.zero);

      final event = events.single as GdReportEvent;
      expect(event.report, isA<GdReport>());
      expect(event.report.overallScore, 80);
      expect(event.report.summary, 'Well done.');
    });

    test('a malformed frame is ignored, not thrown, and does not break later frames', () async {
      setUpService();
      await service.connect(uri: Uri.parse('ws://test/ws/GD_app/9/'), cookieHeader: '');
      final events = <GdWsEvent>[];
      service.events.listen(events.add);

      channel.incoming.add('not json at all {{{');
      channel.incoming.add(jsonEncode({'type': 'status', 'status': 'ended'}));
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect((events.single as GdStatusEvent).status, 'ended');
    });

    test('sendStart sends the start action with language', () async {
      setUpService();
      await service.connect(uri: Uri.parse('ws://test/ws/GD_app/9/'), cookieHeader: '');

      service.sendStart(language: 'hindi');

      expect(channel.fakeSink.sent, [
        jsonEncode({'action': 'start', 'language': 'hindi'}),
      ]);
    });

    test('sendUserSpeaking sends the user_speaking action', () async {
      setUpService();
      await service.connect(uri: Uri.parse('ws://test/ws/GD_app/9/'), cookieHeader: '');

      service.sendUserSpeaking();

      expect(channel.fakeSink.sent, [
        jsonEncode({'action': 'user_speaking'}),
      ]);
    });

    test('sendUserMessage sends the user_message action with content and language', () async {
      setUpService();
      await service.connect(uri: Uri.parse('ws://test/ws/GD_app/9/'), cookieHeader: '');

      service.sendUserMessage('I think social media has both sides.', language: 'english');

      expect(channel.fakeSink.sent, [
        jsonEncode({'action': 'user_message', 'content': 'I think social media has both sides.', 'language': 'english'}),
      ]);
    });

    test('sendEnd sends the end action', () async {
      setUpService();
      await service.connect(uri: Uri.parse('ws://test/ws/GD_app/9/'), cookieHeader: '');

      service.sendEnd();

      expect(channel.fakeSink.sent, [
        jsonEncode({'action': 'end'}),
      ]);
    });
  });
}
