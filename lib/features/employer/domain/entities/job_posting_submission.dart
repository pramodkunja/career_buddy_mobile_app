/// POST payload for `employer/employer/jobs/new/`
/// (`ApiEndpoints.employerJobCreate` — see its doc comment for the full,
/// live-production-verified field contract this mirrors field-for-field).
/// Every field name here is the exact Django form field name the live page
/// posts, so `JobPostingRemoteDataSource.submit` can send them unchanged.
///
/// Deliberately a flat bag of strings/bools/lists rather than a richer
/// typed model (e.g. a `JobCategory` enum) — the live view's own branching
/// (IT vs. Non-IT×Technical vs. Non-IT×Non-Technical) only ever changes
/// which of these fields are *shown*/*required*, never their shape, and
/// the server is the final authority on which combination is valid (see
/// `JobPostingRemoteDataSource`'s doc comment on why validation is not
/// reimplemented client-side). A field irrelevant to the branch the user is
/// actually on is simply sent empty/false, matching what the real page's
/// own hidden/`d-none` inputs already do for fields outside the active
/// branch.
class JobPostingSubmission {
  const JobPostingSubmission({
    required this.jobCategory,
    required this.jobClassification,
    required this.department,
    required this.departmentFunction,
    required this.designation,
    required this.industrySector,
    required this.title,
    required this.jobType,
    required this.contractDurationMonths,
    required this.employmentType,
    required this.experiencePreset,
    required this.experienceYears,
    required this.experiencePlus,
    required this.experienceYearsMax,
    required this.location,
    required this.educationPreset,
    required this.educationOther,
    required this.functionalSkills,
    required this.industryExperience,
    required this.workingHours,
    required this.salaryFormat,
    required this.salaryMin,
    required this.salaryMax,
    required this.openings,
    required this.perks,
    required this.description,
    required this.requirements,
    required this.responsibilities,
    required this.certifications,
    required this.softwareSkills,
    required this.languageRequirements,
    required this.keywords,
    required this.applicationContact,
    required this.skills,
    required this.mandatorySkills,
    required this.deadline,
    required this.status,
    required this.workEnvironment,
    required this.interviewMode,
    required this.interviewModeOther,
    required this.workMode,
    required this.joiningRequirement,
    required this.noticePeriod,
    required this.noticePeriodOther,
    required this.genderPreference,
    required this.ageLimit,
  });

  /// `job_category` — `"it"` | `"non_it"`.
  final String jobCategory;

  /// `job_classification` — `"technical"` | `"non_technical"` | `""`
  /// (only meaningful when [jobCategory] is `"non_it"`).
  final String jobClassification;

  /// `department` — one of `kDepartmentOptions`' values, or `""`.
  final String department;

  /// `department_function` — free text, Non-IT + Non-Technical only.
  final String departmentFunction;

  /// `designation` — one of `kDesignationOptions`' values, or `""`.
  final String designation;

  /// `industry_sector` — free text, Non-IT only.
  final String industrySector;

  final String title;

  /// `job_type` — `kJobTypeOptions`' values, IT only.
  final String jobType;

  /// `contract_duration_months` — digits only, up to 2 characters.
  final String contractDurationMonths;

  /// `employment_type` — `kEmploymentTypeOptions`' values, Non-IT only.
  final String employmentType;

  /// `experience` — one of `kExperiencePresets`' values, or `"custom"` when
  /// [experienceYears] was typed instead of picked.
  final String experiencePreset;

  /// `experience_years` — digits only, up to 2 characters; only meaningful
  /// when [experiencePreset] is `"custom"`.
  final String experienceYears;

  /// `experience_plus` — `"True"`/`"False"` (the real page's own literal
  /// hidden-input values — not JSON `true`/`false`).
  final bool experiencePlus;

  /// `experience_years_max` — digits only, the upper end of a typed
  /// "N-M years" range; empty when not a range.
  final String experienceYearsMax;

  final String location;

  /// `education` — one of `kEducationPresets`' values, or `"custom"` when
  /// [educationOther] was typed instead of picked.
  final String educationPreset;

  /// `education_other` — free text; only meaningful when [educationPreset]
  /// is `"custom"`.
  final String educationOther;

  /// `functional_skills` — free text, Non-IT + Non-Technical only.
  final String functionalSkills;

  /// `industry_experience` — free text, Non-IT only.
  final String industryExperience;

  /// `working_hours` — free text, Non-IT only.
  final String workingHours;

  /// `salary_format` — `kSalaryFormatOptions`' values.
  final String salaryFormat;

  /// `salary_min`/`salary_max` — digits only, up to 6 characters each.
  final String salaryMin;
  final String salaryMax;

  final int openings;

  /// `perks` — zero or more of `kPerksOptions`' values.
  final List<String> perks;

  final String description;

  /// `requirements` — "Technical Requirements", IT only.
  final String requirements;

  /// `responsibilities` — Non-IT only.
  final String responsibilities;

  /// `certifications` — free text, Non-IT only.
  final String certifications;

  /// `software_skills` — free text, Non-IT + Non-Technical only.
  final String softwareSkills;

  /// `language_requirements` — free text, Non-IT + Non-Technical only.
  final String languageRequirements;

  /// `keywords` — free text, Non-IT only.
  final String keywords;

  /// `application_contact` — free text, Non-IT only.
  final String applicationContact;

  /// `skills` — zero or more exact skill labels from whichever
  /// `JobSkillCategory` is active (IT's general group, or the selected
  /// department's group); always empty for Non-IT + Non-Technical.
  final List<String> skills;

  /// `mandatory_skills` — sent as ONE comma-joined string by the real page
  /// (`id_mandatory_skills`'s hidden input), reproduced the same way by
  /// `JobPostingRemoteDataSource`; kept as a list here since that's how the
  /// UI naturally tracks it (star-marked subset of [skills]).
  final List<String> mandatorySkills;

  /// `deadline` — `YYYY-MM-DD`, or empty (optional, IT only).
  final String deadline;

  /// `status` — `kJobStatusOptions`' values, IT only (defaults to
  /// `"active"` elsewhere, matching the live page never showing this field
  /// outside the IT branch yet the model field still needing a value).
  final String status;

  /// `work_environment` — `kWorkEnvironmentOptions`' values, IT only.
  final String workEnvironment;

  /// `interview_mode` — `kInterviewModeOptions`' values, IT only.
  final String interviewMode;

  /// `interview_mode_other` — free text; only meaningful when
  /// [interviewMode] is `"others"`.
  final String interviewModeOther;

  /// `work_mode` — `kWorkModeOptions`' values, Non-IT only (the Non-IT
  /// counterpart of [workEnvironment]).
  final String workMode;

  /// `joining_requirement` — `kJoiningRequirementOptions`' values, Non-IT +
  /// Non-Technical only (the Non-IT + Non-Technical counterpart of
  /// [noticePeriod]).
  final String joiningRequirement;

  /// `notice_period` — `kNoticePeriodOptions`' values, IT + Non-IT×Technical
  /// (the real page's own `nontech-hide` class — hidden only for Non-IT +
  /// Non-Technical, where [joiningRequirement] is shown instead).
  final String noticePeriod;

  /// `notice_period_other` — free text; only meaningful when [noticePeriod]
  /// is `"others"`.
  final String noticePeriodOther;

  /// `gender_preference` — `kGenderPreferenceOptions`' values.
  final String genderPreference;

  /// `age_limit` — free text, Non-IT only.
  final String ageLimit;
}
