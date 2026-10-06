/// Form-field validators shared across screens. The backend's `LoginForm`
/// (`users/forms.py`) only enforces "required" client-side-visibly — actual
/// credential correctness is checked server-side — so validators here stay
/// equally minimal rather than inventing stricter rules the backend doesn't
/// have. The GST/PAN/password rules below are the one exception: the
/// backend itself enforces these exact regexes/lengths server-side
/// (`accounts_app/forms.py`'s `GST_REGEX`/`PAN_REGEX`,
/// `users/password_validators.py`'s min/max-length pair), so reproducing
/// them here isn't inventing stricter rules — it's catching the same
/// rejection earlier instead of waiting on a round trip.
abstract final class Validators {
  static final _gstRegex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[A-Z0-9]{1}Z[A-Z0-9]{1}$');
  static final _panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _aadharRegex = RegExp(r'^[0-9]{12}$');
  static final _passportRegex = RegExp(r'^[A-Z][0-9]{7}$');

  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  static String? email(String? value, {String fieldName = 'Email'}) {
    final requiredError = required(value, fieldName: fieldName);
    if (requiredError != null) return requiredError;
    if (!_emailRegex.hasMatch(value!.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  /// `EmployerRegisterForm.clean_company_gst` (`accounts_app/forms.py:
  /// 116-123`) — optional field, only validated when non-empty.
  static String? gst(String? value) {
    final gst = (value ?? '').trim().toUpperCase();
    if (gst.isEmpty) return null;
    if (gst.length != 15 || !_gstRegex.hasMatch(gst)) {
      return 'Invalid GSTIN format. Must be 99AAAAA9999A1Z9.';
    }
    return null;
  }

  /// `EmployerRegisterForm.clean_company_pan_tin` (`accounts_app/forms.py:
  /// 125-135`) — optional field, only validated when non-empty.
  static String? pan(String? value) {
    final pan = (value ?? '').trim().toUpperCase();
    if (pan.isEmpty) return null;
    if (pan.length != 10 || !_panRegex.hasMatch(pan)) {
      return 'Invalid PAN format. Must be AAAAA9999A (5 letters, 4 digits, 1 letter).';
    }
    return null;
  }

  /// `password-requirements.js`'s checklist + Django's Min/MaximumLength
  /// validators, both server-authoritative — `password1`/`password2`'s own
  /// `maxlength="8"` widget attr (`accounts_app/forms.py:103-113`) caps
  /// entry at 8 client-side too, so "exactly 8" is enforceable here, not
  /// just advisory.
  static String? employerPassword(String? value) {
    final requiredError = required(value, fieldName: 'Password');
    if (requiredError != null) return requiredError;
    final password = value!;
    if (password.length != 8) return 'Password must be exactly 8 characters.';
    if (!RegExp(r'[A-Z]').hasMatch(password)) return 'Password needs at least 1 uppercase letter.';
    if (!RegExp(r'[a-z]').hasMatch(password)) return 'Password needs at least 1 lowercase letter.';
    if (!RegExp(r'[0-9]').hasMatch(password)) return 'Password needs at least 1 number.';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) return 'Password needs at least 1 special character.';
    return null;
  }

  static String? confirmPassword(String? value, {required String original}) {
    final requiredError = required(value, fieldName: 'Confirm password');
    if (requiredError != null) return requiredError;
    if (value != original) return 'Passwords do not match.';
    return null;
  }

  /// `RegisterForm.clean_aadhar_number` (`users/forms.py`) — required,
  /// exactly 12 digits.
  static String? aadhar(String? value) {
    final requiredError = required(value, fieldName: 'Aadhar number');
    if (requiredError != null) return requiredError;
    final aadhar = value!.trim();
    if (!_aadharRegex.hasMatch(aadhar)) {
      return 'Aadhar number must be exactly 12 digits.';
    }
    return null;
  }

  /// `RegisterForm.clean_passport_number` — optional; only validated when
  /// non-empty.
  static String? passport(String? value) {
    final passport = (value ?? '').trim().toUpperCase();
    if (passport.isEmpty) return null;
    if (passport.length != 8 || !_passportRegex.hasMatch(passport)) {
      return 'Passport number must be 1 uppercase letter followed by 7 digits.';
    }
    return null;
  }
}
