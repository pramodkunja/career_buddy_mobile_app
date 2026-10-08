/// `templates/users/profile.html`'s "Profile Details" (Overview) tab —
/// scraped from the single GET `/users/profile/` response (no JSON API;
/// there's also no separate URL for the two tabs, both are rendered in one
/// page — see `ProfileRemoteDataSource`'s doc comment). [fields] holds every
/// `info-item-label` → `info-item-value` pair the server actually rendered
/// (conditional blocks the server chose not to render simply don't appear
/// as a key) — see `ProfileFieldLabels` for the known label strings this
/// app looks up.
class ProfileOverview {
  const ProfileOverview({
    required this.fullName,
    required this.username,
    required this.email,
    required this.activitiesStarted,
    required this.completedSubs,
    required this.totalScore,
    required this.recentResults,
    required this.fields,
    required this.englishLevel,
    required this.bio,
    required this.additionalEducationsJson,
    this.contactPersonRole = '',
    this.contactPersonMobile = '',
    this.contactPersonEmail = '',
  });

  final String fullName;
  final String username;
  final String email;
  final int activitiesStarted;
  final int completedSubs;
  final int totalScore;
  final List<ProfileRecentResult> recentResults;
  final Map<String, String> fields;

  /// `ProfileUpdateForm.Meta.fields`'s `english_level` — not editable via
  /// any Edit tab control, but required server-side (see
  /// [ProfileEditData.englishLevel]'s doc comment), so [getProfile] scrapes
  /// the server's own current selection to round-trip it on save.
  final String englishLevel;

  /// `ProfileUpdateForm.Meta.fields`'s `bio` — same round-trip-only
  /// reasoning as [englishLevel].
  final String bio;

  /// The exact JSON array text (still JS-string-literal-escaped-then-decoded,
  /// never re-encoded) backing `UserProfile.additional_educations_json` —
  /// same round-trip-only reasoning as [englishLevel]. Defaults to `'[]'`
  /// when the page has nothing to scrape.
  final String additionalEducationsJson;

  /// `contact_person_role`/`contact_person_mobile`/`contact_person_email` —
  /// unlike every other field above, these have no Overview `info-item` on
  /// the live page at all (confirmed directly against production), so they
  /// can only be recovered from the Edit tab's own form markup — see
  /// `ProfileRemoteDataSource`'s extraction doc comments. Editable via the
  /// Edit tab (unlike [englishLevel]/[bio]/[additionalEducationsJson], which
  /// are round-trip-only with no corresponding UI).
  final String contactPersonRole;
  final String contactPersonMobile;
  final String contactPersonEmail;

  String field(String label) => fields[label] ?? '';
}

class ProfileRecentResult {
  const ProfileRecentResult({required this.title, required this.score, required this.maxScore});
  final String title;
  final int score;
  final int maxScore;
}

/// The exact `info-item-label` text `templates/users/profile.html`'s
/// Overview tab renders for each field, used both to parse the response and
/// to pre-fill the Edit tab's form controllers from it.
abstract final class ProfileFieldLabels {
  static const mobile = 'Mobile Number';
  static const alternateMobile = 'Alternate Mobile';
  static const gender = 'Gender';
  static const bloodGroup = 'Blood Group';
  static const languagesKnown = 'Languages Known';
  static const aadhar = 'Aadhar Number';
  static const pan = 'PAN Number';
  static const passport = 'Passport Number';
  static const educationLevel = 'Highest Qualification';
  static const passedOutYear = 'Year of Passing';
  static const higherEducationDegree = 'Degree / Course Name';
  static const itiDiplomaSpecialization = 'ITI / Diploma Specialization';
  static const educationLevel2 = 'Additional Qualification';
  static const passedOutYear2 = 'Additional Year of Passing';
  static const higherEducationDegree2 = 'Additional Degree / Course';
  static const itiDiplomaSpecialization2 = 'Additional ITI / Diploma Specialization';
  static const experienceStatus = 'Experience Status';
  static const companyName = 'Company Name';
  static const experienceYears = 'Years of Experience';
  static const industry = 'Industry Sector';
  static const currentCtc = 'Current CTC';
  static const expectedCtc = 'Expected CTC';
  static const contactPerson = 'Contact Person (Manager / HR)';
  static const skills = 'Skillset & Expertise';
  static const certification = 'Certifications';
  static const currentLocation = 'Current Location';
  static const preferredLocation = 'Preferred Location';
  static const abroadExperience = 'Abroad Experience';
  static const abroadYears = 'Years Abroad';
  static const abroadCountry = 'Country';
  static const abroadIndustry = 'Industry Abroad';
  static const abroadSkills = 'Skills Gained Abroad';
}

/// `ProfileUpdateForm` (`users/forms.py`) — the editable subset of
/// `StudentRegistrationData`'s fields (no `username`/`password`, since
/// those can't be changed from this form; `resume` optional, not required).
/// Identity fields (`aadharNumber`/`panNumber`/`passportNumber`) follow the
/// server's own masked-field contract: leaving one blank means "keep the
/// existing value," never "clear it" — see `ProfileEditScreen`'s doc
/// comment.
class ProfileEditData {
  const ProfileEditData({
    required this.firstName,
    required this.lastName,
    required this.email,
    this.gender = '',
    this.mobile = '',
    this.alternateMobile = '',
    this.bloodGroup = '',
    this.languagesKnown = '',
    this.aadharNumber = '',
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
    this.resumeFilePath,
    this.resumeFileName,
    this.currentLocation = '',
    this.preferredLocation = '',
    this.hasAbroadExperience,
    this.abroadYears,
    this.abroadCountry = '',
    this.abroadIndustry = '',
    this.abroadSkills = '',
    required this.englishLevel,
    required this.bio,
    required this.additionalEducationsJson,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String gender;
  final String mobile;
  final String alternateMobile;
  final String bloodGroup;
  final String languagesKnown;

  /// Blank = "leave unchanged" (masked field — see class doc comment).
  final String aadharNumber;
  final String panNumber;
  final String passportNumber;

  final String educationLevel;
  final int? passedOutYear;
  final String itiDiplomaSpecialization;
  final String higherEducationDegree;
  final String educationLevel2;
  final int? passedOutYear2;
  final String itiDiplomaSpecialization2;
  final String higherEducationDegree2;
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

  /// `null` = leave the existing resume unchanged (optional on edit, unlike
  /// registration's required upload).
  final String? resumeFilePath;
  final String? resumeFileName;

  final String currentLocation;
  final String preferredLocation;
  final bool? hasAbroadExperience;
  final int? abroadYears;
  final String abroadCountry;
  final String abroadIndustry;
  final String abroadSkills;

  /// Required (`ProfileUpdateForm.Meta.fields`, `users/forms.py:802`) with
  /// no `blank=True` on the model (`users/models.py:111`) — Flutter has no
  /// UI to edit this, so callers MUST pass through the exact value
  /// [ProfileOverview.englishLevel] scraped from the last `getProfile()`,
  /// never a hardcoded default, or every save will fail `form.is_valid()`.
  final String englishLevel;

  /// Optional server-side, but sent with nothing omitted-means-unchanged
  /// behavior (unlike [aadharNumber] et al.) — an absent/blank POST value
  /// silently clears it. Callers MUST pass through
  /// [ProfileOverview.bio] verbatim to avoid wiping the user's bio.
  final String bio;

  /// Same silent-clear risk as [bio] — `users/forms.py:922-925` always
  /// overwrites `additional_educations_json` from whatever (if anything)
  /// is posted under this key, with no "leave unchanged" fallback. Callers
  /// MUST pass through [ProfileOverview.additionalEducationsJson] verbatim.
  final String additionalEducationsJson;
}
