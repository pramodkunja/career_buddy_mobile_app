import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/validators/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_footer.dart';
import '../../../../shared/widgets/app_nav_drawer.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../controllers/auth_controller.dart';

/// `templates/employer_login/login.html` — extends `base.html` like every
/// other page (confirmed by reading the template directly), so it carries
/// the same global shell (top nav/footer/chatbot) as the rest of the app,
/// unlike the pre-existing student [LoginScreen] (built before that shared
/// shell existed in Batch 5A) — not something this batch was asked to
/// retrofit.
///
/// A single centered `.login-card` (`login.html:12-24`), genuinely
/// different from the student login's two-pane `.auth-card-container` —
/// confirmed by reading both templates; not a shared component.
class EmployerLoginScreen extends ConsumerStatefulWidget {
  const EmployerLoginScreen({super.key});

  @override
  ConsumerState<EmployerLoginScreen> createState() => _EmployerLoginScreenState();
}

class _EmployerLoginScreenState extends ConsumerState<EmployerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // `--cb-primary` (final cascade value, `style.css:2550`) and the
  // `.login-icon-box` gradient's own literal second stop (`login.html:29`).
  static const _navy = Color(0xFF14213D);
  static const _indigo = Color(0xFF6366F1);
  static const _border = Color(0xFFE5E5E5); // `--cb-border` final value.
  static const _textMuted = Color(0xFF64748B); // `--cb-text-muted`.

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(authControllerProvider.notifier)
        .loginEmployer(usernameOrEmail: _usernameController.text.trim(), password: _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AuthRefreshing;
    final errorMessage = authState is AuthUnauthenticated ? authState.errorMessage : null;

    return Scaffold(
      appBar: const AppTopBar(),
      drawer: const AppNavDrawer(),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  // `.login-container{max-width:420px;margin:1rem auto;padding:0 1rem}`.
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Container(
                        // `.login-card{padding:3.5rem 2.5rem;border-radius:var(--cb-radius)}`
                        // = 56px/40px, 16px radius.
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: _border),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 30, offset: Offset(0, 10))],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Center(
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [_navy, _indigo],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.lock_outline, color: Colors.white, size: 22),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'Employer Login',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Sign in to your hiring dashboard',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _textMuted),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              if (errorMessage != null) ...[
                                _ErrorAlert(message: errorMessage),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              AppTextField(
                                label: 'Username or Email',
                                hint: 'Enter username or email',
                                controller: _usernameController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                enabled: !isLoading,
                                validator: (value) => Validators.required(value, fieldName: 'Username or email'),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppTextField(
                                label: 'Password',
                                hint: 'Enter password',
                                controller: _passwordController,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                enabled: !isLoading,
                                validator: (value) => Validators.required(value, fieldName: 'Password'),
                                onSubmitted: (_) => _submit(),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              AppButton(
                                label: 'Sign In',
                                icon: Icons.login,
                                isLoading: isLoading,
                                onPressed: _submit,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              AppButton(
                                label: 'Create Employer Account',
                                icon: Icons.person_add_outlined,
                                variant: AppButtonVariant.outlined,
                                onPressed: isLoading ? null : () => context.push(RoutePaths.employerRegister),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                'Hire talent, manage applications, and grow your team.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _textMuted),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              const Divider(color: _border),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Looking for the student portal?',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _textMuted),
                              ),
                              const SizedBox(height: 4),
                              Center(
                                child: TextButton.icon(
                                  onPressed: isLoading ? null : () => context.go(RoutePaths.login),
                                  icon: const Icon(Icons.school_outlined, size: 16),
                                  label: const Text('Job Seeker Login'),
                                ),
                              ),
                            ],
                          ),
                        ),
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

/// `.alert.alert-danger` (`login.html:85-98`) — iterates every
/// `form.errors` entry on the web; this client only ever has one mapped
/// message, same simplification as the student login's own `_ErrorAlert`.
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 16),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFDC2626))),
          ),
        ],
      ),
    );
  }
}
