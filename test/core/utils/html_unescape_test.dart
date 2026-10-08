import 'package:career_buddy_lms/core/utils/html_unescape.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('unescapeHtmlEntities', () {
    test('decodes the hex apostrophe entity Python\'s html.escape() actually emits', () {
      expect(unescapeHtmlEntities("it&#x27;s"), "it's");
    });

    test('still decodes the decimal apostrophe entity form for robustness', () {
      expect(unescapeHtmlEntities('it&#39;s'), "it's");
    });

    test('leaves a normal apostrophe untouched', () {
      expect(unescapeHtmlEntities("it's already fine"), "it's already fine");
    });

    test('decodes amp/lt/gt/quot alongside apostrophes in one pass', () {
      expect(
        unescapeHtmlEntities('Use &#x27;Led&#x27; &amp; &#x27;Built&#x27; &lt;tag&gt; &quot;quoted&quot;'),
        "Use 'Led' & 'Built' <tag> \"quoted\"",
      );
    });

    test('leaves existing markup-looking text untouched (no tag mangling)', () {
      // These parsers already stop their own captures at the first `<`, so
      // real markup never reaches this function whole — but it must not
      // itself corrupt an HTML-looking string it's handed regardless.
      expect(unescapeHtmlEntities('<b>already plain</b>'), '<b>already plain</b>');
    });

    test('is a no-op on plain text with no entities at all', () {
      expect(unescapeHtmlEntities('Nothing to decode here.'), 'Nothing to decode here.');
    });
  });
}
