import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/validators/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/app_nav_drawer.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../../../shared/widgets/drawer_aware_back_leading.dart';
import '../../data/job_posting_catalog.dart';
import '../../domain/entities/job_posting_submission.dart';
import '../controllers/job_openings_controller.dart';
import '../providers/employer_dashboard_providers.dart';
import '../providers/job_posting_providers.dart';

/// `jobs_app.views.job_create` (`employer/employer/jobs/new/`) — see
/// `ApiEndpoints.employerJobCreate`'s doc comment for the full,
/// live-production-verified field contract this screen reproduces, and
/// `job_posting_catalog.dart` for every option/skill value (all copied
/// verbatim from the live page, nothing invented).
///
/// **Validation philosophy**: this screen only pre-checks the handful of
/// fields confirmed, by directly POSTing a deliberately incomplete request
/// to the real production endpoint during this task, to be unconditionally
/// required regardless of category/classification (title, job type,
/// experience, location, salary format/min/max, openings, description,
/// status, and the 4 radio groups) — using the exact wording the live
/// server itself returned. Every other field's requiredness depends on
/// which of the 3 branches (IT / Non-IT×Technical / Non-IT×Non-Technical)
/// is active, and that was deliberately NOT guessed from reading the
/// live page's client-side JS alone — the real POST is always the final
/// authority, and its own per-field errors (`JobPostingRemoteDataSource`)
/// are shown here exactly as the server phrases them.
class PostNewJobScreen extends ConsumerStatefulWidget {
  /// `jobId` non-null means Edit mode — the exact same form, seeded from
  /// `JobPostingRepository.getJobForEdit(jobId)` instead of starting blank,
  /// and submitted via `submitEdit` instead of `submit`. See this class's
  /// own doc comment for the full Create contract both modes share.
  const PostNewJobScreen({this.jobId, super.key});

  final int? jobId;

  @override
  ConsumerState<PostNewJobScreen> createState() => _PostNewJobScreenState();
}

class _PostNewJobScreenState extends ConsumerState<PostNewJobScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Job Overview & Type ────────────────────────────────────────────────
  String _jobCategory = '';
  String _jobClassification = '';
  String _department = '';
  final _departmentFunction = TextEditingController();
  String _designation = '';
  final _industrySector = TextEditingController();
  final _title = TextEditingController();
  String _jobType = '';
  final _contractDurationMonths = TextEditingController();
  String _employmentType = '';
  String _experiencePreset = '';
  final _experienceYearsTyped = TextEditingController();
  // Phase 55 — `experience_plus`/`experience_years_max` are only meaningful
  // when `_experiencePreset == 'custom'`, exactly like `_experienceYearsTyped`
  // (`forms.py`'s `clean()` discards all three for any preset). The web
  // page's combo box makes "+" and a typed max structurally mutually
  // exclusive (its keydown handler refuses "+" once a "-" range has
  // started, and vice versa); `_experiencePlus` checked clears
  // `_experienceYearsMax` and hides its field, reproducing that exclusion.
  bool _experiencePlus = false;
  final _experienceYearsMax = TextEditingController();
  final _location = TextEditingController();
  String _educationPreset = '';
  final _educationOther = TextEditingController();
  final _functionalSkills = TextEditingController();
  final _industryExperience = TextEditingController();
  final _workingHours = TextEditingController();

  // ── Salary & Vacancies ──────────────────────────────────────────────────
  String _salaryFormat = 'monthly';
  final _salaryMin = TextEditingController();
  final _salaryMax = TextEditingController();
  final _openings = TextEditingController(text: '1');

  // ── Perks ───────────────────────────────────────────────────────────────
  final Set<String> _perks = {};

  // ── Description & Skills ───────────────────────────────────────────────
  final _description = TextEditingController();
  final _requirements = TextEditingController();
  final _responsibilities = TextEditingController();
  final _certifications = TextEditingController();
  final _softwareSkills = TextEditingController();
  final _languageRequirements = TextEditingController();
  final _keywords = TextEditingController();
  final _applicationContact = TextEditingController();
  final Set<String> _selectedSkills = {};
  final Set<String> _mandatorySkills = {};
  final List<String> _customItSkills = [];
  final _itCustomSkillInput = TextEditingController();
  String? _customSkillError;

  // ── Timeline & Publish ──────────────────────────────────────────────────
  DateTime? _deadline;
  String _status = 'active';

  // ── Work Environment / Interview / Notice / Gender ──────────────────────
  String _workEnvironment = '';
  String _interviewMode = '';
  final _interviewModeOther = TextEditingController();
  String _workMode = '';
  String _joiningRequirement = '';
  String _noticePeriod = '';
  final _noticePeriodOther = TextEditingController();
  String _genderPreference = '';
  final _ageLimit = TextEditingController();

  bool _submitting = false;
  String? _generalError;
  Map<String, String> _fieldErrors = {};

  // ── Edit mode ────────────────────────────────────────────────────────────
  bool get _isEdit => widget.jobId != null;
  bool _hydrated = false;
  String? _loadError;

  bool get _isIt => _jobCategory == 'it';
  bool get _isNonIt => _jobCategory == 'non_it';
  bool get _isNonItTech => _isNonIt && _jobClassification == 'technical';
  bool get _isNonItNonTech => _isNonIt && _jobClassification == 'non_technical';

  /// Phase 57 — mirrors `job_form.html`'s own `isContract()`: `"Project
  /// Duration"` is asked for Contract postings only, **IT and both NON-IT
  /// sheets alike** (`forms.py`'s `clean()`, the `job_type == 'contract'`
  /// block). IT's "contract" lives in `_jobType` (`kJobTypeOptions`); both
  /// NON-IT sheets share one `_employmentType` field instead
  /// (`TECH_EMPLOYMENT_TYPE_CHOICES` — "`'contract'` is shared with the IT
  /// list so the duration logic is the same", `models.py`) — never both at
  /// once, since `_onCategoryChanged` always blanks whichever of the 2
  /// isn't relevant to the newly-selected category.
  bool get _isContract => _jobType == 'contract' || _employmentType == 'contract';

  JobSkillCategory? get _currentSkillCategory {
    final key = _isIt
        ? 'it'
        : _isNonItTech
        ? _department
        : '';
    if (key.isEmpty) return null;
    for (final category in kSkillCatalog) {
      if (category.key == key) return category;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadExistingJob();
  }

  Future<void> _loadExistingJob() async {
    final result = await ref.read(jobPostingRepositoryProvider).getJobForEdit(widget.jobId!);
    if (!mounted) return;
    switch (result) {
      case Success(value: final data):
        setState(() {
          _hydrateFrom(data);
          _hydrated = true;
        });
      case Failed(failure: final failure):
        setState(() {
          _loadError = failure.message;
          _hydrated = true;
        });
    }
  }

  /// Seeds every controller/field from an existing job's current values —
  /// the exact inverse of [_submit]'s `JobPostingSubmission` construction.
  void _hydrateFrom(JobPostingSubmission data) {
    _jobCategory = data.jobCategory;
    _jobClassification = data.jobClassification;
    _department = data.department;
    _departmentFunction.text = data.departmentFunction;
    _designation = data.designation;
    _industrySector.text = data.industrySector;
    _title.text = data.title;
    _jobType = data.jobType;
    _contractDurationMonths.text = data.contractDurationMonths;
    _employmentType = data.employmentType;
    _experiencePreset = data.experiencePreset;
    _experienceYearsTyped.text = data.experienceYears;
    _experiencePlus = data.experiencePlus;
    _experienceYearsMax.text = data.experienceYearsMax;
    _location.text = data.location;
    _educationPreset = data.educationPreset;
    _educationOther.text = data.educationOther;
    _functionalSkills.text = data.functionalSkills;
    _industryExperience.text = data.industryExperience;
    _workingHours.text = data.workingHours;
    _salaryFormat = data.salaryFormat.isEmpty ? _salaryFormat : data.salaryFormat;
    _salaryMin.text = data.salaryMin;
    _salaryMax.text = data.salaryMax;
    // `null` means the scrape couldn't determine the job's real opening
    // count (see `JobPostingSubmission.openings`'s doc comment) — leave the
    // field blank rather than show a guessed number as if it were real;
    // the existing "Please enter a valid numeric value" validator below
    // already blocks Save until the employer supplies the real count.
    _openings.text = data.openings?.toString() ?? '';
    _perks
      ..clear()
      ..addAll(data.perks);
    _description.text = data.description;
    _requirements.text = data.requirements;
    _responsibilities.text = data.responsibilities;
    _certifications.text = data.certifications;
    _softwareSkills.text = data.softwareSkills;
    _languageRequirements.text = data.languageRequirements;
    _keywords.text = data.keywords;
    _applicationContact.text = data.applicationContact;
    _selectedSkills
      ..clear()
      ..addAll(data.skills);
    _mandatorySkills
      ..clear()
      ..addAll(data.mandatorySkills);
    // Any selected IT skill not in the static catalog's general list is one
    // the employer previously free-typed (see `_addCustomItSkill`) — surface
    // it as a pre-existing chip the same way a freshly-typed one would be.
    if (data.jobCategory == 'it') {
      final catalogSkills = kSkillCatalog.firstWhere((c) => c.key == 'it').skills;
      _customItSkills
        ..clear()
        ..addAll(data.skills.where((s) => !catalogSkills.contains(s)));
    }
    _deadline = DateTime.tryParse(data.deadline);
    _status = data.status.isEmpty ? _status : data.status;
    _workEnvironment = data.workEnvironment;
    _interviewMode = data.interviewMode;
    _interviewModeOther.text = data.interviewModeOther;
    _workMode = data.workMode;
    _joiningRequirement = data.joiningRequirement;
    _noticePeriod = data.noticePeriod;
    _noticePeriodOther.text = data.noticePeriodOther;
    _genderPreference = data.genderPreference;
    _ageLimit.text = data.ageLimit;
  }

  @override
  void dispose() {
    for (final c in [
      _departmentFunction,
      _industrySector,
      _title,
      _contractDurationMonths,
      _experienceYearsTyped,
      _experienceYearsMax,
      _location,
      _educationOther,
      _functionalSkills,
      _industryExperience,
      _workingHours,
      _salaryMin,
      _salaryMax,
      _openings,
      _description,
      _requirements,
      _responsibilities,
      _certifications,
      _softwareSkills,
      _languageRequirements,
      _keywords,
      _applicationContact,
      _itCustomSkillInput,
      _interviewModeOther,
      _noticePeriodOther,
      _ageLimit,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Phase 52 — in addition to the pre-existing resets, clears whichever of
  /// `job_type`/`work_environment`/`interview_mode` (IT-only,
  /// `jobs_app/forms.py`'s `clean()` `else` branch always blanks the
  /// NON-IT-only trio when `not non_it`) or `work_mode`/`employment_type`/
  /// `notice_period` (the IT-only trio NON-IT never shows) the newly
  /// selected category can no longer show — the real page doesn't carry a
  /// stale value across categories either way (it blanks the inapplicable
  /// side server-side on every submit, `forms.py:855,878-881`), so a
  /// leftover value from before the switch is never meaningful and
  /// shouldn't linger in a field the employer can no longer see.
  void _onCategoryChanged(String value) {
    setState(() {
      _jobCategory = value;
      _jobClassification = '';
      _department = '';
      _selectedSkills.clear();
      _mandatorySkills.clear();
      _customItSkills.clear();
      if (value == 'it') {
        _workMode = '';
        _employmentType = '';
        _joiningRequirement = '';
      } else {
        _jobType = '';
        _workEnvironment = '';
        _interviewMode = '';
        _interviewModeOther.clear();
        // `notice_period` is reused by Non-IT×Technical (see
        // `_onClassificationChanged`) — left alone here, only cleared when
        // the classification itself rules it out.
        _noticePeriod = '';
        _noticePeriodOther.clear();
      }
      // Required for IT only (`forms.py:840-841`, "If Applicable" on both
      // NON-IT sheets) — not hidden on NON-IT, so not blanked, just no
      // longer treated as required; see `_localRequiredErrors`.
      // `education`'s own allowed preset set depends on `_isNonItTech`,
      // which is now `false` either way (`_jobClassification` was just
      // cleared above) — a stale NON-IT×Technical-only preset (Degree /
      // Certification) can't be shown with no classification picked, so it
      // is cleared the same way the real page clears it
      // (`job_form.html`'s `eduApplyPreset('')`); typed ("custom") text is
      // always kept, exactly as the web page keeps it.
      if (_educationPreset != 'custom' &&
          !_educationOptionsFor(false).any((o) => o.$1 == _educationPreset)) {
        _educationPreset = '';
      }
      // Phase 57 — a category switch always blanks whichever of
      // `_jobType`/`_employmentType` could have held `'contract'` for the
      // old category (above), so `_isContract` is always `false` right
      // after this method runs — the duration can never remain relevant.
      _contractDurationMonths.clear();
    });
  }

  /// Phase 52 — `notice_period` (pills) is Non-IT×Technical's own mandatory
  /// field ("Technical keeps the Notice Period pills as its mandatory
  /// Joining Requirement", `forms.py:872-877`); `joining_requirement`
  /// (dropdown) is Non-IT×Non-Technical's instead. Switching between the 2
  /// classifications must not leave the other one's stale selection behind.
  void _onClassificationChanged(String value) {
    setState(() {
      _jobClassification = value;
      _department = '';
      _selectedSkills.clear();
      _mandatorySkills.clear();
      if (value == 'non_technical') {
        _noticePeriod = '';
        _noticePeriodOther.clear();
      } else {
        _joiningRequirement = '';
      }
      // `work_mode`'s allowed-options list is classification-specific
      // (`kTechWorkModeOptions`/`kNonTechWorkModeOptions`) and the 2 lists
      // aren't identical ("Plant" vs. "Hybrid") — a value valid in the old
      // classification's list may not exist in the new one's `Dropdown
      // ButtonFormField.items`, which would otherwise leave the field
      // showing a value Flutter can't find a matching item for.
      if (!_workModeOptionsFor(value).any((o) => o.$1 == _workMode)) {
        _workMode = '';
      }
      // `education`'s own preset list is classification-specific too (see
      // `_educationOptionsFor`'s own doc comment) — a stale selection from
      // the sheet just left behind must not remain selected; typed
      // ("custom") text is always kept.
      if (_educationPreset != 'custom' &&
          !_educationOptionsFor(value == 'technical').any((o) => o.$1 == _educationPreset)) {
        _educationPreset = '';
      }
    });
  }

  void _onDepartmentChanged(String value) {
    setState(() {
      _department = value;
      _selectedSkills.clear();
      _mandatorySkills.clear();
    });
  }

  void _toggleSkill(String skill, bool selected) {
    setState(() {
      if (selected) {
        _selectedSkills.add(skill);
      } else {
        _selectedSkills.remove(skill);
        _mandatorySkills.remove(skill);
      }
    });
  }

  void _toggleMandatory(String skill) {
    if (!_selectedSkills.contains(skill)) return;
    if (!_mandatorySkills.contains(skill) &&
        _mandatorySkills.length >= kMandatorySkillsMax) {
      setState(
        () => _customSkillError =
            'You can mark at most $kMandatorySkillsMax skills as mandatory.',
      );
      return;
    }
    setState(() {
      _customSkillError = null;
      if (_mandatorySkills.contains(skill)) {
        _mandatorySkills.remove(skill);
      } else {
        _mandatorySkills.add(skill);
      }
    });
  }

  /// Mirrors `custom_skill_error()` (`jobs_app/forms.py`) exactly, in the
  /// same order: too-long first (with its own truncated-preview message),
  /// then character-class-or-no-letter (one combined message, since Django
  /// also combines those two conditions with `or`).
  void _addCustomItSkill() {
    final raw = _itCustomSkillInput.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (raw.isEmpty) return;
    if (raw.contains(',')) {
      setState(
        () => _customSkillError = 'Add one skill at a time (no commas).',
      );
      return;
    }
    if (raw.length > kCustomSkillMaxLength) {
      setState(
        () => _customSkillError =
            '"${raw.substring(0, 20)}..." is too long; keep each skill under $kCustomSkillMaxLength characters.',
      );
      return;
    }
    if (!kCustomSkillPattern.hasMatch(raw) ||
        !kCustomSkillLetterPattern.hasMatch(raw)) {
      setState(
        () => _customSkillError =
            '"$raw" is not a valid skill name. Use letters, numbers and . & / ( ) \' + # - only, one skill at a time.',
      );
      return;
    }
    setState(() {
      _customSkillError = null;
      if (!_customItSkills.contains(raw)) _customItSkills.add(raw);
      _selectedSkills.add(raw);
      _itCustomSkillInput.clear();
    });
  }

  /// Live client-side guidance mirroring the real page's own
  /// `validateSkills()` — purely a helpful counter/hint; the server POST
  /// (`JobPostingRemoteDataSource`) remains the actual authority.
  String? get _skillsHint {
    if (_isNonItNonTech) return null;
    final selected = _selectedSkills.length;
    final mandatory = _mandatorySkills.length;
    if (_currentSkillCategory == null) return null;
    if (selected == 0) {
      return _isNonItTech ? 'Select the skills required for this job.' : null;
    }
    if (mandatory < kMandatorySkillsMin || mandatory > kMandatorySkillsMax) {
      return 'Mark $kMandatorySkillsMin to $kMandatorySkillsMax of the selected skills as mandatory '
          '(currently $mandatory).';
    }
    return null;
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  /// The handful of fields confirmed unconditionally required (see this
  /// class's own doc comment) — checked locally, with the exact wording
  /// the live server itself returns, so an obviously-incomplete submission
  /// doesn't need a round trip to discover that.
  ///
  /// Phase 52 — the rest (`work_environment`/`interview_mode`/
  /// `notice_period`/`gender_preference`/`job_type` vs. `work_mode`/
  /// `employment_type`/`joining_requirement`) are **not** unconditional:
  /// `jobs_app/forms.py`'s `clean()` (re-read directly this phase, exact
  /// current line numbers below) requires a genuinely different set per
  /// category/classification, and this method previously required all of
  /// the IT-only ones even when their own widgets are correctly hidden for
  /// Non-IT — a Non-IT posting could never pass local validation no matter
  /// what the employer filled in. Mirrored here exactly:
  ///  - `gender_preference`: required for IT only; "If Applicable" (never
  ///    required) on both Non-IT sheets (`forms.py:840-841`).
  ///  - `interview_mode`: required for IT only; not on either Non-IT sheet
  ///    at all — the model default is used silently (`forms.py:844-849`).
  ///  - `job_type`/`work_environment`: required for IT only
  ///    (`forms.py:878-884`); Non-IT's own equivalents are
  ///    `employment_type`/`work_mode` below.
  ///  - `notice_period`: required for IT **and** Non-IT×Technical, which
  ///    "keeps the Notice Period pills as its mandatory Joining
  ///    Requirement" (`forms.py:872-877`) — not Non-IT×Non-Technical, whose
  ///    own equivalent is `joining_requirement` below.
  ///  - `work_mode`/`employment_type`: required for **both** Non-IT
  ///    sheets, feeding `work_environment`/`job_type` server-side
  ///    (`forms.py:856-864`).
  ///  - `joining_requirement`: required for Non-IT×Non-Technical only
  ///    (`forms.py:858-859`).
  ///  - `education`: required for **both** Non-IT sheets (Technical and
  ///    Non-Technical alike — `non_it` is true for either); never required
  ///    for IT, which has no field-level or `clean()`-level requirement for
  ///    it at all (`forms.py:836-838`; confirmed via `models.py:200`'s
  ///    `blank=True` and no `__init__` override). Phase 53 — this method
  ///    never checked it before. Deliberately NOT mirrored here: the
  ///    `TECH_EDUCATION_KEYS`/`TECH_ONLY_EDUCATION_KEYS` accepted-value
  ///    constraints (`forms.py:884-894`), a distinct "accepted value set"
  ///    class of gap left for a future phase (see
  ///    `docs/PHASE_53_NONIT_EDUCATION_VALIDATION_REPORT.md`).
  Map<String, String> _localRequiredErrors() {
    final errors = <String, String>{};
    if (_jobCategory.isEmpty) errors['job_category'] = 'Select a job category.';
    if (_isIt && _jobType.isEmpty) {
      errors['job_type'] = 'This field is required.';
    }
    // Phase 57 — mirrors `forms.py`'s `clean()` `job_type == 'contract'`
    // block + `clean_contract_duration_months`'s own `> 12` check + the
    // field's `'invalid'`/`'min_value'` error-message overrides, in the
    // same order the server applies them: non-numeric, then negative,
    // then over the 12-month cap, then under the 1-month floor.
    if (_isContract) {
      final text = _contractDurationMonths.text.trim();
      if (text.isEmpty) {
        errors['contract_duration_months'] = 'Enter the project duration in months.';
      } else {
        final months = int.tryParse(text);
        if (months == null) {
          errors['contract_duration_months'] = 'Enter the project duration as a whole number of months.';
        } else if (months < 0) {
          errors['contract_duration_months'] = 'Project duration cannot be negative.';
        } else if (months > 12) {
          errors['contract_duration_months'] = 'Project duration cannot exceed 12 months.';
        } else if (months < 1) {
          errors['contract_duration_months'] = 'Project duration must be at least 1 month.';
        }
      }
    }
    if (_experiencePreset.isEmpty) {
      errors['experience'] = 'This field is required.';
    } else if (_experiencePreset == 'custom') {
      final minText = _experienceYearsTyped.text.trim();
      final minError = _experienceYearsError(minText, 'Enter a whole number of years (0-99).');
      if (minError != null) {
        errors['experience'] = minError;
      }
      final maxText = _experienceYearsMax.text.trim();
      // Phase 55 — only meaningful when actually supplied: an empty max
      // means "no maximum" (fresher/`8+`-style open-ended), not an error —
      // the server itself only runs its range check `elif years_max is not
      // None` (`forms.py`'s `clean()`).
      if (maxText.isNotEmpty) {
        final maxError = _experienceYearsError(
          maxText,
          'Enter the maximum experience as a whole number of years (0-99).',
        );
        if (maxError != null) {
          errors['experience_years_max'] = maxError;
        } else if (minError == null) {
          final minYears = int.parse(minText);
          final maxYears = int.parse(maxText);
          if (minYears > maxYears) {
            errors['experience'] = 'Minimum experience cannot be greater than maximum experience.';
          }
        }
      }
    }
    if (_salaryFormat.isEmpty) {
      errors['salary_format'] = 'This field is required.';
    }
    // Phase 63 — mirrors `SALARY_RULES`/`_clean_salary_range`/`clean()`'s
    // cross-check (`jobs_app/forms.py`) exactly. Every message below,
    // including the "is required." one, is format-specific — the server's
    // own `field.error_messages.update({'required': f'{label} is
    // required.', ...})` resolves `label` from the *selected*
    // `salary_format` (`forms.py`'s `_salary_format()` reads the raw
    // submitted value), so "Minimum LPA is required." replaces "Minimum
    // Salary is required." once LPA is selected, not just the numeric
    // bounds. The cross-field check only runs when both values already
    // parsed and individually passed their own checks (`clean()` only
    // compares `cleaned.get('salary_min')`/`cleaned.get('salary_max')`,
    // which are absent whenever the field-level clean raised), and is
    // always attached to `salary_min`, never `salary_max`.
    final isLpaSalary = _salaryFormat == 'lpa';
    final minLabel = isLpaSalary ? 'Minimum LPA' : 'Minimum Salary';
    final maxLabel = isLpaSalary ? 'Maximum LPA' : 'Maximum Salary';
    final rangeLabel = isLpaSalary ? 'LPA' : 'Salary';
    int? parsedMin;
    int? parsedMax;
    final minText = _salaryMin.text.trim();
    if (minText.isEmpty) {
      errors['salary_min'] = '$minLabel is required.';
    } else {
      final problem = _salaryFieldError(minText, boundLabel: minLabel, isLpa: isLpaSalary);
      if (problem != null) {
        errors['salary_min'] = problem;
      } else {
        parsedMin = _wholeSalaryValue(minText);
      }
    }
    final maxText = _salaryMax.text.trim();
    if (maxText.isEmpty) {
      errors['salary_max'] = '$maxLabel is required.';
    } else {
      final problem = _salaryFieldError(maxText, boundLabel: maxLabel, isLpa: isLpaSalary);
      if (problem != null) {
        errors['salary_max'] = problem;
      } else {
        parsedMax = _wholeSalaryValue(maxText);
      }
    }
    if (parsedMin != null && parsedMax != null && parsedMin > parsedMax) {
      errors['salary_min'] = 'Minimum $rangeLabel must not be greater than Maximum $rangeLabel.';
    }
    // Phase 64 — mirrors the real, 3-way split confirmed by actually
    // running this project's own Django version (5.2.18) against the
    // field's exact pipeline: `openings` is a `PositiveIntegerField`,
    // whose auto-generated ModelForm field carries `min_value=0`
    // (`django.db.models.fields.PositiveIntegerField.formfield()`), so a
    // *negative* value is rejected by that field-level validator with
    // Django's own **uncustomized** `MinValueValidator` message — this
    // project's `error_messages.update({'invalid': ..., 'required': ...})`
    // (`forms.py:553-556`) never overrides `'min_value'`. A negative value
    // never reaches `clean_openings` at all. Only a value that passes the
    // `>= 0` field-level check (i.e. exactly `0`) reaches `clean_openings`
    // (`forms.py:951-958`), which adds the *different*, custom message.
    // Non-numeric/empty/whitespace-only input keeps the existing
    // `int.tryParse(...) == null` path and message, unchanged by this
    // phase (already correct, confirmed against the field's own
    // `'invalid'`/`'required'` override, both "Please enter a valid
    // numeric value.").
    final openingsValue = int.tryParse(_openings.text.trim());
    if (openingsValue == null) {
      errors['openings'] = 'Please enter a valid numeric value.';
    } else if (openingsValue < 0) {
      errors['openings'] = 'Ensure this value is greater than or equal to 0.';
    } else if (openingsValue < 1) {
      errors['openings'] = 'Openings must be 1 or greater.';
    }
    if (_status.isEmpty) errors['status'] = 'This field is required.';
    if (_isIt && _workEnvironment.isEmpty) {
      errors['work_environment'] = 'This field is required.';
    }
    if (_isIt && _interviewMode.isEmpty) {
      errors['interview_mode'] = 'This field is required.';
    }
    if ((_isIt || _isNonItTech) && _noticePeriod.isEmpty) {
      errors['notice_period'] = 'This field is required.';
    }
    if (_isIt && _genderPreference.isEmpty) {
      errors['gender_preference'] = 'This field is required.';
    }
    if (_isNonIt && _workMode.isEmpty) {
      errors['work_mode'] = 'Select a work mode.';
    }
    if (_isNonIt && _employmentType.isEmpty) {
      errors['employment_type'] = 'Select an employment type.';
    }
    if (_isNonItNonTech && _joiningRequirement.isEmpty) {
      errors['joining_requirement'] = 'Select a joining requirement.';
    }
    if (_isNonIt && _educationPreset.isEmpty) {
      errors['education'] = 'Qualification is required.';
    }
    // Phase 54 — `education_other`'s own requiredness/validation is not
    // category-specific at all: `forms.py`'s `clean()` runs this block
    // whenever `education == 'custom'`, for IT and both NON-IT sheets
    // alike (`forms.py:910-918`), so it is checked unconditionally here too.
    if (_educationPreset == 'custom') {
      final text = _normaliseEducationText(_educationOther.text);
      if (text.isEmpty) {
        errors['education_other'] = 'Enter the educational qualification.';
      } else {
        final problem = _educationTextError(text);
        if (problem != null) errors['education_other'] = problem;
      }
    }
    // Phase 58 — `application_contact` is in `NON_IT_FIELDS`'s `required`
    // list for *both* Non-IT sheets (`forms.py:276-307`), never checked for
    // IT at all (the field is hidden there — `_isNonIt`-gated widget,
    // unchanged this phase). The missing-value message is `forms.py`'s own
    // sheet-required wording (`f'{label} is required.'` with `label =
    // 'Application Contact'`), distinct from the format-error message
    // below — the 2 are never shown at once, mirroring the real source's
    // own precedence (a non-empty-but-invalid value never also triggers
    // the "is required" sheet check, since `clean_application_contact`
    // already recorded an error for that field first).
    if (_isNonIt) {
      final contactValue = _normaliseApplicationContact(_applicationContact.text);
      if (contactValue.isEmpty) {
        errors['application_contact'] = 'Application Contact is required.';
      } else {
        final contactError = _applicationContactError(contactValue);
        if (contactError != null) errors['application_contact'] = contactError;
      }
    }
    // Phase 59 — `age_limit` is optional on *both* Non-IT sheets
    // (`forms.py:276-307`'s `'optional'` lists) and blanked for IT
    // (`NON_IT_ALL_FIELDS`); unlike `application_contact` there is no
    // "is required" branch to add here at all — a blank value is always
    // acceptable, so only a non-empty, malformed value is ever an error.
    if (_isNonIt) {
      final ageLimitError = _ageLimitError(_normaliseAgeLimit(_ageLimit.text));
      if (ageLimitError != null) errors['age_limit'] = ageLimitError;
    }
    // Phase 60 — the remaining `NON_IT_FIELDS` sheet-required text fields
    // (`forms.py:276-307`'s sheet-required loop, `forms.py:822-828`) that
    // Phases 52-59 had not yet covered. Every message below is the exact
    // `f'{label} is required.'` wording the server itself uses, with the
    // sheet's own label text; whitespace-only counts as empty, matching
    // the server's own `(cleaned.get(name) or '').strip()` before its
    // `if not value` check.
    // Phase 61 — each field below is also in `TEXT_FIELD_RULES`
    // (`forms.py:104-124`), validated via `_clean_text_field`/
    // `text_field_error`, which runs as that field's own `clean_<name>`
    // *before* `clean()`'s sheet-required loop (Phase 60) ever sees it —
    // so a non-empty-but-invalid value only ever shows the character-rule
    // message, never also "is required." (the server's own
    // `name not in self.errors` guard), mirrored here by checking
    // required-when-empty vs. character-rule-when-non-empty as mutually
    // exclusive branches, gated by each field's own visibility condition
    // (not just its requiredness condition, since the character rule
    // applies to any non-empty value regardless of whether it happens to
    // be required in that classification — see `industry_experience`
    // below).
    if (_isNonIt) {
      final text = _normaliseFreeText(_industrySector.text);
      if (text.isEmpty) {
        errors['industry_sector'] = 'Industry / Sector is required.';
      } else {
        final problem = _textFieldError(
          text,
          allowedChars: _industrySectorCharsRe,
          minLetters: 2,
          noLongDigits: true,
          message: _industrySectorMessage,
        );
        if (problem != null) errors['industry_sector'] = problem;
      }
    }
    if (_isNonIt && _responsibilities.text.trim().isEmpty) {
      errors['responsibilities'] = 'Job Responsibilities is required.';
    }
    if (_isNonIt && _workingHours.text.trim().isEmpty) {
      errors['working_hours'] = 'Working Hours / Shift is required.';
    }
    if (_isNonIt) {
      final text = _normaliseFreeText(_keywords.text);
      if (text.isEmpty) {
        errors['keywords'] = 'Key Skills / Keywords is required.';
      } else {
        final problem = _textFieldError(
          text,
          allowedChars: _keywordsCharsRe,
          minLetters: 2,
          noLongDigits: false,
          message: _keywordsMessage,
        );
        if (problem != null) errors['keywords'] = problem;
      }
    }
    // `industry_experience` is shown (and its character rule applies) on
    // *both* NON-IT sheets, but is required for NON-IT×Technical only —
    // NON-IT×Non-Technical's own sheet lists it under `'optional'` instead
    // (`forms.py:303`).
    if (_isNonIt) {
      final text = _normaliseFreeText(_industryExperience.text);
      if (text.isEmpty) {
        if (_isNonItTech) errors['industry_experience'] = 'Industry Experience is required.';
      } else {
        final problem = _textFieldError(
          text,
          allowedChars: _industryExperienceCharsRe,
          minLetters: 2,
          noLongDigits: false,
          message: _industryExperienceMessage,
        );
        if (problem != null) errors['industry_experience'] = problem;
      }
    }
    // `department_function`/`functional_skills` are NON-IT×Non-Technical's
    // own fields — neither is shown, required, or character-rule-checked
    // for Technical at all (`forms.py:276-290`), matching their existing
    // `_isNonItNonTech`-gated widgets.
    if (_isNonItNonTech) {
      final text = _normaliseFreeText(_departmentFunction.text);
      if (text.isEmpty) {
        errors['department_function'] = 'Department / Function is required.';
      } else {
        final problem = _textFieldError(
          text,
          allowedChars: _departmentFunctionCharsRe,
          minLetters: 2,
          noLongDigits: true,
          message: _departmentFunctionMessage,
        );
        if (problem != null) errors['department_function'] = problem;
      }
    }
    if (_isNonItNonTech) {
      final text = _normaliseFreeText(_functionalSkills.text);
      if (text.isEmpty) {
        errors['functional_skills'] = 'Functional Skills is required.';
      } else {
        final problem = _textFieldError(
          text,
          allowedChars: _functionalSkillsCharsRe,
          minLetters: 2,
          noLongDigits: false,
          message: _functionalSkillsMessage,
        );
        if (problem != null) errors['functional_skills'] = problem;
      }
    }
    // Phase 65 — the remaining 5 `TEXT_FIELD_RULES` fields
    // (`forms.py:106-124`). `title`/`location` are required at the model
    // level for *every* category (`models.py`'s `title`/`location` fields
    // have no `blank=True`) — their own existing `Validators.required`-
    // backed `validator:` already shows "This field is required." for an
    // empty value, so this block only ever sets `errors['title']`/
    // `errors['location']` for a *non-empty* value, never alongside that
    // message (matching Phase 60/61's required-vs-format precedence).
    // `certifications`/`software_skills`/`language_requirements` are
    // always optional (`blank=True`, never in `NON_IT_FIELDS`'s
    // `required` list) — an empty value never produces a format error for
    // any of the 5 fields here.
    final titleText = _normaliseFreeText(_title.text);
    if (titleText.isNotEmpty) {
      final problem = _textFieldError(
        titleText,
        allowedChars: _titleCharsRe,
        minLetters: 2,
        noLongDigits: true,
        message: _titleMessage,
      );
      if (problem != null) errors['title'] = problem;
    }
    final locationText = _normaliseFreeText(_location.text);
    if (locationText.isNotEmpty) {
      final problem = _textFieldError(
        locationText,
        allowedChars: _locationCharsRe,
        minLetters: 2,
        noLongDigits: false,
        message: _locationMessage,
      );
      if (problem != null) errors['location'] = problem;
    }
    // `certifications` is shown (and its format rule applies) on *both*
    // NON-IT sheets, same gate as its existing widget.
    if (_isNonIt) {
      final certificationsText = _normaliseFreeText(_certifications.text);
      if (certificationsText.isNotEmpty) {
        final problem = _textFieldError(
          certificationsText,
          allowedChars: _certificationsCharsRe,
          minLetters: 2,
          noLongDigits: false,
          message: _certificationsMessage,
        );
        if (problem != null) errors['certifications'] = problem;
      }
    }
    // `software_skills`/`language_requirements` are NON-IT×Non-Technical
    // only, same gate as their existing widgets.
    if (_isNonItNonTech) {
      final softwareSkillsText = _normaliseFreeText(_softwareSkills.text);
      if (softwareSkillsText.isNotEmpty) {
        final problem = _textFieldError(
          softwareSkillsText,
          allowedChars: _softwareSkillsCharsRe,
          minLetters: 2,
          noLongDigits: false,
          message: _softwareSkillsMessage,
        );
        if (problem != null) errors['software_skills'] = problem;
      }
      final languageRequirementsText = _normaliseFreeText(_languageRequirements.text);
      if (languageRequirementsText.isNotEmpty) {
        final problem = _textFieldError(
          languageRequirementsText,
          allowedChars: _languageRequirementsCharsRe,
          minLetters: 2,
          noLongDigits: false,
          message: _languageRequirementsMessage,
        );
        if (problem != null) errors['language_requirements'] = problem;
      }
    }
    return errors;
  }

  static const int _experienceYearsMax99 = 99;

  /// Phase 55 — mirrors `experience_years`'/`experience_years_max`'s own
  /// field-level `error_messages` overrides (`forms.py`: `'invalid'`,
  /// `'min_value'`) plus `clean_experience_years`/`clean_experience_years_max`'s
  /// `> EXPERIENCE_YEARS_MAX` check, in that order. [invalidMessage] is the
  /// one piece that differs between the 2 fields' own `'invalid'` wording;
  /// every other message is identical for either field in the real source.
  /// Returns `null` when [text] is an acceptable whole number of years.
  static String? _experienceYearsError(String text, String invalidMessage) {
    final years = int.tryParse(text);
    if (years == null) return invalidMessage;
    if (years < 0) return 'Experience years cannot be negative.';
    if (years > _experienceYearsMax99) {
      return 'Experience years must not exceed $_experienceYearsMax99 (2 digits).';
    }
    return null;
  }

  /// Phase 61 — mirrors `text_field_error`'s own whitespace normalisation
  /// (`jobs_app/forms.py`: `re.sub(r'\s+', ' ', value or '').strip()`)
  /// exactly: collapses whitespace runs to a single space and trims. Used
  /// by every `TEXT_FIELD_RULES` field this phase validates; also the
  /// exact value sent on submit for each (see `_submit`), matching
  /// `_clean_text_field`'s own return value.
  static String _normaliseFreeText(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Phase 61 — mirrors `text_field_error` (`jobs_app/forms.py`) exactly,
  /// for a single `TEXT_FIELD_RULES` field: [normalisedText] must match
  /// [allowedChars] in full, contain at least [minLetters] letters, and
  /// (when [noLongDigits] is true) contain no standalone run of 3+ digits.
  /// All 3 failure modes share the one [message] — the real source never
  /// distinguishes which rule failed, unlike `age_limit`/
  /// `contract_duration_months`. [normalisedText] should already be
  /// whitespace-normalised (see `_normaliseFreeText`) — an empty value is
  /// never checked here, since the server itself only runs this check on
  /// a non-empty value (`if not text: return ''`); emptiness is instead
  /// this screen's own existing Phase 60 "is required" branch.
  static String? _textFieldError(
    String normalisedText, {
    required RegExp allowedChars,
    required int minLetters,
    required bool noLongDigits,
    required String message,
  }) {
    if (!allowedChars.hasMatch(normalisedText)) return message;
    if (RegExp(r'[A-Za-z]').allMatches(normalisedText).length < minLetters) return message;
    if (noLongDigits && RegExp(r'\d{3,}').hasMatch(normalisedText)) return message;
    return null;
  }

  /// Phase 61 — mirrors `TEXT_FIELD_RULES['industry_sector']`
  /// (`jobs_app/forms.py`) exactly.
  static final RegExp _industrySectorCharsRe = RegExp(r"^[A-Za-z0-9 .,&/()'\-]+$");
  static const String _industrySectorMessage =
      'Industry / Sector should contain a valid industry name and should not contain only numbers or special characters.';

  /// Phase 61 — mirrors `TEXT_FIELD_RULES['industry_experience']` exactly
  /// (the one field among these 5 that also allows `+`, and does not set
  /// `no_long_digits`).
  static final RegExp _industryExperienceCharsRe = RegExp(r"^[A-Za-z0-9 .,&/()'\-+]+$");
  static const String _industryExperienceMessage =
      'Industry Experience should describe the relevant experience and should not contain only numbers or special characters.';

  /// Phase 61 — mirrors `TEXT_FIELD_RULES['department_function']` exactly.
  static final RegExp _departmentFunctionCharsRe = RegExp(r"^[A-Za-z0-9 .,&/()'\-]+$");
  static const String _departmentFunctionMessage =
      'Department / Function should contain a valid name and should not contain only numbers or special characters.';

  /// Phase 61 — mirrors `TEXT_FIELD_RULES['functional_skills']` exactly
  /// (allows `+#`, no `no_long_digits`).
  static final RegExp _functionalSkillsCharsRe = RegExp(r"^[A-Za-z0-9 .,&/()'\-+#]+$");
  static const String _functionalSkillsMessage =
      'Functional Skills should contain valid skill names and should not contain only numbers or special characters.';

  /// Phase 61 — mirrors `TEXT_FIELD_RULES['keywords']` exactly (allows
  /// `+#`, no `no_long_digits`).
  static final RegExp _keywordsCharsRe = RegExp(r"^[A-Za-z0-9 .,&/()'\-+#]+$");
  static const String _keywordsMessage =
      'Key Skills / Keywords should contain valid keywords and should not contain only numbers or special characters.';

  /// Phase 65 — mirrors `TEXT_FIELD_RULES['title']` exactly (allows `+#`,
  /// and — like `industry_sector`/`department_function` — sets
  /// `no_long_digits`).
  static final RegExp _titleCharsRe = RegExp(r"^[A-Za-z0-9 .,&/()'\-+#]+$");
  static const String _titleMessage =
      'Job Title should contain a valid job title and should not contain only numbers or special characters.';

  /// Phase 65 — mirrors `TEXT_FIELD_RULES['location']` exactly (no `+`/`#`,
  /// no `no_long_digits`).
  static final RegExp _locationCharsRe = RegExp(r"^[A-Za-z0-9 .,&/()'\-]+$");
  static const String _locationMessage =
      'Location should contain a valid place name (e.g. Hyderabad, Telangana) and should not contain only numbers or special characters.';

  /// Phase 65 — mirrors `TEXT_FIELD_RULES['certifications']` exactly
  /// (allows `+`, not `#`, no `no_long_digits`).
  static final RegExp _certificationsCharsRe = RegExp(r"^[A-Za-z0-9 .,&/()'\-+]+$");
  static const String _certificationsMessage =
      'Required Certifications should contain valid certification names and should not contain only numbers or special characters.';

  /// Phase 65 — mirrors `TEXT_FIELD_RULES['software_skills']` exactly
  /// (allows `+#`, no `no_long_digits`).
  static final RegExp _softwareSkillsCharsRe = RegExp(r"^[A-Za-z0-9 .,&/()'\-+#]+$");
  static const String _softwareSkillsMessage =
      'Software / MS Office Skills should contain valid software names and should not contain only numbers or special characters.';

  /// Phase 65 — mirrors `TEXT_FIELD_RULES['language_requirements']`
  /// exactly: the only field among all 10 `TEXT_FIELD_RULES` entries whose
  /// `chars` excludes `0-9` entirely — digits are never allowed, not even
  /// as part of a longer word.
  static final RegExp _languageRequirementsCharsRe = RegExp(r"^[A-Za-z .,&/()'\-]+$");
  static const String _languageRequirementsMessage = 'Language Requirements should contain language names only.';

  /// Phase 59 — mirrors `AGE_LIMIT_RE`/`AGE_LIMIT_MESSAGE` (`jobs_app/forms.py`)
  /// exactly: 1-2 digits, an optional `-` range (also 1-2 digits, whitespace
  /// around the dash allowed), and an optional trailing `+` regardless of
  /// whether a range was given — so `25`, `25+`, `25-35`, and `25-35+` are
  /// all accepted, matching `job_form.html`'s own client-side mirror of this
  /// same regex (`AGE_LIMIT_RE`/`AGE_LIMIT_MESSAGE` there too). A single
  /// message covers every failure mode — there is no separate "too low"/
  /// "decimal"/"non-numeric" wording in the real source, unlike
  /// `contract_duration_months`'s 5 distinct messages.
  /// Phase 63 — mirrors `_clean_salary_range` (`jobs_app/forms.py`) exactly,
  /// for one already-non-empty salary field. [boundLabel] is the exact
  /// `f'{bound} {rules["label"]}'` the server computes (e.g. `"Minimum
  /// Salary"`/`"Minimum LPA"`). [isLpa] selects `SALARY_RULES['lpa']`
  /// (min 1, max 99) vs. `SALARY_RULES['monthly']` (min 1000, max 999999)
  /// — both `'integer': True`. Checked in the server's own order: numeric
  /// shape (covers Django's field-level `'invalid'`, including more than 2
  /// decimal places, which the server's own `'max_decimal_places'`
  /// override reuses the same `'invalid'` message for), then whole-number,
  /// then the floor, then the ceiling (`SALARY_RULES`'s fixed
  /// `ceiling_message`, which — unlike every other message here — carries
  /// no "Minimum"/"Maximum" prefix at all, the same text regardless of
  /// which field triggered it). Returns `null` for an acceptable value.
  static String? _salaryFieldError(String trimmedText, {required String boundLabel, required bool isLpa}) {
    final match = RegExp(r'^-?\d+(\.(\d+))?$').firstMatch(trimmedText);
    if (match == null) {
      return 'Enter a valid numeric value for $boundLabel.';
    }
    final fractional = match.group(2);
    if (fractional != null && fractional.length > 2) {
      return 'Enter a valid numeric value for $boundLabel.';
    }
    if (fractional != null && fractional.contains(RegExp(r'[1-9]'))) {
      return '$boundLabel must be a whole number (no decimals).';
    }
    final value = _wholeSalaryValue(trimmedText);
    if (isLpa) {
      if (value < 1) return '$boundLabel must be at least 1 LPA.';
      if (value > 99) return 'LPA must not exceed 99 LPA (2 digits).';
    } else {
      if (value < 1000) return '$boundLabel must be at least ₹1,000 per month.';
      if (value > 999999) return 'Salary must not exceed ₹9,99,999 per month (6 digits).';
    }
    return null;
  }

  /// Phase 63 — the integer part of a salary string already confirmed
  /// whole-number-shaped by [_salaryFieldError] (or about to be, by a
  /// caller that has otherwise verified the same regex) — safe to call
  /// only after that check has passed.
  static int _wholeSalaryValue(String trimmedText) => int.parse(trimmedText.split('.').first);

  static final RegExp _ageLimitRe = RegExp(r'^(\d{1,2})(?:\s*-\s*(\d{1,2}))?\+?$');
  static const String _ageLimitMessage = 'Please enter a valid numeric age limit, e.g. 25 or 25-35.';

  /// Phase 59 — mirrors `clean_age_limit` exactly: blank is always valid
  /// (the field is optional on both NON-IT sheets, never required); the low
  /// end must be `>= 1`; when a high end is given, it must also be `>= 1`
  /// and `>= ` the low end. [text] should already be trimmed (see
  /// `_normaliseAgeLimit`). Returns `null` for an acceptable value.
  static String? _ageLimitError(String text) {
    if (text.isEmpty) return null;
    final match = _ageLimitRe.firstMatch(text);
    if (match == null) return _ageLimitMessage;
    final low = int.parse(match.group(1)!);
    final highText = match.group(2);
    if (low < 1) return _ageLimitMessage;
    if (highText != null) {
      final high = int.parse(highText);
      if (high < 1 || high < low) return _ageLimitMessage;
    }
    return null;
  }

  /// Phase 59 — mirrors `clean_age_limit`'s own `.strip()` plus its
  /// `re.sub(r'\s*-\s*', '-', value)` (narrower than `education`'s/
  /// `application_contact`'s general whitespace-collapse: `AGE_LIMIT_RE`
  /// only ever allows whitespace immediately around the dash, nowhere else
  /// in an acceptable value, so this is the exact equivalent). Also the
  /// exact value sent as `age_limit` on submit (see `_submit`).
  static String _normaliseAgeLimit(String text) => text.trim().replaceAll(RegExp(r'\s*-\s*'), '-');

  /// Phase 58 — mirrors `CONTACT_MESSAGE` (`jobs_app/forms.py`) exactly.
  static const String _applicationContactMessage =
      'Application Contact should be a valid email address, phone number or contact name.';

  /// Phase 58 — a reasonably strict "looks like an email" check, standing
  /// in for Django's `validate_email` (an RFC 5322-ish validator this
  /// project doesn't attempt to reproduce bit-for-bit — the same level of
  /// fidelity already used by `Validators.email`'s own regex elsewhere in
  /// this app, not a new, less-strict rule invented for this field).
  static final RegExp _emailLikeRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Phase 58 — mirrors `PHONE_PART_RE` (`jobs_app/forms.py`) exactly:
  /// an optional leading `+`, then 7-20 characters of digits/spaces/
  /// `(`/`)`/`.`/`-`.
  static final RegExp _phonePartRe = RegExp(r'^\+?[\d\s().-]{7,20}$');

  /// Phase 58 — mirrors `CONTACT_NAME_RE` (`jobs_app/forms.py`) exactly:
  /// letters, spaces, `.`, `'`, `-` only.
  static final RegExp _contactNameRe = RegExp(r"^[A-Za-z .'-]+$");

  /// Phase 58 — mirrors `contact_part_error` (`jobs_app/forms.py`) exactly,
  /// for one already-split, not-yet-trimmed piece of `application_contact`:
  /// a valid email (checked first, whenever `@` is present), **or** a
  /// phone-shaped string whose digit count is 7-15, **or** a plain name
  /// (letters/spaces/`.`/`'`/`-` only, at least 2 letters). Returns `null`
  /// for an acceptable (or blank) part, [_applicationContactMessage]
  /// otherwise — deliberately not phone-only or email-only, matching the
  /// real source's own 3-way rule.
  static String? _contactPartError(String part) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains('@')) {
      return _emailLikeRe.hasMatch(trimmed) ? null : _applicationContactMessage;
    }
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isNotEmpty && _phonePartRe.hasMatch(trimmed)) {
      return (digits.length >= 7 && digits.length <= 15) ? null : _applicationContactMessage;
    }
    if (_contactNameRe.hasMatch(trimmed) && RegExp(r'[A-Za-z]').allMatches(trimmed).length >= 2) {
      return null;
    }
    return _applicationContactMessage;
  }

  /// Phase 58 — mirrors `JobPostingForm.clean_application_contact` exactly:
  /// splits [normalisedValue] (already whitespace-collapsed/trimmed — see
  /// `_normaliseApplicationContact`) on `,`/`/`/`|`/`;`, and every
  /// non-blank part must independently pass [_contactPartError], or the
  /// whole field is rejected with one message. Returns `null` for an
  /// acceptable value; [normalisedValue] itself is never empty here —
  /// emptiness is handled separately by the Non-IT requiredness check in
  /// `_localRequiredErrors`, exactly like the real source's own 2-stage
  /// (field-level then sheet-level) validation.
  static String? _applicationContactError(String normalisedValue) {
    final parts = normalisedValue.split(RegExp(r'[,/|;]')).where((p) => p.trim().isNotEmpty).toList();
    if (parts.isEmpty || parts.any((p) => _contactPartError(p) != null)) {
      return _applicationContactMessage;
    }
    return null;
  }

  /// Phase 58 — mirrors `clean_application_contact`'s own
  /// `re.sub(r'\s+', ' ', value).strip()`: collapses whitespace runs to a
  /// single space and trims. Also the exact value sent as
  /// `application_contact` on submit (see `_submit`).
  static String _normaliseApplicationContact(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Phase 54 — mirrors `JobPostingForm.normalise_education_text`
  /// (`jobs_app/forms.py`) exactly: collapses whitespace runs to a single
  /// space and trims. Also the exact value sent as `education_other` on
  /// submit (see `_submit`), matching what the server itself stores back
  /// into `cleaned_data` after validation.
  static String _normaliseEducationText(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

  static const int _educationMaxLen = 60;
  static final RegExp _educationAllowedCharsRe = RegExp(r"^[A-Za-z0-9 ./,()&+'\-]+$");

  /// Phase 54 — mirrors `JobPostingForm.education_text_error`
  /// (`jobs_app/forms.py`) exactly, including its exact wording, for text
  /// already run through [_normaliseEducationText]. Returns `null` when the
  /// text is acceptable.
  static String? _educationTextError(String text) {
    if (text.length > _educationMaxLen) {
      return 'Education must be $_educationMaxLen characters or fewer.';
    }
    if (!_educationAllowedCharsRe.hasMatch(text)) {
      return "Education can contain only letters, numbers, spaces and . / - , ( ) & + '";
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(text)) {
      return 'Education must include letters, for example 10th, B.Tech or Diploma.';
    }
    // A digit run not directly followed by a letter is a standalone number.
    final digitCount = RegExp(r'\d').allMatches(text).length;
    if (RegExp(r'\d{3,}').hasMatch(text) ||
        RegExp(r'\d+(?![A-Za-z\d])').hasMatch(text) ||
        digitCount > 4) {
      return 'Numbers are allowed only as part of a qualification, such as 10th or 12th.';
    }
    return null;
  }

  Future<void> _submit() async {
    // Phase 65 — `title`/`location`/`description`'s own `validator`s fold
    // `_fieldErrors[key]` in (`Validators.required(v) ?? _fieldErrors[key]`).
    // Without clearing it first, a *stale* entry left over from a previous
    // failed attempt (local or server) would make `Form.validate()` below
    // report that field invalid again even after the user corrected it —
    // `_fieldErrors` is otherwise only ever reset on this method's own
    // *success* path, which this stale value would make unreachable in the
    // first place (a real catch-22, newly exposed now that `title`/
    // `location` can fail locally, not only via a server round trip).
    _fieldErrors = {};
    // Both checks always run (not short-circuited) so a single tap surfaces
    // every problem at once — `Form.validate()` itself paints each
    // `AppTextField`'s own built-in error text as a side effect, and
    // `_localRequiredErrors()` covers the select/radio fields `Form`
    // doesn't know about — matching the real page's own "highlight
    // everything that's wrong" submit behavior rather than revealing one
    // error at a time across repeated taps.
    final formValid = _formKey.currentState!.validate();
    final localErrors = _localRequiredErrors();
    if (!formValid || localErrors.isNotEmpty) {
      setState(() {
        _fieldErrors = localErrors;
        _generalError = 'Please check the highlighted fields.';
      });
      // Phase 65 — same reasoning as the server-failure branch below:
      // `title`/`location`/`description` fold their error into their own
      // `validator`, which only re-evaluates on an explicit `validate()`
      // call, not just because the surrounding widget rebuilt. Without
      // this, a `title`/`location` character-rule message set just above
      // (`_localRequiredErrors()`, Phase 65) would never actually render —
      // `_fieldErrors` would hold it, but `Form.validate()` already ran
      // (with the *previous* `_fieldErrors`) before this method populated
      // it with the current one.
      _formKey.currentState?.validate();
      return;
    }

    setState(() {
      _submitting = true;
      _generalError = null;
      _fieldErrors = {};
    });

    final submission = JobPostingSubmission(
      jobCategory: _jobCategory,
      jobClassification: _jobClassification,
      department: _department,
      departmentFunction: _normaliseFreeText(_departmentFunction.text),
      designation: _designation,
      industrySector: _normaliseFreeText(_industrySector.text),
      title: _normaliseFreeText(_title.text),
      jobType: _jobType,
      // Phase 57 — the controller is already cleared the moment the field
      // stops being relevant (the dropdown handlers above, and
      // `_onCategoryChanged`), but this submit-time check reproduces the
      // server's own unconditional discard too (`cleaned['contract_
      // duration_months'] = None` whenever `job_type != 'contract'` —
      // `forms.py`'s `clean()`), so a stale value can never reach the
      // payload through any path.
      contractDurationMonths: _isContract ? _contractDurationMonths.text.trim() : '',
      employmentType: _employmentType,
      experiencePreset: _experiencePreset,
      experienceYears: _experiencePreset == 'custom'
          ? _experienceYearsTyped.text.trim()
          : '',
      // Phase 55 — both discarded for any preset, matching `forms.py`'s
      // `clean()` ("discarded with any preset option"). Within `'custom'`,
      // `experience_plus` is force-cleared whenever a maximum is present
      // (`cleaned['experience_plus'] = False` — `forms.py`'s `clean()`,
      // the "elif years_max is not None" branch) — reproduced here as a
      // submit-time backstop even though `_experienceYearsMax`'s own field
      // is already hidden while `_experiencePlus` is checked, and vice
      // versa, so the 2 can never both be populated through the UI itself.
      experiencePlus: _experiencePreset == 'custom' &&
          _experienceYearsMax.text.trim().isEmpty &&
          _experiencePlus,
      experienceYearsMax: _experiencePreset == 'custom'
          ? _experienceYearsMax.text.trim()
          : '',
      location: _normaliseFreeText(_location.text),
      educationPreset: _educationPreset,
      educationOther: _educationPreset == 'custom'
          ? _normaliseEducationText(_educationOther.text)
          : '',
      functionalSkills: _normaliseFreeText(_functionalSkills.text),
      industryExperience: _normaliseFreeText(_industryExperience.text),
      workingHours: _workingHours.text.trim(),
      salaryFormat: _salaryFormat,
      salaryMin: _salaryMin.text.trim(),
      salaryMax: _salaryMax.text.trim(),
      openings: int.tryParse(_openings.text.trim()) ?? 1,
      perks: _perks.toList(),
      description: _description.text.trim(),
      requirements: _requirements.text.trim(),
      responsibilities: _responsibilities.text.trim(),
      certifications: _normaliseFreeText(_certifications.text),
      softwareSkills: _normaliseFreeText(_softwareSkills.text),
      languageRequirements: _normaliseFreeText(_languageRequirements.text),
      keywords: _normaliseFreeText(_keywords.text),
      applicationContact: _normaliseApplicationContact(_applicationContact.text),
      skills: _isNonItNonTech ? const [] : _selectedSkills.toList(),
      mandatorySkills: _isNonItNonTech ? const [] : _mandatorySkills.toList(),
      deadline: _deadline == null
          ? ''
          : '${_deadline!.year.toString().padLeft(4, '0')}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}',
      status: _status,
      workEnvironment: _workEnvironment,
      interviewMode: _interviewMode,
      interviewModeOther: _interviewMode == 'others'
          ? _interviewModeOther.text.trim()
          : '',
      workMode: _workMode,
      joiningRequirement: _joiningRequirement,
      noticePeriod: _noticePeriod,
      noticePeriodOther: _noticePeriod == 'others'
          ? _noticePeriodOther.text.trim()
          : '',
      genderPreference: _genderPreference,
      ageLimit: _normaliseAgeLimit(_ageLimit.text),
    );

    final repo = ref.read(jobPostingRepositoryProvider);
    final result = _isEdit ? await repo.submitEdit(widget.jobId!, submission) : await repo.submit(submission);
    if (!mounted) return;

    switch (result) {
      case Success():
        ref.invalidate(jobOpeningsControllerProvider);
        ref.invalidate(employerDashboardControllerProvider);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(_isEdit ? 'Job updated successfully!' : 'Job posted successfully!')),
          );
        // Edit is reached by a push (from the Dashboard's per-job Edit
        // button) — pop back to it, same as every other push-reached
        // employer detail screen's success path. Create is reached from the
        // nav drawer (a `go`, no screen to pop back to), so it still lands
        // on Job Openings, same as before.
        if (_isEdit) {
          context.pop();
        } else {
          context.go(RoutePaths.employerJobOpenings);
        }
      case Failed(failure: final failure):
        setState(() {
          _submitting = false;
          _generalError = failure.message;
          _fieldErrors = failure is ValidationFailure
              ? failure.fieldErrors.map(
                  (key, value) =>
                      MapEntry(key, value.isEmpty ? '' : value.first),
                )
              : {};
        });
        // Re-run every `AppTextField`'s validator now that it can see the
        // freshly-set `_fieldErrors` (title/location/description fold the
        // server error into their own `validator` — see those fields' own
        // comments) — `TextFormField` doesn't repaint a validator's error
        // text just because the surrounding widget rebuilt; it only
        // re-evaluates on an explicit `validate()`/`onChanged`.
        _formKey.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && !_hydrated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Job'), leading: drawerAwareBackLeading(context)),
        drawer: const AppNavDrawer(),
        body: const AppLoader(),
      );
    }
    if (_isEdit && _loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Job'), leading: drawerAwareBackLeading(context)),
        drawer: const AppNavDrawer(),
        body: AppErrorView(
          message: _loadError!,
          onRetry: () => setState(() {
            _hydrated = false;
            _loadError = null;
            _loadExistingJob();
          }),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Job' : 'Post New Job'),
        leading: drawerAwareBackLeading(context),
      ),
      drawer: const AppNavDrawer(),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            // `SingleChildScrollView` + `Column`, not `ListView` — confirmed
            // live on a real device: `ListView`'s default viewport
            // virtualization disposes a `FormField`'s `State` once it
            // scrolls far enough out of the cache extent, which silently
            // drops that field's error text the next time it scrolls back
            // into view (a fresh `FormFieldState` mounts with no error),
            // even though `_formKey.currentState!.validate()` did run its
            // validator correctly at tap-time. A form this size (a few
            // dozen fields, not an unbounded/huge list) has no real
            // performance reason to virtualize at all — same reasoning
            // already applied to `ProfileScreen`'s own long edit form.
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  _buildJobOverviewSection(),
                  _buildSalarySection(),
                  _buildPerksSection(),
                  _buildDescriptionAndSkillsSection(),
                  _buildTimelineSection(),
                  if (_jobCategory.isNotEmpty && !_isNonIt)
                    _buildRadioSection(
                      'Work Environment',
                      kWorkEnvironmentOptions,
                      _workEnvironment,
                      (v) => setState(() => _workEnvironment = v),
                      errorKey: 'work_environment',
                    ),
                  if (_isIt)
                    _buildRadioSection(
                      'Interview Mode',
                      kInterviewModeOptions,
                      _interviewMode,
                      (v) => setState(() => _interviewMode = v),
                      errorKey: 'interview_mode',
                      otherTriggerValue: 'others',
                      otherController: _interviewModeOther,
                    ),
                  if (_isNonIt) _buildWorkModeSection(),
                  if (_isNonItNonTech) _buildJoiningRequirementSection(),
                  if (_jobCategory.isNotEmpty && !_isNonItNonTech)
                    _buildRadioSection(
                      'Notice Period Required',
                      kNoticePeriodOptions,
                      _noticePeriod,
                      (v) => setState(() => _noticePeriod = v),
                      errorKey: 'notice_period',
                      otherTriggerValue: 'others',
                      otherController: _noticePeriodOther,
                    ),
                  _buildGenderSection(),
                  if (_generalError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _generalError!,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Save Job Posting',
                    icon: Icons.check_circle_outline,
                    isLoading: _submitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }

  Widget _buildJobOverviewSection() {
    return _section('Job Overview & Type', [
      _dropdown(
        'Job Category',
        _jobCategory,
        kJobCategoryOptions,
        _onCategoryChanged,
        errorKey: 'job_category',
      ),
      if (_isNonIt) ...[
        const SizedBox(height: AppSpacing.sm),
        _dropdown(
          'Job Classification',
          _jobClassification,
          kJobClassificationOptions,
          _onClassificationChanged,
          errorKey: 'job_classification',
        ),
      ],
      if (_isNonItTech) ...[
        const SizedBox(height: AppSpacing.sm),
        _dropdown(
          'Department',
          _department,
          kDepartmentOptions,
          _onDepartmentChanged,
          errorKey: 'department',
        ),
      ],
      if (_isNonItNonTech) ...[
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'Department / Function',
          controller: _departmentFunction,
          enabled: !_submitting,
        ),
        _fieldError('department_function'),
      ],
      if (_isNonIt) ...[
        const SizedBox(height: AppSpacing.sm),
        _dropdown(
          'Job Role / Designation (optional)',
          _designation,
          [
            for (final d in kDesignationOptions)
              if (d.$3 == _jobClassification) (d.$1, d.$2),
          ],
          (v) => setState(() => _designation = v),
          errorKey: 'designation',
          allowEmpty: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'Industry / Sector',
          controller: _industrySector,
          enabled: !_submitting,
        ),
        _fieldError('industry_sector'),
      ],
      const SizedBox(height: AppSpacing.sm),
      AppTextField(
        label: 'Job Title',
        controller: _title,
        enabled: !_submitting,
        // Folds the server's own `err_title` message into the same
        // validator FormField already uses, rather than also passing a
        // separate `errorText` — `TextFormField` would otherwise overwrite
        // a directly-set `errorText` with its validator's result (`null`,
        // once the field is non-empty) on every rebuild, silently
        // discarding a real server error the moment the field has any
        // text in it.
        validator: (v) => Validators.required(v) ?? _fieldErrors['title'],
      ),
      // Phase 52 — IT-only (`job_form.html`'s `nonit-hide` class on the
      // `job_type` select; `forms.py:878-884` only ever requires/reads
      // `job_type` directly for IT). Previously rendered unconditionally
      // with a Non-IT-relabeled title, duplicating the real, separate
      // "Employment Type" dropdown below (`kEmploymentTypeOptions`, bound
      // to `_employmentType`/`employment_type`) — an employer posting a
      // Non-IT job saw 2 differently-populated "employment type"-shaped
      // fields where the real page shows exactly 1.
      if (_isIt) ...[
        const SizedBox(height: AppSpacing.sm),
        _dropdown(
          'Job Type',
          _jobType,
          kJobTypeOptions,
          // Phase 57 — leaving Contract hides Project Duration below; clear
          // its stale value here too, exactly like the real page's
          // `toggleDuration()` (`durationInput.value = ''` the instant the
          // field becomes irrelevant), not just at submit time.
          (v) => setState(() {
            _jobType = v;
            if (v != 'contract') _contractDurationMonths.clear();
          }),
          errorKey: 'job_type',
        ),
      ],
      if (_isContract) ...[
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: _isIt
              ? 'Project Duration (months)'
              : 'Project / Contract Duration (months)',
          controller: _contractDurationMonths,
          keyboardType: TextInputType.number,
          enabled: !_submitting,
        ),
        _fieldError('contract_duration_months'),
      ],
      if (_isNonIt) ...[
        const SizedBox(height: AppSpacing.sm),
        _dropdown(
          'Employment Type',
          _employmentType,
          kEmploymentTypeOptions,
          // Phase 57 — same reasoning as the Job Type dropdown above:
          // leaving Contract via Employment Type (both NON-IT sheets share
          // this one field) must clear the stale duration too.
          (v) => setState(() {
            _employmentType = v;
            if (v != 'contract') _contractDurationMonths.clear();
          }),
          errorKey: 'employment_type',
        ),
      ],
      const SizedBox(height: AppSpacing.sm),
      _dropdown(
        'Experience Required',
        _experiencePreset,
        [...kExperiencePresets, ('custom', 'Enter manually')],
        (v) => setState(() => _experiencePreset = v),
        errorKey: 'experience',
      ),
      if (_experiencePreset == 'custom') ...[
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'Years of experience',
          controller: _experienceYearsTyped,
          keyboardType: TextInputType.number,
          enabled: !_submitting,
        ),
        // `Material(type: transparency)` — `AppCard`'s own opaque
        // background (a plain `Container`/`BoxDecoration`, not a
        // `Material`) would otherwise hide `CheckboxListTile`'s ink/ripple,
        // since `ListTile` always paints those on the nearest `Material`
        // ancestor, which sits behind this card's own decoration in paint
        // order without one of its own.
        Material(
          type: MaterialType.transparency,
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('No upper limit (e.g. "10+ years")'),
            value: _experiencePlus,
            onChanged: _submitting
                ? null
                : (v) => setState(() {
                    _experiencePlus = v ?? false;
                    // Mutually exclusive with a maximum, exactly like the
                    // real combo box, where typing "+" and typing a "-max"
                    // range can never both be active at once.
                    if (_experiencePlus) _experienceYearsMax.clear();
                  }),
          ),
        ),
        if (!_experiencePlus) ...[
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label: 'Maximum years (optional)',
            controller: _experienceYearsMax,
            keyboardType: TextInputType.number,
            enabled: !_submitting,
          ),
          _fieldError('experience_years_max'),
        ],
      ],
      const SizedBox(height: AppSpacing.sm),
      AppTextField(
        label: _isIt ? 'Location' : 'Job Location',
        controller: _location,
        enabled: !_submitting,
        validator: (v) => Validators.required(v) ?? _fieldErrors['location'],
      ),
      const SizedBox(height: AppSpacing.sm),
      _dropdown(
        _isIt ? 'Education' : 'Qualification',
        _educationPreset,
        [..._educationOptionsFor(_isNonItTech), ('custom', 'Enter manually')],
        (v) => setState(() => _educationPreset = v),
        errorKey: 'education',
        allowEmpty: true,
      ),
      if (_educationPreset == 'custom') ...[
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'Qualification',
          controller: _educationOther,
          enabled: !_submitting,
        ),
        _fieldError('education_other'),
      ],
      if (_isNonItNonTech) ...[
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'Functional Skills',
          controller: _functionalSkills,
          enabled: !_submitting,
        ),
        _fieldError('functional_skills'),
      ],
      if (_isNonIt) ...[
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'Industry Experience',
          controller: _industryExperience,
          enabled: !_submitting,
        ),
        _fieldError('industry_experience'),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'Working Hours / Shift',
          controller: _workingHours,
          enabled: !_submitting,
        ),
        _fieldError('working_hours'),
      ],
    ]);
  }

  Widget _buildSalarySection() {
    return _section(_isIt ? 'Salary & Vacancies' : 'Salary / CTC', [
      _dropdown(
        'Salary Format',
        _salaryFormat,
        kSalaryFormatOptions,
        // Phase 63 — mirrors `job_form.html`'s own `salaryFormatEl`
        // `change` handler (`applySalaryFormat(true)`): "Switching format
        // clears any entered values so monthly and LPA figures are never
        // mixed" — a stale monthly rupee figure left in place after
        // switching to LPA (or vice versa) would otherwise be compared
        // against the wrong bounds entirely.
        (v) => setState(() {
          _salaryFormat = v;
          _salaryMin.clear();
          _salaryMax.clear();
        }),
        errorKey: 'salary_format',
      ),
      const SizedBox(height: AppSpacing.sm),
      AppTextField(
        label: _salaryFormat == 'lpa'
            ? 'Minimum Salary (LPA)'
            : 'Minimum Salary (₹ per month)',
        controller: _salaryMin,
        keyboardType: TextInputType.number,
        enabled: !_submitting,
      ),
      _fieldError('salary_min'),
      const SizedBox(height: AppSpacing.sm),
      AppTextField(
        label: _salaryFormat == 'lpa'
            ? 'Maximum Salary (LPA)'
            : 'Maximum Salary (₹ per month)',
        controller: _salaryMax,
        keyboardType: TextInputType.number,
        enabled: !_submitting,
      ),
      _fieldError('salary_max'),
      const SizedBox(height: AppSpacing.sm),
      AppTextField(
        label: _isIt ? 'Total Openings' : 'Number of Vacancies',
        controller: _openings,
        keyboardType: TextInputType.number,
        enabled: !_submitting,
      ),
      _fieldError('openings'),
    ]);
  }

  Widget _buildPerksSection() {
    return _section(_isIt ? 'Additional Perks' : 'Benefits / Allowances', [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final perk in kPerksOptions)
            FilterChip(
              label: Text(perk.$2),
              selected: _perks.contains(perk.$1),
              onSelected: _submitting
                  ? null
                  : (selected) => setState(() {
                      if (selected) {
                        _perks.add(perk.$1);
                      } else {
                        _perks.remove(perk.$1);
                      }
                    }),
            ),
        ],
      ),
    ]);
  }

  Widget _buildDescriptionAndSkillsSection() {
    return _section('Description & Skills', [
      _multilineField(
        'Job Description',
        _description,
        validator: (v) => Validators.required(v) ?? _fieldErrors['description'],
      ),
      if (_isIt) ...[
        const SizedBox(height: AppSpacing.sm),
        _multilineField('Technical Requirements', _requirements),
      ],
      if (_isNonIt) ...[
        const SizedBox(height: AppSpacing.sm),
        _multilineField('Job Responsibilities', _responsibilities),
        _fieldError('responsibilities'),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'Required Certifications',
          controller: _certifications,
          enabled: !_submitting,
        ),
        _fieldError('certifications'),
      ],
      if (_isNonItNonTech) ...[
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'Software / MS Office Skills',
          controller: _softwareSkills,
          enabled: !_submitting,
        ),
        _fieldError('software_skills'),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'Language Requirements',
          controller: _languageRequirements,
          enabled: !_submitting,
        ),
        _fieldError('language_requirements'),
      ],
      if (_isNonIt) ...[
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'Key Skills / Keywords',
          controller: _keywords,
          enabled: !_submitting,
        ),
        _fieldError('keywords'),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'Application Contact',
          controller: _applicationContact,
          enabled: !_submitting,
        ),
        _fieldError('application_contact'),
      ],
      if (!_isNonItNonTech) ...[
        const SizedBox(height: AppSpacing.md),
        _buildSkillPicker(),
      ],
    ]);
  }

  Widget _buildSkillPicker() {
    final category = _currentSkillCategory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isIt ? 'Skills' : 'Technical Skills',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          _isIt
              ? 'Optional. If you select skills, mark 3–4 of them as mandatory.'
              : 'Skills follow the selected Department. Select the skills for this role, then mark 3–4 as mandatory.',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 8),
        if (category == null)
          const Text(
            'Select a Department above to see its skills.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final skill
                  in category.key == 'it'
                      ? [...category.skills, ..._customItSkills]
                      : category.skills)
                _skillChip(skill),
            ],
          ),
          if (category.key == 'it') ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Add a skill',
                    controller: _itCustomSkillInput,
                    enabled: !_submitting,
                    onSubmitted: (_) => _addCustomItSkill(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _submitting ? null : _addCustomItSkill,
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Mandatory skills marked: ${_mandatorySkills.length} of $kMandatorySkillsMin–$kMandatorySkillsMax',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          if (_skillsHint != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _skillsHint!,
                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
              ),
            ),
          if (_customSkillError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _customSkillError!,
                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
              ),
            ),
        ],
        _fieldError('skills'),
      ],
    );
  }

  /// A custom widget rather than `InputChip` — `InputChip` has no clean way
  /// to give its label area and its `avatar` two independent tap targets
  /// (`onSelected` vs. a star-specific action); confirmed live on a real
  /// device that combining `onPressed` (meant only for the star) with
  /// `onSelected` makes tapping the star toggle the whole chip's selection
  /// instead (`InputChip` treats the entire chip as one gesture region).
  /// This mirrors the real web's own approach instead
  /// (`skill-star`'s `ev.stopPropagation()` inside the `<label>`,
  /// `job_form.html`): the label area and the star button are two
  /// separate, independently-hit-testable widgets (`InkWell` + a nested
  /// `IconButton`), so Flutter's own innermost-gesture-wins hit-testing
  /// keeps them from fighting over the same tap the way `InputChip` did.
  Widget _skillChip(String skill) {
    final selected = _selectedSkills.contains(skill);
    final mandatory = _mandatorySkills.contains(skill);
    final borderColor = mandatory
        ? const Color(0xFFF59E0B)
        : (selected ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1));
    return Material(
      color: mandatory
          ? const Color(0xFFFEF3C7)
          : (selected ? const Color(0xFFDBEAFE) : Colors.white),
      shape: StadiumBorder(side: BorderSide(color: borderColor)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: _submitting ? null : () => _toggleSkill(skill, !selected),
        child: Padding(
          padding: EdgeInsets.only(
            left: 14,
            right: selected ? 4 : 14,
            top: 6,
            bottom: 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // `Flexible` + ellipsis — `Wrap` constrains each chip to at
              // most its own available cross-axis width (confirmed via
              // `RenderWrap`'s own source: `BoxConstraints(maxWidth:
              // constraints.maxWidth)` per child, not unbounded as one
              // might assume), and several real skill labels (e.g.
              // "Technical / Domain Knowledge") are wide enough to
              // overflow a bare `Text` at a normal phone width — caught by
              // this screen's own widget tests, the same class of bug
              // `ProfileScreen`'s dropdowns had before `isExpanded: true`.
              Flexible(child: Text(skill, overflow: TextOverflow.ellipsis)),
              if (selected)
                IconButton(
                  icon: Icon(
                    mandatory ? Icons.star : Icons.star_border,
                    size: 18,
                    color: mandatory ? const Color(0xFFB45309) : null,
                  ),
                  tooltip: mandatory
                      ? 'Unmark as mandatory'
                      : 'Mark as mandatory',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: _submitting ? null : () => _toggleMandatory(skill),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineSection() {
    if (!_isIt) return const SizedBox.shrink();
    return _section('Timeline & Publish', [
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(
                _deadline == null
                    ? 'Application Deadline'
                    : '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}',
              ),
              onPressed: _submitting ? null : _pickDeadline,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      _dropdown(
        'Publish Status',
        _status,
        kJobStatusOptions,
        (v) => setState(() => _status = v),
        errorKey: 'status',
      ),
    ]);
  }

  /// Phase 52 — `work_mode`'s allowed set is classification-specific
  /// (`jobs_app/forms.py`'s `WORK_MODE_OPTIONS` dict); [classification] is
  /// `_jobClassification`'s value (`'technical'`/`'non_technical'`/`''`).
  List<(String value, String label)> _workModeOptionsFor(String classification) =>
      classification == 'non_technical' ? kNonTechWorkModeOptions : kTechWorkModeOptions;

  /// Phase 54 — `education`'s allowed preset set is also not one shared
  /// list: NON-IT×Technical gets its own sheet (`kTechEducationPresets`,
  /// `TECH_EDUCATION_KEYS`); IT and NON-IT×Non-Technical share the general
  /// list instead (`kGeneralEducationPresets`) — see those constants' own
  /// doc comment in `job_posting_catalog.dart` for the exact server/web
  /// evidence. [isNonItTech] is `_isNonItTech`.
  List<(String value, String label)> _educationOptionsFor(bool isNonItTech) =>
      isNonItTech ? kTechEducationPresets : kGeneralEducationPresets;

  Widget _buildWorkModeSection() {
    return _section('Work Mode', [
      _dropdown(
        'Work Mode',
        _workMode,
        _workModeOptionsFor(_jobClassification),
        (v) => setState(() => _workMode = v),
        errorKey: 'work_mode',
      ),
    ]);
  }

  Widget _buildJoiningRequirementSection() {
    return _section('Joining Requirement', [
      _dropdown(
        'Joining Requirement',
        _joiningRequirement,
        kJoiningRequirementOptions,
        (v) => setState(() => _joiningRequirement = v),
        errorKey: 'joining_requirement',
      ),
    ]);
  }

  Widget _buildGenderSection() {
    return _section(_isIt ? 'Gender Preference' : 'Gender Requirement', [
      _buildRadioGroup(
        kGenderPreferenceOptions,
        _genderPreference,
        (v) => setState(() => _genderPreference = v),
      ),
      _fieldError('gender_preference'),
      if (_isNonIt) ...[
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'Age Limit (optional)',
          controller: _ageLimit,
          enabled: !_submitting,
        ),
        _fieldError('age_limit'),
      ],
    ]);
  }

  Widget _buildRadioSection(
    String title,
    List<(String value, String label)> options,
    String value,
    ValueChanged<String> onChanged, {
    required String errorKey,
    String? otherTriggerValue,
    TextEditingController? otherController,
  }) {
    return _section(title, [
      _buildRadioGroup(options, value, onChanged),
      _fieldError(errorKey),
      if (otherTriggerValue != null &&
          value == otherTriggerValue &&
          otherController != null) ...[
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'Please specify',
          controller: otherController,
          enabled: !_submitting,
        ),
      ],
    ]);
  }

  Widget _buildRadioGroup(
    List<(String value, String label)> options,
    String value,
    ValueChanged<String> onChanged,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option.$2),
            selected: value == option.$1,
            onSelected: _submitting ? null : (_) => onChanged(option.$1),
          ),
      ],
    );
  }

  Widget _multilineField(
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: 4,
      enabled: !_submitting,
      validator: validator,
      decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
    );
  }

  Widget _fieldError(String key) {
    final message = _fieldErrors[key];
    if (message == null || message.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title.isNotEmpty) ...[
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            ...children,
          ],
        ),
      ),
    );
  }

  /// `isExpanded: true` — same overflow fix already applied to
  /// `ProfileScreen`'s dropdowns (several option labels here are just as
  /// long, e.g. "Logistics & Industrial Workforce Skills").
  Widget _dropdown(
    String hint,
    String value,
    List<(String value, String label)> options,
    ValueChanged<String> onChanged, {
    String? errorKey,
    bool allowEmpty = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: value.isEmpty ? null : value,
          isExpanded: true,
          decoration: InputDecoration(labelText: hint, isDense: true),
          items: [
            for (final o in options)
              DropdownMenuItem(
                value: o.$1,
                child: Text(o.$2, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _submitting ? null : (v) => onChanged(v ?? ''),
        ),
        if (errorKey != null) _fieldError(errorKey),
      ],
    );
  }
}
