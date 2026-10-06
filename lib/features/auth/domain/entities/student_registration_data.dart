/// Every field `RegisterForm` (`users/forms.py`) accepts, mirrored 1:1.
///
/// Deliberately excluded, as a documented, disclosed scope decision rather
/// than an oversight:
/// - `selfie` — optional (`required=False`); the server only sets it "if
///   present", so omitting it entirely is a safe, valid submission.
/// - `additional_educations_json` — the web's own dynamic "add another
///   education" rows beyond the two fixed sets already covered by
///   [educationLevel]/[educationLevel2] below; the form's own
///   `validate_additional_education_years` defaults to `'[]'` when this key
///   is absent from the POST body, so omitting it is equally safe.
/// - `lang_name[]`/`lang_level[]` — the web's dynamic per-language
///   proficiency rows; `RegisterForm.save()` itself falls back to the plain
///   [languagesKnown] free-text field whenever no such pairs are submitted
///   (`users/forms.py` `save()`), so this app uses that fallback field
///   directly instead of reproducing the add/remove-row UI.
class StudentRegistrationData {
  const StudentRegistrationData({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.username,
    required this.password,
    required this.passwordConfirm,
    required this.aadharNumber,
    required this.resumeFilePath,
    required this.resumeFileName,
    this.gender = '',
    this.mobile = '',
    this.alternateMobile = '',
    this.bloodGroup = '',
    this.languagesKnown = '',
    this.panNumber = '',
    this.passportNumber = '',
    this.educationLevel = '',
    this.passedOutYear,
    this.itiDiplomaSpecialization = '',
    this.higherEducationDegree = '',
    this.educationLevel2 = '',
    this.passedOutYear2,
    this.itiDiplomaSpecialization2 = '',
    this.higherEducationDegree2 = '',
    this.hasExperience,
    this.experienceYears,
    this.companyName = '',
    this.contactPersonRole = '',
    this.contactPersonMobile = '',
    this.contactPersonEmail = '',
    this.industry = '',
    this.skills = '',
    this.currentCtc,
    this.expectedCtc,
    this.certification = '',
    this.currentLocation = '',
    this.preferredLocation = '',
    this.hasAbroadExperience,
    this.abroadYears,
    this.abroadCountry = '',
    this.abroadIndustry = '',
    this.abroadSkills = '',
  });

  // Account
  final String firstName;
  final String lastName;
  final String email;
  final String username;
  final String password;
  final String passwordConfirm;

  // Personal
  final String gender;

  /// E.164 (`"+<dial code><digits>"`), same convention as the employer
  /// HR-contact field — see `EmployerPhoneInputField`.
  final String mobile;
  final String alternateMobile;
  final String bloodGroup;
  final String languagesKnown;

  // Identity
  final String aadharNumber;
  final String panNumber;
  final String passportNumber;

  // Education
  final String educationLevel;
  final int? passedOutYear;
  final String itiDiplomaSpecialization;
  final String higherEducationDegree;

  // Additional education (optional second set)
  final String educationLevel2;
  final int? passedOutYear2;
  final String itiDiplomaSpecialization2;
  final String higherEducationDegree2;

  // Experience & skills
  final bool? hasExperience;
  final int? experienceYears;
  final String companyName;
  final String contactPersonRole;
  final String contactPersonMobile;
  final String contactPersonEmail;
  final String industry;
  final String skills;
  final double? currentCtc;
  final double? expectedCtc;
  final String certification;

  /// Local file path from the file picker — required
  /// (`resume = forms.FileField(required=True, ...)`).
  final String resumeFilePath;
  final String resumeFileName;

  // Location
  final String currentLocation;
  final String preferredLocation;

  // Abroad experience
  final bool? hasAbroadExperience;
  final int? abroadYears;
  final String abroadCountry;
  final String abroadIndustry;
  final String abroadSkills;
}

/// `users/models.py`'s exact choice lists (value/label pairs), verbatim.
class RegistrationChoiceOption {
  const RegistrationChoiceOption(this.value, this.label);
  final String value;
  final String label;
}

const List<RegistrationChoiceOption> kGenderOptions = [
  RegistrationChoiceOption('male', 'Male'),
  RegistrationChoiceOption('female', 'Female'),
  RegistrationChoiceOption('other', 'Other'),
  RegistrationChoiceOption('prefer_not', 'Prefer not to say'),
];

const List<RegistrationChoiceOption> kEducationLevelOptions = [
  RegistrationChoiceOption('7th', '7th Standard'),
  RegistrationChoiceOption('8th', '8th Standard'),
  RegistrationChoiceOption('9th', '9th Standard'),
  RegistrationChoiceOption('10th', '10th / SSLC'),
  RegistrationChoiceOption('11th', '11th Standard'),
  RegistrationChoiceOption('12th', '12th / HSC / PUC'),
  RegistrationChoiceOption('iti', 'ITI'),
  RegistrationChoiceOption('diploma', 'Diploma'),
  RegistrationChoiceOption('ug', 'Under-Graduate / Degree'),
  RegistrationChoiceOption('pg', 'Post-Graduate'),
];

const List<RegistrationChoiceOption> kBloodGroupOptions = [
  RegistrationChoiceOption('A+', 'A+'),
  RegistrationChoiceOption('A-', 'A-'),
  RegistrationChoiceOption('B+', 'B+'),
  RegistrationChoiceOption('B-', 'B-'),
  RegistrationChoiceOption('AB+', 'AB+'),
  RegistrationChoiceOption('AB-', 'AB-'),
  RegistrationChoiceOption('O+', 'O+'),
  RegistrationChoiceOption('O-', 'O-'),
];

const List<RegistrationChoiceOption> kIndustryOptions = [
  RegistrationChoiceOption('manufacturing', 'Manufacturing'),
  RegistrationChoiceOption('it_software', 'IT / Software'),
  RegistrationChoiceOption('healthcare', 'Healthcare & Pharma'),
  RegistrationChoiceOption('construction', 'Construction & Real Estate'),
  RegistrationChoiceOption('retail', 'Retail & FMCG'),
  RegistrationChoiceOption('hospitality', 'Hospitality & Tourism'),
  RegistrationChoiceOption('education', 'Education & Training'),
  RegistrationChoiceOption('finance', 'Finance, Banking & Insurance'),
  RegistrationChoiceOption('agriculture', 'Agriculture & Food Processing'),
  RegistrationChoiceOption('logistics', 'Logistics & Transportation'),
  RegistrationChoiceOption('automobile', 'Automobile & Engineering'),
  RegistrationChoiceOption('textile', 'Textile & Garments'),
  RegistrationChoiceOption('oil_gas', 'Oil, Gas & Energy'),
  RegistrationChoiceOption('government', 'Government / PSU'),
  RegistrationChoiceOption('media', 'Media & Entertainment'),
  RegistrationChoiceOption('telecom', 'Telecom'),
  RegistrationChoiceOption('other', 'Other'),
];

/// `get_max_passed_out_year()` (`users/forms.py`) — the year before the
/// current one, descending to 1990 (`range(get_max_passed_out_year(), 1989,
/// -1)`).
List<int> passedOutYearOptions() {
  final maxYear = DateTime.now().year - 1;
  return [for (var year = maxYear; year >= 1990; year--) year];
}
