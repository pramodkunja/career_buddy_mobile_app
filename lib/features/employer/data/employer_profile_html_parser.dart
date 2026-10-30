import '../domain/entities/employer_profile_form.dart';

/// Parses `templates/employer/profile_form.html` — the single template
/// shared by `employer_profile_create` and `employer_profile_edit`
/// (`jobs_app/views.py`). Every form field is a plain Django-rendered
/// input/select/textarea; this scrapes each one's current value by its
/// stable `id_<field_name>` id, exactly as verified against the real
/// rendered page. Phase 74 — this template `{% extends 'employer_base.html'
/// %}`, so the one response already fetched for this form also carries that
/// layout's own sidebar identity block; [EmployerProfileFormData
/// .companyLogoUrl] scrapes that block too, reusing this same fetch rather
/// than adding a second request anywhere a caller needs the logo.
EmployerProfileFormData parseEmployerProfileFormHtml(String html) {
  if (!isEmployerProfileFormHtml(html)) {
    throw const FormatException('Not the employer profile form page');
  }
  return EmployerProfileFormData(
    companyName: _attrValue(html, 'company_name'),
    companyWebsite: _attrValue(html, 'company_website'),
    industry: _attrValue(html, 'industry'),
    companySize: _selectedOption(html, 'company_size'),
    location: _attrValue(html, 'location'),
    description: _textareaContent(html, 'description'),
    companyAddress: _textareaContent(html, 'company_address'),
    companyGst: _attrValue(html, 'company_gst'),
    maskedPan: _maskedPanPattern.firstMatch(html)?.group(1) ?? '',
    hrContactE164: _attrValue(html, 'hr_contact'),
    hrMail: _attrValue(html, 'hr_mail'),
    companyLogoUrl: _companyLogoUrl(html),
  );
}

/// `templates/employer_base.html:200-205` — the sidebar identity block's own
/// `<img ... alt="Company Logo">`, present only when the real employer has a
/// logo on file; absent (the template's own `{% else %}` icon) otherwise.
/// `alt="Company Logo"` is a stable, literal anchor the same way every other
/// field in this file anchors on its own stable `id="id_<field>"`.
String? _companyLogoUrl(String html) {
  final tag = RegExp(r'<img[^>]*alt="Company Logo"[^>]*>').firstMatch(html)?.group(0);
  if (tag == null) return null;
  return RegExp(r'src="([^"]*)"').firstMatch(tag)?.group(1);
}

/// `templates/employer/profile_form.html:103` — present only on the real,
/// rendered Company Profile form (both the create and edit variants share
/// this one template), confirmed absent from
/// `templates/employer_login/{login,signup}.html` and `base.html` — so
/// this is this file's success/failure signal, same role as
/// `isDashboardHtml`/`isProfileHtml` elsewhere in this app.
bool isEmployerProfileFormHtml(String html) => html.contains('id="toggleEditBtn"');

final _maskedPanPattern = RegExp(r'mask-reveal-masked[^>]*>([^<]*)<');

String _tag(String html, String fieldName) {
  final m = RegExp('<[a-z]+[^>]*id="id_$fieldName"[^>]*>').firstMatch(html);
  return m?.group(0) ?? '';
}

String _attrValue(String html, String fieldName) {
  final tag = _tag(html, fieldName);
  return RegExp(r'value="([^"]*)"').firstMatch(tag)?.group(1) ?? '';
}

String _selectedOption(String html, String fieldName) {
  final selectMatch = RegExp(
    '<select[^>]*id="id_$fieldName"[^>]*>([\\s\\S]*?)</select>',
  ).firstMatch(html);
  if (selectMatch == null) return '';
  final body = selectMatch.group(1)!;
  final selected = RegExp(r'<option value="([^"]*)"[^>]*\sselected').firstMatch(body);
  return selected?.group(1) ?? '';
}

String _textareaContent(String html, String fieldName) {
  final m = RegExp(
    '<textarea[^>]*id="id_$fieldName"[^>]*>([\\s\\S]*?)</textarea>',
  ).firstMatch(html);
  return m?.group(1)?.trim() ?? '';
}
