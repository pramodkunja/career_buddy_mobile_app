import '../../../core/network/api_endpoints.dart';

/// Batch 11 — derives the real Group Discussion WebSocket URI from
/// [baseUrl] (`EnvironmentConfig.baseUrl`), the same single source of truth
/// every other network destination in this app already uses. Extracted out
/// of `GdSessionController._connect` into its own pure, directly-testable
/// function specifically so the `http → ws` / `https → wss` scheme
/// derivation — required for a real HTTPS backend, since browsers/Django
/// Channels reject a plaintext `ws://` handshake against an `https://` site
/// — can be verified in isolation, not only indirectly through the whole
/// session-creation flow.
Uri buildGdWebSocketUri(String baseUrl, int sessionId) {
  final base = Uri.parse(baseUrl);
  return base.replace(
    scheme: base.scheme == 'https' ? 'wss' : 'ws',
    path: ApiEndpoints.gdWebSocketPath(sessionId),
  );
}
