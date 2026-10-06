import 'package:career_buddy_lms/features/employer/data/employer_profile_html_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixture markup reproduces the real, exact `id_<field>` structure of
/// `templates/employer/profile_form.html` as rendered server-side (verified
/// live against a real, complete employer profile) — not a guessed shape.
const _fixtureHtmlComplete = '''
<input type="text" name="company_name" value="Acme Talent Solutions" class="form-control" placeholder="Company Name" autofocus="autofocus" maxlength="200" required id="id_company_name">
<input type="url" name="company_website" value="https://acme.example.com" class="form-control" placeholder="https://example.com" maxlength="200" id="id_company_website">
<input type="file" name="company_logo" class="form-control" accept="image/*" id="id_company_logo">
<input type="text" name="industry" value="Information Technology" class="form-control" placeholder="e.g. Information Technology" maxlength="100" required id="id_industry">
<select name="company_size" class="form-select" id="id_company_size">
  <option value="">---------</option>
  <option value="1-10">1-10</option>
  <option value="11-50" selected>11-50</option>
  <option value="51-200">51-200</option>
</select>
<input type="text" name="location" value="Bengaluru, Karnataka" class="form-control" placeholder="City, State" maxlength="200" id="id_location">
<textarea name="description" cols="40" rows="4" class="form-control" id="id_description">We build hiring tools.</textarea>
<textarea name="company_address" cols="40" rows="2" class="form-control" placeholder="Company Headquarters Address" id="id_company_address">221B Residency Road, Bengaluru</textarea>
<input type="text" name="company_gst" value="27ABCDE1234F1Z5" class="form-control" placeholder="e.g. 27ABCDE1234F1Z5" maxlength="15" style="text-transform:uppercase" minlength="15" required id="id_company_gst">
<div class="mask-reveal-field">
    <div class="mask-reveal-display d-flex align-items-center gap-2">
        <span class="form-control mask-reveal-masked" style="background:#f8fafc;color:#475569;letter-spacing:.03em;">XXXXXX285A</span>
        <button type="button" class="btn btn-sm btn-outline-secondary mask-reveal-toggle flex-shrink-0"><i class="fas fa-pen me-1"></i>Change</button>
    </div>
    <div class="mask-reveal-input d-none">
        <input type="text" name="company_pan_tin" class="form-control" placeholder="e.g. ABCDE1234F" maxlength="10" minlength="10" style="text-transform:uppercase" id="id_company_pan_tin">
    </div>
</div>
<input type="hidden" name="hr_contact" value="+919876543210" id="id_hr_contact">
<input type="email" name="hr_mail" value="hr@acme.example.com" class="form-control" placeholder="HR Email Address" maxlength="254" id="id_hr_mail">
''';

const _fixtureHtmlFreshProfile = '''
<input type="text" name="company_name" value="New Co" class="form-control" placeholder="Company Name" autofocus="autofocus" maxlength="200" required id="id_company_name">
<input type="url" name="company_website" class="form-control" placeholder="https://example.com" maxlength="200" id="id_company_website">
<input type="file" name="company_logo" class="form-control" accept="image/*" id="id_company_logo">
<input type="text" name="industry" value="Retail" class="form-control" placeholder="e.g. Information Technology" maxlength="100" required id="id_industry">
<select name="company_size" class="form-select" id="id_company_size">
  <option value="" selected>---------</option>
  <option value="1-10">1-10</option>
</select>
<input type="text" name="location" value="Pune, Maharashtra" class="form-control" placeholder="City, State" maxlength="200" id="id_location">
<textarea name="description" cols="40" rows="4" class="form-control" id="id_description"></textarea>
<textarea name="company_address" cols="40" rows="2" class="form-control" placeholder="Company Headquarters Address" id="id_company_address"></textarea>
<input type="text" name="company_gst" class="form-control" placeholder="e.g. 27ABCDE1234F1Z5" maxlength="15" style="text-transform:uppercase" minlength="15" required id="id_company_gst">
<div class="mask-reveal-field">
    <input type="text" name="company_pan_tin" class="form-control" placeholder="e.g. ABCDE1234F" maxlength="10" minlength="10" style="text-transform:uppercase" id="id_company_pan_tin">
</div>
<input type="hidden" name="hr_contact" value="9876500000" id="id_hr_contact">
<input type="email" name="hr_mail" class="form-control" placeholder="HR Email Address" maxlength="254" id="id_hr_mail">
''';

void main() {
  group('parseEmployerProfileFormHtml', () {
    test('parses every field for a complete profile, including the masked PAN', () {
      final data = parseEmployerProfileFormHtml(_fixtureHtmlComplete);

      expect(data.companyName, 'Acme Talent Solutions');
      expect(data.companyWebsite, 'https://acme.example.com');
      expect(data.industry, 'Information Technology');
      expect(data.companySize, '11-50');
      expect(data.location, 'Bengaluru, Karnataka');
      expect(data.description, 'We build hiring tools.');
      expect(data.companyAddress, '221B Residency Road, Bengaluru');
      expect(data.companyGst, '27ABCDE1234F1Z5');
      expect(data.maskedPan, 'XXXXXX285A');
      expect(data.hrContactE164, '+919876543210');
      expect(data.hrMail, 'hr@acme.example.com');
    });

    test('parses a fresh/incomplete profile with no GST/PAN/size/logo on file', () {
      final data = parseEmployerProfileFormHtml(_fixtureHtmlFreshProfile);

      expect(data.companyName, 'New Co');
      expect(data.companyWebsite, isEmpty);
      expect(data.companySize, isEmpty);
      expect(data.companyGst, isEmpty);
      expect(data.maskedPan, isEmpty);
      // Confirmed live against a real production profile: some accounts
      // have a bare local number with no leading "+<dial code>" — the
      // parser returns it as-is; `EmployerPhoneInputField` is what treats
      // a non-"+" value as a local number under the default country.
      expect(data.hrContactE164, '9876500000');
    });
  });
}
