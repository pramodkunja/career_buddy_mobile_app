import 'package:career_buddy_lms/core/data/country_codes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizePhoneToE164', () {
    test('a bare local number (no leading +) gets the default country (India) dial code prepended', () {
      // The exact real-world shape confirmed live against a production
      // profile: `mobile` stored as plain digits, no `+91`.
      expect(normalizePhoneToE164('7993443081'), '+917993443081');
    });

    test('a number already in E.164 form is passed through unchanged', () {
      expect(normalizePhoneToE164('+917993443081'), '+917993443081');
    });

    test('a bare number with non-digit formatting characters is cleaned before prefixing', () {
      expect(normalizePhoneToE164('799-344-3081'), '+917993443081');
    });

    test('empty/null input stays empty', () {
      expect(normalizePhoneToE164(''), '');
      expect(normalizePhoneToE164(null), '');
      expect(normalizePhoneToE164('   '), '');
    });

    test('"Not Provided" (the Overview tab\'s own empty-field placeholder) has no digits, so it normalizes to empty rather than a bogus "+91"', () {
      expect(normalizePhoneToE164('Not Provided'), '');
    });
  });
}
