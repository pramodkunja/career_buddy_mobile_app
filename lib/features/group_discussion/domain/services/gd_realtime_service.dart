import '../entities/gd_ws_event.dart';

/// The connection lifecycle a [GdRealtimeService] reports on
/// [GdRealtimeService.connectionStatus] — this client's own state, not a
/// server-sent value (the server has no equivalent concept; it just accepts
/// or drops the socket).
enum GdConnectionStatus {
  /// Never connected yet, or a previous connection was cleanly closed via
  /// [GdRealtimeService.disconnect].
  idle,
  connecting,
  connected,

  /// The socket closed or errored without [GdRealtimeService.disconnect]
  /// having been called — a real drop (network loss, server restart, the
  /// consumer closing with code 4403 because ownership no longer checks
  /// out, etc.), not a normal end-of-session. Callers should surface a
  /// "connection lost" state and offer to retry [GdRealtimeService.connect]
  /// rather than silently hanging.
  lost,
}

/// The seam between the presentation layer and the actual WebSocket
/// transport — same "one small interface per external dependency" pattern
/// as `AudioRecorderService`. [GdWebSocketService] is the one real
/// implementation (`package:web_socket_channel`); a hand-written fake
/// implementing this interface is what `GdSessionController`'s own tests use,
/// so those tests never touch a real socket.
abstract interface class GdRealtimeService {
  /// Every parsed server frame, in arrival order. A broadcast stream — safe
  /// to listen to only once per connection lifetime in practice, but nothing
  /// stops a second listener.
  Stream<GdWsEvent> get events;

  /// This client's own connection-state observations — see
  /// [GdConnectionStatus].
  Stream<GdConnectionStatus> get connectionStatus;

  /// Opens the socket at [uri], sending [cookieHeader] as the raw `Cookie`
  /// header on the initial HTTP upgrade request (see
  /// `ApiClient.buildCookieHeader`/`ApiEndpoints.gdWebSocketPath`'s doc
  /// comments for why that's what actually authenticates this connection).
  /// Completes once the connection is either open or has failed — a
  /// failure is also reported on [connectionStatus] as [GdConnectionStatus.lost],
  /// never left to hang silently.
  Future<void> connect({required Uri uri, required String cookieHeader});

  /// `{"action": "start", "language": ...}`.
  void sendStart({String language = 'english'});

  /// `{"action": "user_speaking"}`.
  void sendUserSpeaking();

  /// `{"action": "user_message", "content": ..., "language": ...}`.
  void sendUserMessage(String content, {String language = 'english'});

  /// `{"action": "end"}`.
  void sendEnd();

  /// Closes the socket deliberately — after this, [connectionStatus] emits
  /// [GdConnectionStatus.idle], not [GdConnectionStatus.lost] (this wasn't a
  /// drop).
  Future<void> disconnect();
}
