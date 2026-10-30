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
import '../../../../shared/widgets/auth_branding_pane.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../controllers/auth_controller.dart';

/// `templates/employer_login/login.html` — extends `base.html` like every
/// other page, so it carries the same global shell (top nav/footer/
/// chatbot) as the rest of the app, unlike the pre-existing student
/// [LoginScreen] (built before that shared shell existed in Batch 5A) —
/// not something this phase was asked to retrofit.
///
/// Phase 68 (`UI-A-006`): this screen previously rendered a single
/// centered `.login-card`, based on a doc comment claiming the real
/// template never had the student login's two-pane `.auth-card-container`
/// banner. Re-reading the template directly this phase found that claim
/// is now wrong — confirmed by diffing against the **original** Django
/// reference (`Career_Buddy_LMS/templates/employer_login/login.html`),
/// which does still have the old single-card `.login-card`/`.login-icon-
/// box` markup the doc comment (and this screen) were built from. The
/// **updated** reference (`royalStaffing_CB01/templates/employer_login/
/// login.html:17-34`) has since been redesigned to the exact same shared
/// `.auth-banner-left`/`.auth-card-container` shell the student login page
/// uses (`accounts_app/views.py:86-88` confirms this is still the live
/// `EmployerLoginView.template_name`) — a real website update, not a
/// research error. This screen now reproduces that shell via the same
/// [AuthBrandingPane] the student [LoginScreen] uses, with this page's own
/// "Welcome Back!"/employer-feature copy.
class EmployerLoginScreen extends ConsumerStatefulWidget {
  const EmployerLoginScreen({super.key});

  @override
  ConsumerState<EmployerLoginScreen> createState() => _EmployerLoginScreenState();
}

class _EmployerLoginScreenState extends ConsumerState<EmployerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  static const _blue = Color(0xFF185ADB);
  static const _border = Color(0xFFE2E8F0); // `.auth-card-container` border.
  static const _fieldBorder = Color(0xFFCBD5E1);
  static const _fieldFill = Color(0xFFF8FAFC);
  static const _textMuted = Color(0xFF64748B);

  /// The web's own breakpoint for this shared banner/form shell
  /// (`@media (max-width:860px)`, `style.css:2197`) — same value
  /// `LoginScreen` uses for the identical real layout.
  static const double _stackBreakpoint = 860;

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
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xl),
                  child: Center(
                    child: ConstrainedBox(
                      // `.auth-card-container{max-width:920px}` — same real
                      // shell the student login uses.
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= _stackBreakpoint;
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: _border),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(color: Color(0x0D000000), blurRadius: 40, offset: Offset(0, 10)),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: wide
                                ? IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        const Expanded(child: _EmployerBrandingPane(compact: false)),
                                        SizedBox(
                                          width: 460,
                                          child: _EmployerFormPane(
                                            formKey: _formKey,
                                            usernameController: _usernameController,
                                            passwordController: _passwordController,
                                            isLoading: isLoading,
                                            errorMessage: errorMessage,
                                            onSubmit: _submit,
                                            compact: false,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Column(
                                    children: [
                                      const _EmployerBrandingPane(compact: true),
                                      _EmployerFormPane(
                                        formKey: _formKey,
                                        usernameController: _usernameController,
                                        passwordController: _passwordController,
                                        isLoading: isLoading,
                                        errorMessage: errorMessage,
                                        onSubmit: _submit,
                                        compact: true,
                                      ),
                                    ],
                                  ),
                          );
                        },
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

/// `templates/employer_login/login.html:17-34` — this page's own copy for
/// the shared [AuthBrandingPane] shell.
class _EmployerBrandingPane extends StatelessWidget {
  const _EmployerBrandingPane({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AuthBrandingPane(
      compact: compact,
      heading: 'Welcome Back!',
      subtitle: 'Hire talent, manage applications, and grow your team.',
      features: const [
        'AI-Powered Candidate Screening & Scoring',
        'Post Jobs & Manage Applications',
        'Direct Access to Top Talent',
        'Build Your Dream Team Faster',
      ],
    );
  }
}

/// `.auth-form-right` (`login.html:35-82`): title, subtitle, the form
/// itself, the inline error alert, Sign In, the divider, "Create Employer
/// Account", and the "Looking for the student portal?" link — unchanged
/// from before this phase except for moving out from under the removed
/// lock-icon header and duplicate "Hire talent..." line (both now carried
/// by [_EmployerBrandingPane] instead, matching the real page's own
/// banner/form split).
class _EmployerFormPane extends StatelessWidget {
  const _EmployerFormPane({
    required this.formKey,
    required this.usernameController,
    required this.passwordController,
    required this.isLoading,
    required this.errorMessage,
    required this.onSubmit,
    required this.compact,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSubmit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(32, 40, 32, 40)
          : const EdgeInsets.fromLTRB(48, 56, 48, 56),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Employer Login',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Sign in to your hiring dashboard',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _EmployerLoginScreenState._textMuted),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (errorMessage != null) ...[
              _ErrorAlert(message: errorMessage!),
              const SizedBox(height: AppSpacing.md),
            ],
            AppTextField(
              label: 'Username or Email',
              hint: 'Enter username or email',
              controller: usernameController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              enabled: !isLoading,
              validator: (value) => Validators.required(value, fieldName: 'Username or email'),
              fillColor: _EmployerLoginScreenState._fieldFill,
              borderRadius: BorderRadius.circular(10),
              borderColor: _EmployerLoginScreenState._fieldBorder,
              focusedBorderColor: _EmployerLoginScreenState._blue,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Password',
              hint: 'Enter password',
              controller: passwordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              enabled: !isLoading,
              validator: (value) => Validators.required(value, fieldName: 'Password'),
              onSubmitted: (_) => onSubmit(),
              fillColor: _EmployerLoginScreenState._fieldFill,
              borderRadius: BorderRadius.circular(10),
              borderColor: _EmployerLoginScreenState._fieldBorder,
              focusedBorderColor: _EmployerLoginScreenState._blue,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Sign In',
              icon: Icons.login,
              isLoading: isLoading,
              onPressed: onSubmit,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const Expanded(
                  flex: 1,
                  child: Divider(color: _EmployerLoginScreenState._border),
                ),
                Flexible(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    child: Text(
                      "Don't have an account?",
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _EmployerLoginScreenState._textMuted),
                    ),
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: Divider(color: _EmployerLoginScreenState._border),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Create Employer Account',
              icon: Icons.person_add_outlined,
              variant: AppButtonVariant.outlined,
              onPressed: isLoading ? null : () => context.push(RoutePaths.employerRegister),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(color: _EmployerLoginScreenState._border),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Looking for the student portal?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _EmployerLoginScreenState._textMuted),
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
