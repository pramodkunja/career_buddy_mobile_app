import 'package:career_buddy_lms/core/validators/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.required', () {
    test('returns an error for null', () {
      expect(Validators.required(null, fieldName: 'Password'), 'Password is required.');
    });

    test('returns an error for empty/whitespace-only input', () {
      expect(Validators.required('', fieldName: 'Password'), isNotNull);
      expect(Validators.required('   ', fieldName: 'Password'), isNotNull);
    });

    test('returns null for non-empty input', () {
      expect(Validators.required('hello'), isNull);
    });
  });

  group('Validators.email', () {
    test('rejects missing @ or domain', () {
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
    });

    test('accepts a plausible address', () {
      expect(Validators.email('hr@company.com'), isNull);
    });
  });

  group('Validators.gst', () {
    test('is optional — empty is valid', () {
      expect(Validators.gst(''), isNull);
      expect(Validators.gst(null), isNull);
    });

    test('accepts the exact format from EmployerRegisterForm\'s own placeholder', () {
      expect(Validators.gst('27ABCDE1234F1Z5'), isNull);
    });

    test('rejects a malformed GSTIN', () {
      expect(Validators.gst('not-a-gst-number'), isNotNull);
      expect(Validators.gst('27ABCDE1234F1Z'), isNotNull); // 14 chars, not 15
    });
  });

  group('Validators.pan', () {
    test('is optional — empty is valid', () {
      expect(Validators.pan(''), isNull);
    });

    test('accepts the exact format from EmployerRegisterForm\'s own placeholder', () {
      expect(Validators.pan('ABCDE1234F'), isNull);
    });

    test('rejects a malformed PAN', () {
      expect(Validators.pan('1234567890'), isNotNull);
    });
  });

  group('Validators.aadhar', () {
    test('is required — null/empty is invalid', () {
      expect(Validators.aadhar(null), isNotNull);
      expect(Validators.aadhar(''), isNotNull);
    });

    test('accepts exactly 12 digits', () {
      expect(Validators.aadhar('123456789012'), isNull);
    });

    test('rejects anything not exactly 12 digits', () {
      expect(Validators.aadhar('12345'), isNotNull);
      expect(Validators.aadhar('12345678901234'), isNotNull);
      expect(Validators.aadhar('12345678901A'), isNotNull);
    });
  });

  group('Validators.passport', () {
    test('is optional — empty is valid', () {
      expect(Validators.passport(''), isNull);
      expect(Validators.passport(null), isNull);
    });

    test('accepts the exact format from RegisterForm\'s own placeholder', () {
      expect(Validators.passport('A1234567'), isNull);
      expect(Validators.passport('a1234567'), isNull); // lowercase normalized
    });

    test('rejects a malformed passport number', () {
      expect(Validators.passport('1234567A'), isNotNull);
      expect(Validators.passport('A123456'), isNotNull); // 7 chars, not 8
    });
  });

  group('Validators.employerPassword', () {
    test('rejects anything not exactly 8 characters', () {
      expect(Validators.employerPassword('Ab1!'), isNotNull);
      expect(Validators.employerPassword('Ab1!Ab1!Ab1!'), isNotNull);
    });

    test('rejects a valid-length password missing one required character class', () {
      expect(Validators.employerPassword('abcdefg1'), isNotNull); // no uppercase, no special
    });

    test('accepts a password satisfying every rule at exactly 8 characters', () {
      expect(Validators.employerPassword('Abcdef1!'), isNull);
    });
  });

  group('Validators.confirmPassword', () {
    test('rejects a mismatch', () {
      expect(Validators.confirmPassword('Abcdef1!', original: 'Different1!'), isNotNull);
    });

    test('accepts an exact match', () {
      expect(Validators.confirmPassword('Abcdef1!', original: 'Abcdef1!'), isNull);
    });
  });
}
