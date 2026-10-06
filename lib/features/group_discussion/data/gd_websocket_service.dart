import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/entities/gd_ws_event.dart';
import '../domain/services/gd_realtime_service.dart';

/// Opens a real WebSocket connection — the seam [GdWebSocketService]'s own
/// tests override to hand back a channel built over a plain
/// `StreamController` pair instead of a real socket. Defaults to
/// `IOWebSocketChannel.connect`, which is what actually sends [headers] (the
/// `Cookie` header — see `GdRealtimeService.connect`'s doc comment) on the
/// WebSocket's initial HTTP upgrade request; `WebSocketChannel.connect`
/// (the platform-generic factory) has no `headers` parameter at all, which
/// is why this deliberately depends on the `dart:io`-specific one rather
/// than the generic one.
typedef GdChannelOpener = WebSocketChannel Function(Uri uri, {Map<String, dynamic>? headers});

WebSocketChannel _defaultOpener(Uri uri, {Map<String, dynamic>? headers}) {
  return IOWebSocketChannel.connect(uri, headers: headers);
}

/// The real [GdRealtimeService] — a thin protocol layer over
/// `package:web_socket_channel`: JSON-encodes the 3 outgoing actions,
/// JSON-decodes + parses every incoming frame via `parseGdWsEvent`, and
/// turns a socket that closes/errors without [disconnect] having been
/// called into a [GdConnectionStatus.lost] event on [connectionStatus]
/// rather than letting the stream just go quiet.
class GdWebSocketService implements GdRealtimeService {
  GdWebSocketService({GdChannelOpener? channelOpener}) : _openChannel = channelOpener ?? _defaultOpener;

  final GdChannelOpener _openChannel;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _disconnectRequested = false;

  final _eventsController = StreamController<GdWsEvent>.broadcast();
  final _statusController = StreamController<GdConnectionStatus>.broadcast();

  @override
  Stream<GdWsEvent> get events => _eventsController.stream;

  @override
  Stream<GdConnectionStatus> get connectionStatus => _statusController.stream;

  @override
  Future<void> connect({required Uri uri, required String cookieHeader}) async {
    _disconnectRequested = false;
    _statusController.add(GdConnectionStatus.connecting);

    final channel = _openChannel(uri, headers: {'Cookie': cookieHeader});
    _channel = channel;
    _subscription = channel.stream.listen(
      _handleRawFrame,
      onError: (Object _, StackTrace _) => _handleClosed(),
      onDone: _handleClosed,
      cancelOnError: true,
    );

    try {
      await channel.ready;
      if (!_disconnectRequested) _statusController.add(GdConnectionStatus.connected);
    } catch (_) {
      _handleClosed();
    }
  }

  void _handleClosed() {
    if (_disconnectRequested) {
      _statusController.add(GdConnectionStatus.idle);
    } else {
      _statusController.add(GdConnectionStatus.lost);
    }
  }

  void _handleRawFrame(dynamic raw) {
    if (raw is! String) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final event = parseGdWsEvent(decoded);
      if (event != null) _eventsController.add(event);
    } catch (_) {
      // A single malformed frame must not take down the live connection.
    }
  }

  @override
  void sendStart({String language = 'english'}) => _send({'action': 'start', 'language': language});

  @override
  void sendUserSpeaking() => _send({'action': 'user_speaking'});

  @override
  void sendUserMessage(String content, {String language = 'english'}) =>
      _send({'action': 'user_message', 'content': content, 'language': language});

  @override
  void sendEnd() => _send({'action': 'end'});

  void _send(Map<String, dynamic> data) {
    _channel?.sink.add(jsonEncode(data));
  }

  @override
  Future<void> disconnect() async {
    _disconnectRequested = true;
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _statusController.add(GdConnectionStatus.idle);
  }

  /// Releases this service's own streams — call once, when the owning
  /// controller/screen is disposed for good (not between reconnects).
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _eventsController.close();
    _statusController.close();
  }
}
