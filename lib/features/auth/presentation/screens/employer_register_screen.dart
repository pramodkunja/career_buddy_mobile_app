import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/validators/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_footer.dart';
import '../../../../shared/widgets/app_nav_drawer.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../domain/entities/employer_registration_data.dart';
import '../controllers/auth_controller.dart';
import '../widgets/employer_email_otp_field.dart';
import '../widgets/employer_phone_input_field.dart';

/// `templates/employer_login/signup.html` — the employer registration
/// form, reproducing every field `EmployerRegisterForm`
/// (`accounts_app/forms.py`) accepts, in the template's own rendered
/// order/grouping (4 `.reg-section` cards: Company Profile → Tax &
/// Registrations → HR/Contact Person → Account Credentials —
/// `signup.html:138-302`), not the Python class's declaration order.
class EmployerRegisterScreen extends ConsumerStatefulWidget {
  const EmployerRegisterScreen({super.key});

  @override
  ConsumerState<EmployerRegisterScreen> createState() => _EmployerRegisterScreenState();
}

class _EmployerRegisterScreenState extends ConsumerState<EmployerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _companyGstController = TextEditingController();
  final _companyPanTinController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _hrMailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _password1Controller = TextEditingController();
  final _password2Controller = TextEditingController();

  String? _industry;
  String _hrContactE164 = '';
  String? _companyLogoPath;
  bool _hrMailVerified = false;
  bool _emailVerified = false;
  bool _showOtpGateError = false;
  bool _showPhoneRequiredError = false;

  static const _sky = Color(0xFF0284C7);
  static const _skyLight = Color(0xFF0EA5E9);

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _companyGstController.dispose();
    _companyPanTinController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _hrMailController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _password1Controller.dispose();
    _password2Controller.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked != null) setState(() => _companyLogoPath = picked.path);
  }

  void _submit() {
    setState(() {
      _showOtpGateError = false;
      _showPhoneRequiredError = false;
    });
    if (!_formKey.currentState!.validate()) return;
    if (_hrContactE164.isEmpty) {
      setState(() => _showPhoneRequiredError = true);
      return;
    }
    // Mirrors `signup.html:471-479`'s submit guard: block until both
    // emails are verified, same as `accounts_app/views.py:54-64`'s
    // server-side gate.
    if (!_emailVerified || !_hrMailVerified) {
      setState(() => _showOtpGateError = true);
      return;
    }

    ref
        .read(authControllerProvider.notifier)
        .registerEmployer(
          EmployerRegistrationData(
            username: _usernameController.text.trim(),
            password: _password1Controller.text,
            passwordConfirm: _password2Controller.text,
            email: _emailController.text.trim(),
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            companyName: _companyNameController.text.trim(),
            industry: _industry ?? '',
            hrContactE164: _hrContactE164,
            hrMail: _hrMailController.text.trim(),
            companyLogoPath: _companyLogoPath,
            companyGst: _companyGstController.text.trim(),
            companyPanTin: _companyPanTinController.text.trim(),
            companyAddress: _companyAddressController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AuthRefreshing;
    final errorMessage = authState is AuthUnauthenticated ? authState.errorMessage : null;

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthAuthenticated && next.user.isEmployer) {
        context.go(RoutePaths.employerHome);
      }
    });

    return Scaffold(
      appBar: const AppTopBar(),
      drawer: const AppNavDrawer(),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(),
                          if (errorMessage != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            _ErrorAlert(message: errorMessage),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          _RegSection(
                            icon: Icons.factory_outlined,
                            title: 'Company Profile',
                            subtitle: 'Basic details about your organization',
                            children: [
                              AppTextField(
                                label: 'Company Name *',
                                hint: 'Registered Company Name',
                                controller: _companyNameController,
                                validator: (v) => Validators.required(v, fieldName: 'Company name'),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _IndustryDropdown(
                                value: _industry,
                                onChanged: (value) => setState(() => _industry = value),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _LogoPicker(path: _companyLogoPath, onPick: _pickLogo),
                              const SizedBox(height: AppSpacing.md),
                              TextFormField(
                                controller: _companyAddressController,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Company Address',
                                  hintText: 'Company Headquarters Address',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _RegSection(
                            icon: Icons.receipt_long_outlined,
                            title: 'Tax & Registrations',
                            subtitle: 'Government registration numbers',
                            children: [
                              AppTextField(
                                label: 'Company GST',
                                hint: 'e.g. 27ABCDE1234F1Z5',
                                controller: _companyGstController,
                                validator: Validators.gst,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppTextField(
                                label: 'Company PAN/TIN',
                                hint: 'e.g. ABCDE1234F (optional)',
                                controller: _companyPanTinController,
                                validator: Validators.pan,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _RegSection(
                            icon: Icons.contact_page_outlined,
                            title: 'HR / Contact Person',
                            subtitle: 'Direct contact info for recruitment HR',
                            children: [
                              AppTextField(
                                label: 'HR First Name *',
                                hint: 'HR First Name',
                                controller: _firstNameController,
                                validator: (v) => Validators.required(v, fieldName: 'HR first name'),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppTextField(
                                label: 'HR Last Name *',
                                hint: 'HR Last Name',
                                controller: _lastNameController,
                                validator: (v) => Validators.required(v, fieldName: 'HR last name'),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              EmployerPhoneInputField(
                                onChanged: (value) => setState(() {
                                  _hrContactE164 = value;
                                  if (value.isNotEmpty) _showPhoneRequiredError = false;
                                }),
                                errorText: _showPhoneRequiredError ? 'HR contact number is required.' : null,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              EmployerEmailOtpField(
                                label: 'HR Email Address *',
                                controller: _hrMailController,
                                onVerifiedChanged: (v) => setState(() => _hrMailVerified = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _RegSection(
                            icon: Icons.lock_outline,
                            title: 'Account Credentials',
                            subtitle: 'Configure your employer login username and password',
                            children: [
                              AppTextField(
                                label: 'Username *',
                                hint: 'Username',
                                controller: _usernameController,
                                validator: (v) => Validators.required(v, fieldName: 'Username'),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              EmployerEmailOtpField(
                                label: 'Account Email Address *',
                                controller: _emailController,
                                onVerifiedChanged: (v) => setState(() => _emailVerified = v),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppTextField(
                                label: 'Password *',
                                hint: 'Password',
                                controller: _password1Controller,
                                obscureText: true,
                                validator: Validators.employerPassword,
                              ),
                              // `includes/password_requirements.html` — the
                              // "Exactly 8 characters" checklist, shown
                              // next to password1 only, matching the web.
                              const _PasswordRequirementsHint(),
                              const SizedBox(height: AppSpacing.md),
                              AppTextField(
                                label: 'Confirm Password *',
                                hint: 'Confirm Password',
                                controller: _password2Controller,
                                obscureText: true,
                                validator: (v) => Validators.confirmPassword(v, original: _password1Controller.text),
                              ),
                              if (_showOtpGateError) ...[
                                const SizedBox(height: AppSpacing.sm),
                                const _ErrorAlert(
                                  message: 'Please verify both email addresses with the OTP before creating your account.',
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppButton(
                            label: 'Create Employer Account',
                            icon: Icons.how_to_reg,
                            isLoading: isLoading,
                            onPressed: _submit,
                            backgroundColor: _sky,
                            foregroundColor: Colors.white,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Center(
                            child: TextButton(
                              onPressed: isLoading ? null : () => context.go(RoutePaths.employerLogin),
                              child: const Text('Already have an account? Sign in here'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const AppFooter(showActivityStats: false, showBrandIcon: false),
              ],
            ),
          ),
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_EmployerRegisterScreenState._sky, _EmployerRegisterScreenState._skyLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.business, color: Colors.white, size: 32),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Employer Registration',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
        ),
        const SizedBox(height: 6),
        Text(
          'Create an employer account to post jobs and find matches for your requirements',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// `.reg-section` (`signup.html:36-63`) — a white card with a light-blue
/// gradient header (icon + title + subtitle) and a padded body.
class _RegSection extends StatelessWidget {
  const _RegSection({required this.icon, required this.title, required this.subtitle, required this.children});

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 20)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFFF0F9FF), Color(0xFFE0F2FE)]),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_EmployerRegisterScreenState._sky, _EmployerRegisterScreenState._skyLight],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 16),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ],
      ),
    );
  }
}

/// `EmployerRegisterForm.industry` (`accounts_app/forms.py:58-71`).
class _IndustryDropdown extends StatelessWidget {
  const _IndustryDropdown({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Industry Type *'),
      hint: const Text('Select Industry'),
      items: [
        for (final option in kEmployerIndustryOptions)
          DropdownMenuItem(value: option.value, child: Text(option.label)),
      ],
      validator: (v) => v == null || v.isEmpty ? 'Industry type is required.' : null,
      onChanged: onChanged,
    );
  }
}

/// `form.company_logo` (`signup.html:158-163`) — a plain file input on the
/// web with the caption "JPG/PNG image format"; no drag-drop, no preview.
class _LogoPicker extends StatelessWidget {
  const _LogoPicker({required this.path, required this.onPick});

  final String? path;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'COMPANY LOGO',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.image_outlined),
          label: Text(path == null ? 'Choose company logo' : path!.split('/').last, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(height: 2),
        const Text('JPG/PNG image format', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}

class _PasswordRequirementsHint extends StatelessWidget {
  const _PasswordRequirementsHint();

  static const _requirements = [
    'Exactly 8 characters',
    'At least 1 uppercase letter',
    'At least 1 lowercase letter',
    'At least 1 number',
    'At least 1 special character',
    'Avoid common passwords',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: 2,
        children: [
          for (final requirement in _requirements)
            Text('• $requirement', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _ErrorAlert extends StatelessWidget {
  const _ErrorAlert({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 16),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(message, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
