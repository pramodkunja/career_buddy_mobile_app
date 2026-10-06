import 'package:career_buddy_lms/features/ai_listening/data/models/listening_page_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractEmbeddedJsonConfig', () {
    test('extracts and decodes the JSON blob from a matching <script> tag', () {
      const html = '''
<html><body>
<script type="application/json" id="listening-config">
{
  "analyzeEndpoint": "/activities/exercise/7/analyze/listening/",
  "lessonsPath": "/activities/exercise/7/",
  "attemptToken": "abc123def456"
}
</script>
</body></html>
''';

      final config = extractEmbeddedJsonConfig(html, 'listening-config');

      expect(config, isNotNull);
      expect(config!['attemptToken'], 'abc123def456');
      expect(config['analyzeEndpoint'], '/activities/exercise/7/analyze/listening/');
    });

    test('returns null when the element id is not present (e.g. redirected to a different page)', () {
      const html = '<html><body><h1>Activities</h1></body></html>';
      expect(extractEmbeddedJsonConfig(html, 'listening-config'), isNull);
    });

    test('returns null when the script tag id matches but the content is not valid JSON', () {
      const html = '<script type="application/json" id="listening-config">not json</script>';
      expect(extractEmbeddedJsonConfig(html, 'listening-config'), isNull);
    });

    test('returns null when the content decodes to a non-object JSON value', () {
      const html = '<script type="application/json" id="listening-config">[1,2,3]</script>';
      expect(extractEmbeddedJsonConfig(html, 'listening-config'), isNull);
    });

    test('only matches the requested element id, not a different config block on the same page', () {
      const html = '''
<script type="application/json" id="writing-config">{"attemptToken": "wrong-one"}</script>
<script type="application/json" id="listening-config">{"attemptToken": "right-one"}</script>
''';
      final config = extractEmbeddedJsonConfig(html, 'listening-config');
      expect(config!['attemptToken'], 'right-one');
    });
  });
}
