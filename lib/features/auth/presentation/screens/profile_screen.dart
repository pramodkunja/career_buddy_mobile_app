import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/data/country_codes.dart';
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
import '../../domain/entities/profile_data.dart';
import '../../domain/entities/student_registration_data.dart';
import '../controllers/auth_controller.dart';
import '../controllers/profile_controller.dart';
import '../providers/auth_providers.dart';
import '../widgets/employer_phone_input_field.dart';

/// `templates/users/profile.html` — "Profile Details" (Overview, read-only)
/// + "Edit Details" tabs, both served by the same `/users/profile/` URL
/// (see `ProfileRemoteDataSource`'s doc comment). Reached from the nav
/// drawer's "Profile" item.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileControllerProvider);

    ref.listen<AsyncValue<ProfileOverview>>(profileControllerProvider, (previous, next) {
      if (next.error is UnauthorizedFailure) {
        ref.read(authControllerProvider.notifier).logout();
      }
    });

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        // Matches every other drawer-linked screen — see `DashboardScreen`'s
        // doc comment for the underlying reasoning (the web's persistent
        // navbar means every page keeps full navigation, error state or
        // not).
        drawer: const AppNavDrawer(),
        appBar: AppBar(
          title: const Text('My Profile'),
          leading: drawerAwareBackLeading(context),
          bottom: const TabBar(tabs: [Tab(text: 'Profile Details'), Tab(text: 'Edit Details')]),
        ),
        body: Stack(
          children: [
            switch (state) {
              AsyncData(value: final data) => TabBarView(
                children: [
                  _OverviewTab(data: data),
                  _EditTab(data: data),
                ],
              ),
              AsyncError() => AppErrorView(
                message: 'Could not load your profile.',
                onRetry: () => ref.read(profileControllerProvider.notifier).retry(),
              ),
              _ => const AppLoader(),
            },
            const BuddyChatbotOverlay(),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.data});

  final ProfileOverview data;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  data.fullName.isEmpty ? data.username : data.fullName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text('@${data.username}', style: const TextStyle(color: Color(0xFF64748B))),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _statTile(context, 'Started', data.activitiesStarted),
                    _statTile(context, 'Done', data.completedSubs),
                    _statTile(context, 'Score', data.totalScore),
                  ],
                ),
                if (data.recentResults.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('Recent Exercise Results', style: Theme.of(context).textTheme.labelMedium),
                  for (final r in data.recentResults)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(r.title, overflow: TextOverflow.ellipsis)),
                          Text('${r.score}/${r.maxScore}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          _infoSection(context, 'Account Details', [
            MapEntry('Email Address', data.email),
            MapEntry('Username', data.username),
          ]),
          _infoSection(context, 'Personal & Contact Information', [
            MapEntry(ProfileFieldLabels.mobile, data.field(ProfileFieldLabels.mobile)),
            MapEntry(ProfileFieldLabels.alternateMobile, data.field(ProfileFieldLabels.alternateMobile)),
            MapEntry(ProfileFieldLabels.gender, data.field(ProfileFieldLabels.gender)),
            MapEntry(ProfileFieldLabels.bloodGroup, data.field(ProfileFieldLabels.bloodGroup)),
            MapEntry(ProfileFieldLabels.languagesKnown, data.field(ProfileFieldLabels.languagesKnown)),
          ]),
          _infoSection(context, 'Government Identity Documents', [
            MapEntry(ProfileFieldLabels.aadhar, data.field(ProfileFieldLabels.aadhar)),
            MapEntry(ProfileFieldLabels.pan, data.field(ProfileFieldLabels.pan)),
            MapEntry(ProfileFieldLabels.passport, data.field(ProfileFieldLabels.passport)),
          ]),
          _infoSection(context, 'Education Details', [
            MapEntry(ProfileFieldLabels.educationLevel, data.field(ProfileFieldLabels.educationLevel)),
            MapEntry(ProfileFieldLabels.passedOutYear, data.field(ProfileFieldLabels.passedOutYear)),
            MapEntry(ProfileFieldLabels.higherEducationDegree, data.field(ProfileFieldLabels.higherEducationDegree)),
            MapEntry(ProfileFieldLabels.itiDiplomaSpecialization, data.field(ProfileFieldLabels.itiDiplomaSpecialization)),
          ]),
          _infoSection(context, 'Work Experience & Skills', [
            MapEntry(ProfileFieldLabels.experienceStatus, data.field(ProfileFieldLabels.experienceStatus)),
            MapEntry(ProfileFieldLabels.companyName, data.field(ProfileFieldLabels.companyName)),
            MapEntry(ProfileFieldLabels.experienceYears, data.field(ProfileFieldLabels.experienceYears)),
            MapEntry(ProfileFieldLabels.industry, data.field(ProfileFieldLabels.industry)),
            MapEntry(ProfileFieldLabels.currentCtc, data.field(ProfileFieldLabels.currentCtc)),
            MapEntry(ProfileFieldLabels.expectedCtc, data.field(ProfileFieldLabels.expectedCtc)),
            MapEntry(ProfileFieldLabels.skills, data.field(ProfileFieldLabels.skills)),
            MapEntry(ProfileFieldLabels.certification, data.field(ProfileFieldLabels.certification)),
          ]),
          _infoSection(context, 'Location Preferences', [
            MapEntry(ProfileFieldLabels.currentLocation, data.field(ProfileFieldLabels.currentLocation)),
            MapEntry(ProfileFieldLabels.preferredLocation, data.field(ProfileFieldLabels.preferredLocation)),
          ]),
          _infoSection(context, 'Abroad Experience Details', [
            MapEntry(ProfileFieldLabels.abroadExperience, data.field(ProfileFieldLabels.abroadExperience)),
            MapEntry(ProfileFieldLabels.abroadYears, data.field(ProfileFieldLabels.abroadYears)),
            MapEntry(ProfileFieldLabels.abroadCountry, data.field(ProfileFieldLabels.abroadCountry)),
            MapEntry(ProfileFieldLabels.abroadIndustry, data.field(ProfileFieldLabels.abroadIndustry)),
            MapEntry(ProfileFieldLabels.abroadSkills, data.field(ProfileFieldLabels.abroadSkills)),
          ]),
        ],
      ),
    );
  }

  Widget _statTile(BuildContext context, String label, int value) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _infoSection(BuildContext context, String title, List<MapEntry<String, String>> items) {
    final visible = items.where((e) => e.value.trim().isNotEmpty).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.sm),
            for (final e in visible)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 150, child: Text(e.key, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13))),
                    Expanded(child: Text(e.value)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditTab extends ConsumerStatefulWidget {
  const _EditTab({required this.data});

  final ProfileOverview data;

  @override
  ConsumerState<_EditTab> createState() => _EditTabState();
}

class _EditTabState extends ConsumerState<_EditTab> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _languagesKnown;
  late final TextEditingController _itiSpec;
  late final TextEditingController _higherDegree;
  late final TextEditingController _itiSpec2;
  late final TextEditingController _higherDegree2;
  late final TextEditingController _experienceYears;
  late final TextEditingController _companyName;
  late final TextEditingController _contactPersonRole;
  late final TextEditingController _contactPersonEmail;
  late final TextEditingController _skills;
  late final TextEditingController _currentCtc;
  late final TextEditingController _expectedCtc;
  late final TextEditingController _certification;
  late final TextEditingController _currentLocation;
  late final TextEditingController _preferredLocation;
  late final TextEditingController _abroadYears;
  late final TextEditingController _abroadCountry;
  late final TextEditingController _abroadIndustry;
  late final TextEditingController _abroadSkills;
  final _aadhar = TextEditingController();
  final _pan = TextEditingController();
  final _passport = TextEditingController();

  late String _gender;
  late String _bloodGroup;
  late String _educationLevel;
  late String _educationLevel2;
  late String _industry;
  int? _passedOutYear;
  int? _passedOutYear2;
  bool? _hasExperience;
  bool? _hasAbroadExperience;
  String _mobile = '';
  String _alternateMobile = '';
  String _contactPersonMobile = '';
  PlatformFile? _resume;
  bool _submitting = false;
  String? _submitError;

  static String _valueForLabel(List<RegistrationChoiceOption> options, String label) {
    for (final o in options) {
      if (o.label == label) return o.value;
    }
    return '';
  }

  static double? _parseLeadingNumber(String value) {
    final match = RegExp(r'[\d.]+').firstMatch(value);
    return match == null ? null : double.tryParse(match.group(0)!);
  }

  static int? _parseLeadingInt(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  static String _orEmpty(String value) => value == 'Not Provided' ? '' : value;

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _firstName = TextEditingController(text: d.fullName.split(' ').firstOrNull ?? '');
    _lastName = TextEditingController(text: d.fullName.split(' ').length > 1 ? d.fullName.split(' ').skip(1).join(' ') : '');
    _email = TextEditingController(text: d.email);
    _languagesKnown = TextEditingController(text: _orEmpty(d.field(ProfileFieldLabels.languagesKnown)));
    _itiSpec = TextEditingController(text: _orEmpty(d.field(ProfileFieldLabels.itiDiplomaSpecialization)));
    _higherDegree = TextEditingController(text: _orEmpty(d.field(ProfileFieldLabels.higherEducationDegree)));
    _itiSpec2 = TextEditingController(text: _orEmpty(d.field(ProfileFieldLabels.itiDiplomaSpecialization2)));
    _higherDegree2 = TextEditingController(text: _orEmpty(d.field(ProfileFieldLabels.higherEducationDegree2)));
    _experienceYears = TextEditingController(text: _orEmpty(d.field(ProfileFieldLabels.experienceYears)).replaceAll(RegExp(r'[^\d]'), ''));
    _companyName = TextEditingController(text: _orEmpty(d.field(ProfileFieldLabels.companyName)));
    _contactPersonRole = TextEditingController(text: d.contactPersonRole);
    _contactPersonEmail = TextEditingController(text: d.contactPersonEmail);
    _skills = TextEditingController(text: _orEmpty(d.field(ProfileFieldLabels.skills)));
    _currentCtc = TextEditingController(text: _parseLeadingNumber(d.field(ProfileFieldLabels.currentCtc))?.toString() ?? '');
    _expectedCtc = TextEditingController(text: _parseLeadingNumber(d.field(ProfileFieldLabels.expectedCtc))?.toString() ?? '');
    _certification = TextEditingController(text: _orEmpty(d.field(ProfileFieldLabels.certification)));
    _currentLocation = TextEditingController(text: _orEmpty(d.field(ProfileFieldLabels.currentLocation)));
    _preferredLocation = TextEditingController(text: _orEmpty(d.field(ProfileFieldLabels.preferredLocation)));
    _abroadYears = TextEditingController(text: _parseLeadingInt(d.field(ProfileFieldLabels.abroadYears))?.toString() ?? '');
    _abroadCountry = TextEditingController(text: _orEmpty(d.field(ProfileFieldLabels.abroadCountry)));
    _abroadIndustry = TextEditingController(text: _orEmpty(d.field(ProfileFieldLabels.abroadIndustry)));
    _abroadSkills = TextEditingController(text: _orEmpty(d.field(ProfileFieldLabels.abroadSkills)));

    _gender = _valueForLabel(kGenderOptions, d.field(ProfileFieldLabels.gender));
    _bloodGroup = _orEmpty(d.field(ProfileFieldLabels.bloodGroup));
    _educationLevel = _valueForLabel(kEducationLevelOptions, d.field(ProfileFieldLabels.educationLevel));
    _educationLevel2 = _valueForLabel(kEducationLevelOptions, d.field(ProfileFieldLabels.educationLevel2));
    _industry = _valueForLabel(kIndustryOptions, d.field(ProfileFieldLabels.industry));
    _passedOutYear = _parseLeadingInt(d.field(ProfileFieldLabels.passedOutYear));
    _passedOutYear2 = _parseLeadingInt(d.field(ProfileFieldLabels.passedOutYear2));
    _hasExperience = d.field(ProfileFieldLabels.experienceStatus) == 'Experienced Candidate';
    _hasAbroadExperience = d.field(ProfileFieldLabels.abroadExperience) == 'Yes';
    // `normalizePhoneToE164`, not `_orEmpty` — see its own doc comment.
    // Without this, a save that never touches the phone fields (almost
    // every save — e.g. editing just the name) sends the raw, bare-digit
    // value some existing accounts have stored, which the server's own
    // phone validation rejects outright, failing the entire save.
    // Confirmed live against a real production account during this task.
    _mobile = normalizePhoneToE164(d.field(ProfileFieldLabels.mobile));
    _alternateMobile = normalizePhoneToE164(d.field(ProfileFieldLabels.alternateMobile));
    _contactPersonMobile = normalizePhoneToE164(d.contactPersonMobile);
  }

  @override
  void dispose() {
    for (final c in [
      _firstName, _lastName, _email, _languagesKnown, _itiSpec, _higherDegree,
      _itiSpec2, _higherDegree2, _experienceYears, _companyName,
      _contactPersonRole, _contactPersonEmail, _skills,
      _currentCtc, _expectedCtc, _certification, _currentLocation,
      _preferredLocation, _abroadYears, _abroadCountry, _abroadIndustry,
      _abroadSkills, _aadhar, _pan, _passport,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickResume() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx']);
    if (files.isNotEmpty) setState(() => _resume = files.single);
  }

  Future<void> _submit() async {
    setState(() => _submitError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final data = ProfileEditData(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      email: _email.text.trim(),
      gender: _gender,
      mobile: _mobile,
      alternateMobile: _alternateMobile,
      bloodGroup: _bloodGroup,
      languagesKnown: _languagesKnown.text.trim(),
      aadharNumber: _aadhar.text.trim(),
      panNumber: _pan.text.trim(),
      passportNumber: _passport.text.trim(),
      educationLevel: _educationLevel,
      passedOutYear: _passedOutYear,
      itiDiplomaSpecialization: _itiSpec.text.trim(),
      higherEducationDegree: _higherDegree.text.trim(),
      educationLevel2: _educationLevel2,
      passedOutYear2: _passedOutYear2,
      itiDiplomaSpecialization2: _itiSpec2.text.trim(),
      higherEducationDegree2: _higherDegree2.text.trim(),
      hasExperience: _hasExperience,
      experienceYears: int.tryParse(_experienceYears.text.trim()),
      companyName: _companyName.text.trim(),
      contactPersonRole: _contactPersonRole.text.trim(),
      contactPersonMobile: _contactPersonMobile,
      contactPersonEmail: _contactPersonEmail.text.trim(),
      industry: _industry,
      skills: _skills.text.trim(),
      currentCtc: double.tryParse(_currentCtc.text.trim()),
      expectedCtc: double.tryParse(_expectedCtc.text.trim()),
      certification: _certification.text.trim(),
      resumeFilePath: _resume?.path,
      resumeFileName: _resume?.name,
      currentLocation: _currentLocation.text.trim(),
      preferredLocation: _preferredLocation.text.trim(),
      hasAbroadExperience: _hasAbroadExperience,
      abroadYears: int.tryParse(_abroadYears.text.trim()),
      abroadCountry: _abroadCountry.text.trim(),
      abroadIndustry: _abroadIndustry.text.trim(),
      abroadSkills: _abroadSkills.text.trim(),
      // Not editable here — round-tripped from the last `getProfile()` so
      // saving doesn't fail server-side validation or wipe these out (see
      // `ProfileEditData`'s doc comments).
      englishLevel: widget.data.englishLevel,
      bio: widget.data.bio,
      additionalEducationsJson: widget.data.additionalEducationsJson,
    );

    final result = await ref.read(profileRepositoryProvider).updateProfile(data);
    if (!mounted) return;
    switch (result) {
      case Success():
        setState(() => _submitting = false);
        ref.read(profileControllerProvider.notifier).retry();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
      case Failed(failure: final failure):
        setState(() {
          _submitting = false;
          _submitError = failure.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section('Account', [
              AppTextField(label: 'First Name', controller: _firstName, enabled: !_submitting, validator: Validators.required),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Last Name', controller: _lastName, enabled: !_submitting, validator: Validators.required),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Email Address', controller: _email, enabled: !_submitting, validator: Validators.email),
            ]),
            _section('Personal', [
              _dropdown('Select Gender', _gender, kGenderOptions, (v) => setState(() => _gender = v)),
              const SizedBox(height: AppSpacing.sm),
              EmployerPhoneInputField(hint: 'Mobile Number', initialE164: _mobile, onChanged: (v) => _mobile = v),
              const SizedBox(height: AppSpacing.sm),
              EmployerPhoneInputField(hint: 'Alternate Mobile (optional)', initialE164: _alternateMobile, onChanged: (v) => _alternateMobile = v),
              const SizedBox(height: AppSpacing.sm),
              _dropdown('Select Blood Group', _bloodGroup, kBloodGroupOptions, (v) => setState(() => _bloodGroup = v)),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Languages known', controller: _languagesKnown, enabled: !_submitting),
            ]),
            _section('Identity', [
              Text(
                'Leave a field blank to keep its current value unchanged.',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.xs),
              AppTextField(label: '12-digit Aadhar Number', controller: _aadhar, keyboardType: TextInputType.number, enabled: !_submitting),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'PAN (optional)', controller: _pan, enabled: !_submitting, validator: Validators.pan),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Passport Number (optional)', controller: _passport, enabled: !_submitting, validator: Validators.passport),
            ]),
            _section('Education', [
              _dropdown('Select Highest Education', _educationLevel, kEducationLevelOptions, (v) => setState(() => _educationLevel = v)),
              const SizedBox(height: AppSpacing.sm),
              _yearDropdown('Passing out year', _passedOutYear, (v) => setState(() => _passedOutYear = v)),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'ITI / Diploma specialization', controller: _itiSpec, enabled: !_submitting),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Degree', controller: _higherDegree, enabled: !_submitting),
            ]),
            _section('Additional Education (optional)', [
              _dropdown('Select Additional Education', _educationLevel2, kEducationLevelOptions, (v) => setState(() => _educationLevel2 = v)),
              const SizedBox(height: AppSpacing.sm),
              _yearDropdown('Additional passing out year', _passedOutYear2, (v) => setState(() => _passedOutYear2 = v)),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'ITI / Diploma specialization', controller: _itiSpec2, enabled: !_submitting),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Degree', controller: _higherDegree2, enabled: !_submitting),
            ]),
            _section('Experience & Skills', [
              _yesNoDropdown('Do you have work experience?', _hasExperience, (v) => setState(() => _hasExperience = v)),
              if (_hasExperience == true) ...[
                const SizedBox(height: AppSpacing.sm),
                AppTextField(label: 'Years of Experience', controller: _experienceYears, keyboardType: TextInputType.number, enabled: !_submitting),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(label: 'Company Name', controller: _companyName, enabled: !_submitting),
              ],
              const SizedBox(height: AppSpacing.sm),
              _dropdown('Select Industry', _industry, kIndustryOptions, (v) => setState(() => _industry = v)),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Skills', controller: _skills, enabled: !_submitting),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Current CTC (LPA)', controller: _currentCtc, keyboardType: const TextInputType.numberWithOptions(decimal: true), enabled: !_submitting),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Expected CTC (LPA)', controller: _expectedCtc, keyboardType: const TextInputType.numberWithOptions(decimal: true), enabled: !_submitting),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Certifications', controller: _certification, enabled: !_submitting),
              const SizedBox(height: AppSpacing.sm),
              _ResumePicker(fileName: _resume?.name, onPick: _submitting ? null : _pickResume),
            ]),
            _section(ProfileFieldLabels.contactPerson, [
              AppTextField(label: 'Contact Role (e.g. HR Manager, Team Lead)', controller: _contactPersonRole, enabled: !_submitting),
              const SizedBox(height: AppSpacing.sm),
              EmployerPhoneInputField(
                hint: 'Contact Mobile Number (optional)',
                initialE164: _contactPersonMobile,
                onChanged: (v) => _contactPersonMobile = v,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Contact Email ID',
                controller: _contactPersonEmail,
                enabled: !_submitting,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? null
                    : Validators.email(v, fieldName: 'Contact Email'),
              ),
            ]),
            _section('Location', [
              AppTextField(label: 'Current City, State', controller: _currentLocation, enabled: !_submitting),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Preferred City / State', controller: _preferredLocation, enabled: !_submitting),
            ]),
            _section('Abroad Experience', [
              _yesNoDropdown('Do you have abroad experience?', _hasAbroadExperience, (v) => setState(() => _hasAbroadExperience = v)),
              if (_hasAbroadExperience == true) ...[
                const SizedBox(height: AppSpacing.sm),
                AppTextField(label: 'Number of years abroad', controller: _abroadYears, keyboardType: TextInputType.number, enabled: !_submitting),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(label: 'Country', controller: _abroadCountry, enabled: !_submitting),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(label: 'Industry while abroad', controller: _abroadIndustry, enabled: !_submitting),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(label: 'Skills acquired abroad', controller: _abroadSkills, enabled: !_submitting),
              ],
            ]),
            if (_submitError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_submitError!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
            ],
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Save Changes', icon: Icons.save_outlined, isLoading: _submitting, onPressed: _submit),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
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
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: AppSpacing.sm),
            ...children,
          ],
        ),
      ),
    );
  }

  // `isExpanded: true` on every dropdown below: without it, a
  // `DropdownButtonFormField`'s internal Row sizes itself to its selected
  // item/hint text's natural (unconstrained) width instead of the space
  // actually available, overflowing — reproducibly, at a perfectly normal
  // phone width — the moment any option label is long enough (several
  // `kIndustryOptions`/`kEducationLevelOptions` entries are). `isExpanded`
  // makes it fill the available width and ellipsize instead.
  Widget _dropdown(String hint, String value, List<RegistrationChoiceOption> options, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value.isEmpty ? null : value,
      isExpanded: true,
      decoration: InputDecoration(labelText: hint, isDense: true),
      items: [
        for (final o in options) DropdownMenuItem(value: o.value, child: Text(o.label, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) => onChanged(v ?? ''),
    );
  }

  Widget _yearDropdown(String hint, int? value, ValueChanged<int?> onChanged) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: hint, isDense: true),
      items: [for (final y in passedOutYearOptions()) DropdownMenuItem(value: y, child: Text('$y'))],
      onChanged: onChanged,
    );
  }

  Widget _yesNoDropdown(String hint, bool? value, ValueChanged<bool?> onChanged) {
    return DropdownButtonFormField<bool>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: hint, isDense: true),
      items: const [
        DropdownMenuItem(value: true, child: Text('Yes')),
        DropdownMenuItem(value: false, child: Text('No')),
      ],
      onChanged: onChanged,
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _ResumePicker extends StatelessWidget {
  const _ResumePicker({required this.fileName, required this.onPick});

  final String? fileName;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.upload_file_outlined, color: Color(0xFF185ADB)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                fileName ?? 'Replace resume (optional)',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fileName == null ? const Color(0xFF64748B) : null),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
