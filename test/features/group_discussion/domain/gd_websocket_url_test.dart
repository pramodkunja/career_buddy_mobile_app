import 'package:career_buddy_lms/app/config/environment.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/gd_websocket_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildGdWebSocketUri', () {
    // Batch 12 — `EnvironmentConfig.production`'s real, positively-verified
    // host must never downgrade to `ws://` for the real deployment. Only
    // runs its production-specific assertion under
    // `--dart-define=ENV=production` (see `environment_test.dart`'s own
    // doc comment for why this file is run three separate ways); under the
    // default `dev` run this just proves the getter doesn't throw.
    test('derives wss:// from the real, positively-verified EnvironmentConfig.production host', () {
      const envName = String.fromEnvironment('ENV', defaultValue: 'dev');
      if (envName != 'production') return;

      final uri = buildGdWebSocketUri(EnvironmentConfig.baseUrl, 123);

      expect(uri.scheme, 'wss');
      expect(uri.host, 'careerbuddy4u.com');
      expect(uri.path, '/ws/GD_app/123/');
    });

    test('derives ws:// from an http:// base URL (today\'s dev configuration)', () {
      final uri = buildGdWebSocketUri('http://10.0.2.2:8000', 42);

      expect(uri.scheme, 'ws');
      expect(uri.host, '10.0.2.2');
      expect(uri.port, 8000);
      expect(uri.path, '/ws/GD_app/42/');
    });

    test('derives wss:// from an https:// base URL (a real production backend)', () {
      final uri = buildGdWebSocketUri('https://api.careerbuddy.example', 7);

      expect(uri.scheme, 'wss');
      expect(uri.host, 'api.careerbuddy.example');
      expect(uri.path, '/ws/GD_app/7/');
    });

    test('never hardcodes ws:// when the base URL is already https://', () {
      final uri = buildGdWebSocketUri('https://secure.example.com:443', 1);
      expect(uri.scheme, isNot('ws'));
      expect(uri.scheme, 'wss');
    });

    test('preserves the real session id in the path for any session number', () {
      expect(buildGdWebSocketUri('http://127.0.0.1:8000', 999).path, '/ws/GD_app/999/');
      expect(buildGdWebSocketUri('http://127.0.0.1:8000', 1).path, '/ws/GD_app/1/');
    });
  });
}
