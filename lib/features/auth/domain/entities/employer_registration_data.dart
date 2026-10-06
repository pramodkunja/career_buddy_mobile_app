/// Every field `EmployerRegisterForm` (`accounts_app/forms.py`) accepts,
/// carried as one plain value object from the registration screen down to
/// the datasource. Deliberately mirrors the Python form's fields 1:1 —
/// nothing added, nothing dropped (`company_gst`/`company_pan_tin`/
/// `company_address`/`companyLogoPath` are optional there and stay optional
/// here).
class EmployerRegistrationData {
  const EmployerRegistrationData({
    required this.username,
    required this.password,
    required this.passwordConfirm,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.companyName,
    required this.industry,
    required this.hrContactE164,
    required this.hrMail,
    this.companyLogoPath,
    this.companyGst = '',
    this.companyPanTin = '',
    this.companyAddress = '',
  });

  final String username;
  final String password;
  final String passwordConfirm;
  final String email;
  final String firstName;
  final String lastName;
  final String companyName;

  /// One of `EmployerRegisterForm.industry`'s real option values (e.g.
  /// `'it_software'`) — see `EmployerIndustryOptions`.
  final String industry;

  /// E.164 (`"+<dial code><digits>"`), already combined the same way
  /// `phone-input.js`'s `syncHidden()` does.
  final String hrContactE164;
  final String hrMail;

  /// Local file path from the image picker, or `null` if the user didn't
  /// attach one (`company_logo` is optional).
  final String? companyLogoPath;
  final String companyGst;
  final String companyPanTin;
  final String companyAddress;
}

/// `EmployerRegisterForm.industry`'s exact choice list
/// (`accounts_app/forms.py:58-71`) — value/label pairs, verbatim.
class EmployerIndustryOption {
  const EmployerIndustryOption(this.value, this.label);
  final String value;
  final String label;
}

const List<EmployerIndustryOption> kEmployerIndustryOptions = [
  EmployerIndustryOption('it_software', 'IT / Software'),
  EmployerIndustryOption('manufacturing', 'Manufacturing'),
  EmployerIndustryOption('healthcare', 'Healthcare'),
  EmployerIndustryOption('finance', 'Finance / Banking'),
  EmployerIndustryOption('education', 'Education'),
  EmployerIndustryOption('consulting', 'Consulting'),
  EmployerIndustryOption('retail', 'Retail / FMCG'),
  EmployerIndustryOption('other', 'Other'),
];
