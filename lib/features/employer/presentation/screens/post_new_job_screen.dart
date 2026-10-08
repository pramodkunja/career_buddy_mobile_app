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
    _location.text = data.location;
    _educationPreset = data.educationPreset;
    _educationOther.text = data.educationOther;
    _functionalSkills.text = data.functionalSkills;
    _industryExperience.text = data.industryExperience;
    _workingHours.text = data.workingHours;
    _salaryFormat = data.salaryFormat.isEmpty ? _salaryFormat : data.salaryFormat;
    _salaryMin.text = data.salaryMin;
    _salaryMax.text = data.salaryMax;
    _openings.text = data.openings.toString();
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

  void _onCategoryChanged(String value) {
    setState(() {
      _jobCategory = value;
      _jobClassification = '';
      _department = '';
      _selectedSkills.clear();
      _mandatorySkills.clear();
      _customItSkills.clear();
    });
  }

  void _onClassificationChanged(String value) {
    setState(() {
      _jobClassification = value;
      _department = '';
      _selectedSkills.clear();
      _mandatorySkills.clear();
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

  void _addCustomItSkill() {
    final raw = _itCustomSkillInput.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (raw.isEmpty) return;
    if (raw.contains(',')) {
      setState(
        () => _customSkillError = 'Add one skill at a time (no commas).',
      );
      return;
    }
    if (raw.length > kCustomSkillMaxLength ||
        !kCustomSkillPattern.hasMatch(raw)) {
      setState(() => _customSkillError = '"$raw" is not a valid skill name.');
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
  Map<String, String> _localRequiredErrors() {
    final errors = <String, String>{};
    if (_jobCategory.isEmpty) errors['job_category'] = 'Select a job category.';
    if (_jobType.isEmpty) errors['job_type'] = 'This field is required.';
    if (_experiencePreset.isEmpty) {
      errors['experience'] = 'This field is required.';
    } else if (_experiencePreset == 'custom' &&
        _experienceYearsTyped.text.trim().isEmpty) {
      errors['experience'] = 'Enter a whole number of years (0-99).';
    }
    if (_salaryFormat.isEmpty) {
      errors['salary_format'] = 'This field is required.';
    }
    if (_salaryMin.text.trim().isEmpty) {
      errors['salary_min'] = 'Minimum Salary is required.';
    }
    if (_salaryMax.text.trim().isEmpty) {
      errors['salary_max'] = 'Maximum Salary is required.';
    }
    if (int.tryParse(_openings.text.trim()) == null) {
      errors['openings'] = 'Please enter a valid numeric value.';
    }
    if (_status.isEmpty) errors['status'] = 'This field is required.';
    if (_workEnvironment.isEmpty) {
      errors['work_environment'] = 'This field is required.';
    }
    if (_interviewMode.isEmpty) {
      errors['interview_mode'] = 'This field is required.';
    }
    if (_noticePeriod.isEmpty) {
      errors['notice_period'] = 'This field is required.';
    }
    if (_genderPreference.isEmpty) {
      errors['gender_preference'] = 'This field is required.';
    }
    return errors;
  }

  Future<void> _submit() async {
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
      departmentFunction: _departmentFunction.text.trim(),
      designation: _designation,
      industrySector: _industrySector.text.trim(),
      title: _title.text.trim(),
      jobType: _jobType,
      contractDurationMonths: _contractDurationMonths.text.trim(),
      employmentType: _employmentType,
      experiencePreset: _experiencePreset,
      experienceYears: _experiencePreset == 'custom'
          ? _experienceYearsTyped.text.trim()
          : '',
      experiencePlus: false,
      experienceYearsMax: '',
      location: _location.text.trim(),
      educationPreset: _educationPreset,
      educationOther: _educationPreset == 'custom'
          ? _educationOther.text.trim()
          : '',
      functionalSkills: _functionalSkills.text.trim(),
      industryExperience: _industryExperience.text.trim(),
      workingHours: _workingHours.text.trim(),
      salaryFormat: _salaryFormat,
      salaryMin: _salaryMin.text.trim(),
      salaryMax: _salaryMax.text.trim(),
      openings: int.tryParse(_openings.text.trim()) ?? 1,
      perks: _perks.toList(),
      description: _description.text.trim(),
      requirements: _requirements.text.trim(),
      responsibilities: _responsibilities.text.trim(),
      certifications: _certifications.text.trim(),
      softwareSkills: _softwareSkills.text.trim(),
      languageRequirements: _languageRequirements.text.trim(),
      keywords: _keywords.text.trim(),
      applicationContact: _applicationContact.text.trim(),
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
      ageLimit: _ageLimit.text.trim(),
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
      const SizedBox(height: AppSpacing.sm),
      _dropdown(
        _isIt ? 'Job Type' : 'Employment Type (job nature)',
        _jobType,
        kJobTypeOptions,
        (v) => setState(() => _jobType = v),
        errorKey: 'job_type',
      ),
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
      if (_isNonIt) ...[
        const SizedBox(height: AppSpacing.sm),
        _dropdown(
          'Employment Type',
          _employmentType,
          kEmploymentTypeOptions,
          (v) => setState(() => _employmentType = v),
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
        [...kEducationPresets, ('custom', 'Enter manually')],
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
        (v) => setState(() => _salaryFormat = v),
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
      ],
      if (_isNonItNonTech) ...[
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'Software / MS Office Skills',
          controller: _softwareSkills,
          enabled: !_submitting,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'Language Requirements',
          controller: _languageRequirements,
          enabled: !_submitting,
        ),
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

  Widget _buildWorkModeSection() {
    return _section('Work Mode', [
      _dropdown(
        'Work Mode',
        _workMode,
        kWorkModeOptions,
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
