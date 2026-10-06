import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/validators/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../providers/auth_providers.dart';

/// `templates/registration/password_reset_confirm.html`. The web reaches
/// this page via the `uidb64`/`token` embedded in the emailed reset link's
/// URL; this app has no app-link/universal-link verification configured
/// against the production host to intercept that link directly (that would
/// require hosting `assetlinks.json`/`apple-app-site-association` on
/// `careerbuddy4u.com`, outside this app's control), so instead the user
/// pastes the link's text here and the app extracts the same two path
/// segments itself — an explicit, documented mobile adaptation of the same
/// underlying flow, not a shortcut around it.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

enum _Stage { pasteLink, checkingLink, invalidLink, validLink, submitting, checkFailed }

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  static final _linkPattern = RegExp(r'reset/([A-Za-z0-9_-]+)/([A-Za-z0-9_-]+)');

  final _linkController = TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();
  final _password1Controller = TextEditingController();
  final _password2Controller = TextEditingController();

  _Stage _stage = _Stage.pasteLink;
  String? _errorMessage;
  String? _uidb64;
  String? _token;

  @override
  void dispose() {
    _linkController.dispose();
    _password1Controller.dispose();
    _password2Controller.dispose();
    super.dispose();
  }

  Future<void> _checkLink() async {
    final match = _linkPattern.firstMatch(_linkController.text.trim());
    if (match == null) {
      setState(() {
        _errorMessage = "That doesn't look like a valid reset link. Paste the full link from your email.";
      });
      return;
    }
    final uidb64 = match.group(1)!;
    final token = match.group(2)!;
    setState(() {
      _stage = _Stage.checkingLink;
      _errorMessage = null;
    });
    final result = await ref.read(passwordResetRepositoryProvider).checkResetLink(uidb64: uidb64, token: token);
    if (!mounted) return;
    switch (result) {
      case Success(value: final isValid):
        setState(() {
          if (isValid) {
            _uidb64 = uidb64;
            _token = token;
            _stage = _Stage.validLink;
          } else {
            _stage = _Stage.invalidLink;
          }
        });
      case Failed(failure: final failure):
        setState(() {
          _stage = _Stage.checkFailed;
          _errorMessage = failure.message;
        });
    }
  }

  Future<void> _submitNewPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() {
      _stage = _Stage.submitting;
      _errorMessage = null;
    });
    final result = await ref.read(passwordResetRepositoryProvider).confirmReset(
      uidb64: _uidb64!,
      token: _token!,
      password1: _password1Controller.text,
      password2: _password2Controller.text,
    );
    if (!mounted) return;
    switch (result) {
      case Success():
        context.go(RoutePaths.passwordResetComplete);
      case Failed(failure: final failure):
        setState(() {
          _stage = _Stage.validLink;
          _errorMessage = failure.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: AppCard(child: _buildBody(context)),
              ),
            ),
          ),
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_stage) {
      case _Stage.checkingLink:
        return const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.xl), child: AppLoader());
      case _Stage.invalidLink:
        return _buildInvalidLink(context, "This password reset link is no longer valid. Please request a new one.");
      case _Stage.checkFailed:
        return _buildInvalidLink(context, _errorMessage ?? 'Something went wrong. Please try again.');
      case _Stage.pasteLink:
        return _buildPasteLink(context);
      case _Stage.validLink:
      case _Stage.submitting:
        return _buildNewPasswordForm(context);
    }
  }

  Widget _buildPasteLink(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Paste your reset link',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Open the email we sent you, copy the reset link, and paste it here.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Reset link',
          hint: 'https://careerbuddy4u.com/users/reset/…/…/',
          controller: _linkController,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _checkLink(),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(_errorMessage!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
        ],
        const SizedBox(height: AppSpacing.md),
        AppButton(label: 'Continue', icon: Icons.arrow_forward, onPressed: _checkLink),
      ],
    );
  }

  Widget _buildInvalidLink(BuildContext context, String message) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 30),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Invalid or expired link',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Request a new link',
          onPressed: () => context.go(RoutePaths.passwordReset),
        ),
      ],
    );
  }

  Widget _buildNewPasswordForm(BuildContext context) {
    final submitting = _stage == _Stage.submitting;
    return Form(
      key: _passwordFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Set a new password',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a strong password for your account.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'New password',
            controller: _password1Controller,
            obscureText: true,
            enabled: !submitting,
            autofillHints: const [AutofillHints.newPassword],
            validator: Validators.employerPassword,
          ),
          const SizedBox(height: AppSpacing.xs),
          _PasswordRequirements(passwordListenable: _password1Controller),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Confirm new password',
            controller: _password2Controller,
            obscureText: true,
            enabled: !submitting,
            textInputAction: TextInputAction.done,
            validator: (value) => Validators.confirmPassword(value, original: _password1Controller.text),
            onSubmitted: (_) => _submitNewPassword(),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(_errorMessage!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Change my password', isLoading: submitting, onPressed: _submitNewPassword),
        ],
      ),
    );
  }
}

/// Mirrors `templates/includes/password_requirements.html`'s live checklist
/// — all 6 rules stay visible with a per-rule tick, instead of the user only
/// discovering one failure at a time from a single server error string.
class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements({required this.passwordListenable});

  final TextEditingController passwordListenable;

  static const _commonPasswords = {
    'password', '12345678', 'qwertyui', 'letmein1', 'iloveyou', 'admin123',
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: passwordListenable,
      builder: (context, _) {
        final password = passwordListenable.text;
        final rules = <String, bool>{
          'Exactly 8 characters': password.length == 8,
          'At least 1 uppercase letter': RegExp(r'[A-Z]').hasMatch(password),
          'At least 1 lowercase letter': RegExp(r'[a-z]').hasMatch(password),
          'At least 1 number': RegExp(r'[0-9]').hasMatch(password),
          'At least 1 special character': RegExp(r'[^A-Za-z0-9]').hasMatch(password),
          'Avoid common passwords': password.isNotEmpty && !_commonPasswords.contains(password.toLowerCase()),
        };
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in rules.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      Icon(
                        entry.value ? Icons.check_circle : Icons.circle_outlined,
                        size: 14,
                        color: entry.value ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: entry.value ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
