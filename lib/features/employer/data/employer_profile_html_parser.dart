import '../domain/entities/employer_profile_form.dart';

/// Parses `templates/employer/profile_form.html` — the single template
/// shared by `employer_profile_create` and `employer_profile_edit`
/// (`jobs_app/views.py`). Every field is a plain Django-rendered
/// input/select/textarea; this scrapes each one's current value by its
/// stable `id_<field_name>` id, exactly as verified against the real
/// rendered page.
EmployerProfileFormData parseEmployerProfileFormHtml(String html) {
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
  );
}

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
