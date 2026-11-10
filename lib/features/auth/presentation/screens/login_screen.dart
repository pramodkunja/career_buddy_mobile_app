import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/validators/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/auth_branding_pane.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../controllers/auth_controller.dart';

/// Mirrors `templates/users/login.html` — a two-pane card (`.auth-card-
/// container`): a blue-gradient branding pane on the left
/// (`.auth-banner-left`) and the sign-in form on the right
/// (`.auth-form-right`), stacking vertically below the web's own 860px
/// breakpoint (`static/css/style.css:2192-2206`). Colors/radius/spacing
/// below are the literal values read from `static/css/style.css`'s AUTH
/// PAGES block and the template's own inline styles — NOT the app's
/// generic theme, since this page's fields/banner/outline button are
/// genuinely blue (`#185adb`) on the real site: confirmed by reading the
/// cascade all the way to the end of the file, not just the first
/// `!important` match — nothing later overrides `.auth-banner-left`/
/// `.auth-form .form-control`/`.auth-form .form-control:focus`. The Sign
/// In button itself is the one genuine exception: it's plain `class="btn
/// btn-primary"`, and `.btn-primary`'s own final, latest override
/// (`style.css:2899-2919`, appended after both the original blue theme and
/// a since-superseded gold "BLACK & GOLD" pass) repaints it navy with
/// white text — not gold, and not the inline blue either. This screen
/// doesn't set that color itself; it relies on `AppButton`'s default
/// styling (`app_theme.dart`'s `elevatedButtonTheme`), which is navy for
/// exactly this reason.
///
/// Registration, password-reset, and employer-portal screens are all real,
/// fully-built screens — these links are genuine navigation to them, not
/// placeholders.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  static const _blue = Color(0xFF185ADB);

  /// The web's own breakpoint for this page
  /// (`@media (max-width:860px)`, `style.css:2192`) — deliberately its own
  /// value, not the app's generic `Breakpoints.tabletMinWidth` (700),
  /// which is for a different screen's layout decision.
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
        .login(
          usernameOrEmail: _usernameController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AuthRefreshing;
    final errorMessage = authState is AuthUnauthenticated
        ? authState.errorMessage
        : null;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            // `.auth-page-wrapper` (`style.css:2034-2041`).
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xl,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= _stackBreakpoint;
                        // `.auth-card-container` (`style.css:2043-2053`).
                        return Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0D000000),
                                blurRadius: 40,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: wide
                              ? IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Expanded(
                                        child: _LoginBrandingPane(compact: false),
                                      ),
                                      SizedBox(
                                        width: 460,
                                        child: _FormPane(
                                          formKey: _formKey,
                                          usernameController:
                                              _usernameController,
                                          passwordController:
                                              _passwordController,
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
                                    const _LoginBrandingPane(compact: true),
                                    _FormPane(
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
            ),
          ),
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

/// `templates/users/login.html:7-23` — the student sign-in page's own copy
/// for the shared [AuthBrandingPane] shell.
///
/// Phase 68 (`UI-A-001`/`UI-A-002`/`UI-A-003`): the subtitle previously
/// read "Continue your journey to Business English mastery and career
/// growth." — the real page says "Continue your journey to career
/// growth." (no "Business English mastery and"); the first feature line
/// previously read "20+ Comprehensive..." where the real page literally
/// has a space before the `+` ("20 + Comprehensive...", `login.html:19`).
/// Both corrected to match source exactly, however the live wording looks.
class _LoginBrandingPane extends StatelessWidget {
  const _LoginBrandingPane({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AuthBrandingPane(
      compact: compact,
      heading: 'Welcome Back!',
      subtitle: 'Continue your journey to career growth.',
      features: const [
        '20 + Comprehensive Learning Activities',
        'Interactive Exercises & Speaking Quizzes',
        'AI Resume Matcher & ATS Score Analytics',
        'Direct Recruiter Hiring & Job Applications',
      ],
    );
  }
}

/// `.auth-form-right` (`style.css:2116-2165`): title, subtitle, the form
/// itself, the inline error alert (`.alert.alert-danger`, template lines
/// 49-65), Sign In, the divider, and the two secondary links.
class _FormPane extends StatelessWidget {
  const _FormPane({
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
      // `.auth-form-right`: desktop `padding:3.5rem 3rem` = 56px/48px
      // (`style.css:2119`); mobile override `2.5rem 2rem` = 40px/32px
      // (`style.css:2198-2201`).
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
              'Job Seeker Sign In',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Enter your login credentials to access your dashboard',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              label: 'Username or Email',
              controller: usernameController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              enabled: !isLoading,
              validator: (value) =>
                  Validators.required(value, fieldName: 'Username or email'),
              fillColor: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              borderColor: Theme.of(context).colorScheme.outlineVariant,
              focusedBorderColor: _LoginScreenState._blue,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Password',
              controller: passwordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              enabled: !isLoading,
              validator: (value) =>
                  Validators.required(value, fieldName: 'Password'),
              onSubmitted: (_) => onSubmit(),
              fillColor: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              borderColor: Theme.of(context).colorScheme.outlineVariant,
              focusedBorderColor: _LoginScreenState._blue,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: _LoginScreenState._blue,
                ),
                onPressed: isLoading
                    ? null
                    : () => context.push(RoutePaths.passwordReset),
                child: const Text('Forgot password?'),
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _ErrorAlert(message: errorMessage!),
            ],
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Sign In to Dashboard',
              icon: Icons.login,
              isLoading: isLoading,
              onPressed: onSubmit,
            ),
            const SizedBox(height: AppSpacing.lg),
            // `.auth-divider` (`style.css:2167-2190`).
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Divider(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                Flexible(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    child: Text(
                      'Don\'t have an account?',
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Divider(color: Theme.of(context).colorScheme.outlineVariant),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // `.btn-outline-primary` here carries its own inline
            // `border-color:#cbd5e1;color:#185adb` (template line 71) with
            // no competing `!important`, so it stays light-gray/blue, not
            // the app's usual navy outline.
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _LoginScreenState._blue,
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isLoading
                    ? null
                    : () => context.push(RoutePaths.register),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_add_outlined, size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Create Free Candidate Account',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Are you an Employer / Recruiter?',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            // `.btn-light` (Bootstrap default, unmodified) + inline
            // `border:1px solid #cbd5e1;color:#475569`.
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isLoading
                    ? null
                    : () => context.push(RoutePaths.employerLogin),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.business_outlined, size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Employer Portal Sign In',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Debug-only Direct Demo Entry — never rendered in a release
            // build (`kDebugMode` is a compile-time constant). See
            // `DemoEntryScreen`'s doc comment for the full safety
            // reasoning.
            if (kDebugMode) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Preview Demo (Debug)',
                icon: Icons.science_outlined,
                variant: AppButtonVariant.text,
                onPressed: isLoading
                    ? null
                    : () => context.go(RoutePaths.demoEntry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// `.alert.alert-danger.py-2.rounded-3.small` with the template's own
/// inline override (`style="border:1px solid #fecaca;background:#fef2f2;
/// color:#dc2626"`, `login.html:49-65`) — an inline persistent box, not a
/// transient snackbar. The web iterates Django's own per-field form
/// errors; this client only ever has one mapped [Failure] message, so a
/// single line is shown instead of fabricating multiple field errors.
class _ErrorAlert extends StatelessWidget {
  const _ErrorAlert({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
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
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }
}
