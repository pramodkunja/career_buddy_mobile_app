/// `jobs_app.forms.EmployerProfileForm` / `jobs_app/models.py:EmployerProfile`
/// — shared by both `employer_profile_create` and `employer_profile_edit`
/// (same template, same form class; only the target URL and a couple of
/// redirect rules differ — see `EmployerProfileRemoteDataSource`'s doc
/// comment).
class EmployerProfileFormData {
  const EmployerProfileFormData({
    required this.companyName,
    required this.companyWebsite,
    required this.industry,
    required this.companySize,
    required this.location,
    required this.description,
    required this.companyAddress,
    required this.companyGst,
    required this.maskedPan,
    required this.hrContactE164,
    required this.hrMail,
  });

  final String companyName;
  final String companyWebsite;
  final String industry;
  final String companySize;
  final String location;
  final String description;
  final String companyAddress;
  final String companyGst;

  /// `templates/includes/mask_reveal_field.html` — e.g. `"XXXXXX285A"` when
  /// a PAN is already on file (leaving the edit field blank keeps it
  /// unchanged on submit), or empty when none is saved yet (the field is
  /// then required, same as [EmployerProfileFormData] creation).
  final String maskedPan;
  final String hrContactE164;
  final String hrMail;
}

/// POST payload for both `employer_profile_create` and
/// `employer_profile_edit`. [companyPanTin] left blank means "keep the
/// existing value" when one is already on file (`clean_company_pan_tin`,
/// `jobs_app/forms.py`) — the same mask-and-reveal convention already used
/// by the student profile's Aadhar/PAN/Passport fields.
class EmployerProfileSubmission {
  const EmployerProfileSubmission({
    required this.companyName,
    required this.companyWebsite,
    required this.industry,
    required this.companySize,
    required this.location,
    required this.description,
    required this.companyAddress,
    required this.companyGst,
    required this.companyPanTin,
    required this.hrContactE164,
    required this.hrMail,
    this.companyLogoPath,
  });

  final String companyName;
  final String companyWebsite;
  final String industry;
  final String companySize;
  final String location;
  final String description;
  final String companyAddress;
  final String companyGst;
  final String companyPanTin;
  final String hrContactE164;
  final String hrMail;
  final String? companyLogoPath;
}

/// `EmployerProfile.company_size` choices (`jobs_app/models.py`) — verified
/// live against the rendered `<select id="id_company_size">` options.
const List<(String value, String label)> kCompanySizeOptions = [
  ('1-10', '1-10'),
  ('11-50', '11-50'),
  ('51-200', '51-200'),
  ('201-500', '201-500'),
  ('500+', '500+'),
];
