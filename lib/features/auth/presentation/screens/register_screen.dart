import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/validators/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../domain/entities/student_registration_data.dart';
import '../controllers/auth_controller.dart';
import '../providers/auth_providers.dart';
import '../widgets/employer_email_otp_field.dart';
import '../widgets/employer_phone_input_field.dart';

/// `templates/users/register.html` / `users/forms.py:RegisterForm` — every
/// section of the real web form, in the same order. See
/// `StudentRegistrationData`'s doc comment for the 3 pieces deliberately
/// deferred (selfie upload, the dynamic "add another education" rows beyond
/// the two fixed sets below, and per-language proficiency pairs — the plain
/// `languagesKnown` field the server itself falls back to is used instead).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Account
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password1 = TextEditingController();
  final _password2 = TextEditingController();
  bool _emailVerified = false;

  // Personal
  String _gender = '';
  String _mobile = '';
  String _alternateMobile = '';
  String _bloodGroup = '';
  final _languagesKnown = TextEditingController();

  // Identity
  final _aadhar = TextEditingController();
  final _pan = TextEditingController();
  final _passport = TextEditingController();

  // Education
  String _educationLevel = '';
  int? _passedOutYear;
  final _itiSpec = TextEditingController();
  final _higherDegree = TextEditingController();

  // Additional education
  String _educationLevel2 = '';
  int? _passedOutYear2;
  final _itiSpec2 = TextEditingController();
  final _higherDegree2 = TextEditingController();

  // Experience & skills
  bool? _hasExperience;
  final _experienceYears = TextEditingController();
  final _companyName = TextEditingController();
  final _contactRole = TextEditingController();
  String _contactMobile = '';
  final _contactEmail = TextEditingController();
  String _industry = '';
  final _skills = TextEditingController();
  final _currentCtc = TextEditingController();
  final _expectedCtc = TextEditingController();
  final _certification = TextEditingController();
  PlatformFile? _resume;

  // Location
  final _currentLocation = TextEditingController();
  final _preferredLocation = TextEditingController();

  // Abroad
  bool? _hasAbroadExperience;
  final _abroadYears = TextEditingController();
  final _abroadCountry = TextEditingController();
  final _abroadIndustry = TextEditingController();
  final _abroadSkills = TextEditingController();

  String? _submitError;

  @override
  void dispose() {
    for (final c in [
      _firstName,
      _lastName,
      _email,
      _username,
      _password1,
      _password2,
      _languagesKnown,
      _aadhar,
      _pan,
      _passport,
      _itiSpec,
      _higherDegree,
      _itiSpec2,
      _higherDegree2,
      _experienceYears,
      _companyName,
      _contactRole,
      _contactEmail,
      _skills,
      _currentCtc,
      _expectedCtc,
      _certification,
      _currentLocation,
      _preferredLocation,
      _abroadYears,
      _abroadCountry,
      _abroadIndustry,
      _abroadSkills,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickResume() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      // `accept=".pdf,.doc,.docx"` (`users/forms.py:RegisterForm.resume`).
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (files.isNotEmpty) setState(() => _resume = files.single);
  }

  Future<void> _submit() async {
    setState(() => _submitError = null);
    if (!_formKey.currentState!.validate()) return;
    if (!_emailVerified) {
      setState(
        () => _submitError =
            'Please verify your email address with the OTP before continuing.',
      );
      return;
    }
    final resume = _resume;
    if (resume?.path == null) {
      setState(
        () => _submitError =
            'Please upload your resume to complete registration.',
      );
      return;
    }

    final data = StudentRegistrationData(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      email: _email.text.trim(),
      username: _username.text.trim(),
      password: _password1.text,
      passwordConfirm: _password2.text,
      aadharNumber: _aadhar.text.trim(),
      resumeFilePath: resume!.path!,
      resumeFileName: resume.name,
      gender: _gender,
      mobile: _mobile,
      alternateMobile: _alternateMobile,
      bloodGroup: _bloodGroup,
      languagesKnown: _languagesKnown.text.trim(),
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
      contactPersonRole: _contactRole.text.trim(),
      contactPersonMobile: _contactMobile,
      contactPersonEmail: _contactEmail.text.trim(),
      industry: _industry,
      skills: _skills.text.trim(),
      currentCtc: double.tryParse(_currentCtc.text.trim()),
      expectedCtc: double.tryParse(_expectedCtc.text.trim()),
      certification: _certification.text.trim(),
      currentLocation: _currentLocation.text.trim(),
      preferredLocation: _preferredLocation.text.trim(),
      hasAbroadExperience: _hasAbroadExperience,
      abroadYears: int.tryParse(_abroadYears.text.trim()),
      abroadCountry: _abroadCountry.text.trim(),
      abroadIndustry: _abroadIndustry.text.trim(),
      abroadSkills: _abroadSkills.text.trim(),
    );

    await ref.read(authControllerProvider.notifier).register(data);
    if (!mounted) return;
    final authState = ref.read(authControllerProvider);
    if (authState is AuthUnauthenticated && authState.errorMessage != null) {
      setState(() => _submitError = authState.errorMessage);
    }
    // AuthAuthenticated is handled by the router's redirect guard (same as
    // login/employer registration) — no manual navigation needed here.
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AuthRefreshing;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _section(context, 'Account', [
                    AppTextField(
                      label: 'First Name',
                      controller: _firstName,
                      enabled: !isLoading,
                      validator: Validators.required,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Last Name',
                      controller: _lastName,
                      enabled: !isLoading,
                      validator: Validators.required,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    EmployerEmailOtpField(
                      label: 'Email Address',
                      controller: _email,
                      onVerifiedChanged: (v) =>
                          setState(() => _emailVerified = v),
                      sendOtp: (ref, email) =>
                          ref.read(authRepositoryProvider).sendOtp(email),
                      verifyOtp: (ref, {required email, required code}) => ref
                          .read(authRepositoryProvider)
                          .verifyOtp(email: email, code: code),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Choose a Username',
                      controller: _username,
                      enabled: !isLoading,
                      validator: Validators.required,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Password',
                      controller: _password1,
                      obscureText: true,
                      enabled: !isLoading,
                      validator: Validators.employerPassword,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Confirm Password',
                      controller: _password2,
                      obscureText: true,
                      enabled: !isLoading,
                      validator: (v) => Validators.confirmPassword(
                        v,
                        original: _password1.text,
                      ),
                    ),
                  ]),
                  _section(context, 'Personal', [
                    _dropdown(
                      'Select Gender',
                      _gender,
                      kGenderOptions,
                      (v) => setState(() => _gender = v),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    EmployerPhoneInputField(
                      hint: 'Mobile Number',
                      onChanged: (v) => _mobile = v,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    EmployerPhoneInputField(
                      hint: 'Alternate Mobile (optional)',
                      onChanged: (v) => _alternateMobile = v,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _dropdown(
                      'Select Blood Group',
                      _bloodGroup,
                      kBloodGroupOptions,
                      (v) => setState(() => _bloodGroup = v),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Languages known',
                      hint: 'Hindi, Telugu, Gujarati, English, others...',
                      controller: _languagesKnown,
                      enabled: !isLoading,
                    ),
                  ]),
                  _section(context, 'Identity', [
                    AppTextField(
                      label: '12-digit Aadhar Number',
                      controller: _aadhar,
                      keyboardType: TextInputType.number,
                      enabled: !isLoading,
                      validator: Validators.aadhar,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'PAN (optional)',
                      hint: 'e.g. ABCDE1234F',
                      controller: _pan,
                      enabled: !isLoading,
                      validator: Validators.pan,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Passport Number (optional)',
                      hint: 'e.g. A1234567',
                      controller: _passport,
                      enabled: !isLoading,
                      validator: Validators.passport,
                    ),
                  ]),
                  _section(context, 'Education', [
                    _dropdown(
                      'Select Highest Education',
                      _educationLevel,
                      kEducationLevelOptions,
                      (v) => setState(() => _educationLevel = v),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _yearDropdown(
                      'Passing out year',
                      _passedOutYear,
                      (v) => setState(() => _passedOutYear = v),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'ITI / Diploma specialization',
                      hint: 'e.g. Electrician, Mechanical, Civil',
                      controller: _itiSpec,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Degree',
                      hint: 'e.g. B.Tech (CSE), MBA, B.Com',
                      controller: _higherDegree,
                      enabled: !isLoading,
                    ),
                  ]),
                  _section(context, 'Additional Education (optional)', [
                    _dropdown(
                      'Select Additional Education',
                      _educationLevel2,
                      kEducationLevelOptions,
                      (v) => setState(() => _educationLevel2 = v),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _yearDropdown(
                      'Additional passing out year',
                      _passedOutYear2,
                      (v) => setState(() => _passedOutYear2 = v),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'ITI / Diploma specialization',
                      controller: _itiSpec2,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Degree',
                      hint: 'e.g. MBA, M.Tech, M.Sc, MCA',
                      controller: _higherDegree2,
                      enabled: !isLoading,
                    ),
                  ]),
                  _section(context, 'Experience & Skills', [
                    _yesNoDropdown(
                      'Do you have work experience?',
                      _hasExperience,
                      (v) => setState(() => _hasExperience = v),
                    ),
                    if (_hasExperience == true) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        label: 'Years of Experience',
                        controller: _experienceYears,
                        keyboardType: TextInputType.number,
                        enabled: !isLoading,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        label: 'Company Name',
                        hint: 'e.g. TCS, Infosys',
                        controller: _companyName,
                        enabled: !isLoading,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        label: 'Contact Role',
                        hint: 'e.g. HR Manager, Team Lead',
                        controller: _contactRole,
                        enabled: !isLoading,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      EmployerPhoneInputField(
                        hint: 'Contact Mobile Number',
                        onChanged: (v) => _contactMobile = v,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        label: 'Contact Email ID',
                        controller: _contactEmail,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !isLoading,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    _dropdown(
                      'Select Industry',
                      _industry,
                      kIndustryOptions,
                      (v) => setState(() => _industry = v),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Skills',
                      hint: 'e.g. Welding, AutoCAD, Python, MS Office',
                      controller: _skills,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Current CTC (LPA)',
                      controller: _currentCtc,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Expected CTC (LPA)',
                      controller: _expectedCtc,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Certifications',
                      hint: 'e.g. AWS Certified, NCVT, ISO Lead Auditor',
                      controller: _certification,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ResumePicker(
                      file: _resume,
                      onPick: isLoading ? null : _pickResume,
                    ),
                  ]),
                  _section(context, 'Location', [
                    AppTextField(
                      label: 'Current City, State',
                      controller: _currentLocation,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Preferred City / State',
                      controller: _preferredLocation,
                      enabled: !isLoading,
                    ),
                  ]),
                  _section(context, 'Abroad Experience', [
                    _yesNoDropdown(
                      'Do you have abroad experience?',
                      _hasAbroadExperience,
                      (v) => setState(() => _hasAbroadExperience = v),
                    ),
                    if (_hasAbroadExperience == true) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        label: 'Number of years abroad',
                        controller: _abroadYears,
                        keyboardType: TextInputType.number,
                        enabled: !isLoading,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        label: 'Country',
                        hint: 'e.g. UAE, Qatar, Singapore',
                        controller: _abroadCountry,
                        enabled: !isLoading,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        label: 'Industry while abroad',
                        controller: _abroadIndustry,
                        enabled: !isLoading,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        label: 'Skills acquired abroad',
                        controller: _abroadSkills,
                        enabled: !isLoading,
                      ),
                    ],
                  ]),
                  if (_submitError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _submitError!,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Create Account',
                    icon: Icons.person_add,
                    isLoading: isLoading,
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

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _dropdown(
    String hint,
    String value,
    List<RegistrationChoiceOption> options,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value.isEmpty ? null : value,
      decoration: InputDecoration(labelText: hint, isDense: true),
      items: [
        for (final o in options)
          DropdownMenuItem(value: o.value, child: Text(o.label)),
      ],
      onChanged: (v) => onChanged(v ?? ''),
    );
  }

  Widget _yearDropdown(String hint, int? value, ValueChanged<int?> onChanged) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: hint, isDense: true),
      items: [
        for (final y in passedOutYearOptions())
          DropdownMenuItem(value: y, child: Text('$y')),
      ],
      onChanged: onChanged,
    );
  }

  Widget _yesNoDropdown(
    String hint,
    bool? value,
    ValueChanged<bool?> onChanged,
  ) {
    return DropdownButtonFormField<bool>(
      initialValue: value,
      decoration: InputDecoration(labelText: hint, isDense: true),
      items: const [
        DropdownMenuItem(value: true, child: Text('Yes')),
        DropdownMenuItem(value: false, child: Text('No')),
      ],
      onChanged: onChanged,
    );
  }
}

class _ResumePicker extends StatelessWidget {
  const _ResumePicker({required this.file, required this.onPick});

  final PlatformFile? file;
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
                file?.name ?? 'Upload your resume (PDF, DOC, DOCX) *',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: file == null ? const Color(0xFF64748B) : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
