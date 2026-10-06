/// What `GD_app:create_session` actually hands back — not a JSON body (the
/// view is a plain `redirect()`, never JSON), but the new `GDSession.id`
/// parsed out of its `Location` response header (`/gd/room/<id>/`) — see
/// `GdRemoteDataSource.createSession`. [topic] is simply echoed back from
/// what this client itself sent; the server doesn't return it anywhere
/// parseable from that redirect.
class GdStartedSession {
  const GdStartedSession({required this.sessionId, required this.topic});

  final int sessionId;
  final String topic;
}
