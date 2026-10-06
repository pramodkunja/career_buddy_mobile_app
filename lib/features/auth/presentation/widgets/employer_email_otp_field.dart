import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/validators/validators.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/auth_providers.dart';

/// `signup.html:227-242`/`263-278` — the HR/Account email field paired with
/// its own inline "Verify"/OTP-code/"Confirm"/"Resend" controls
/// (signup.html:388-480's inline JS, `send_email_otp`/`verify_email_otp`).
/// One instance is used for each of the two email fields on the
/// registration form (`hrMail`/`email`) — structurally identical on the
/// web too (byte-identical markup, only the id prefix differs).
class EmployerEmailOtpField extends ConsumerStatefulWidget {
  const EmployerEmailOtpField({
    required this.label,
    required this.controller,
    required this.onVerifiedChanged,
    this.sendOtp,
    this.verifyOtp,
    super.key,
  });

  final String label;
  final TextEditingController controller;

  /// Called with `true` once this exact email address has been verified in
  /// this session, `false` whenever it stops being so (edited after
  /// verifying, same as the web's own `refreshAll()`/input-listener
  /// behavior, `signup.html:461-463`).
  final ValueChanged<bool> onVerifiedChanged;

  /// Defaults to `employerAuthRepositoryProvider`'s calls (unchanged
  /// behavior for every existing employer-registration call site). Student
  /// registration passes the plain `authRepositoryProvider`'s equivalents
  /// instead — same shared Django endpoints (`users/urls.py:'register/
  /// send-otp/'`/`'verify-otp/'`), same widget, different session-level
  /// caller.
  final Future<Result<String>> Function(WidgetRef ref, String email)? sendOtp;
  final Future<Result<String>> Function(WidgetRef ref, {required String email, required String code})? verifyOtp;

  @override
  ConsumerState<EmployerEmailOtpField> createState() => _EmployerEmailOtpFieldState();
}

enum _OtpStage { idle, sending, sent, verifying, verified }

class _EmployerEmailOtpFieldState extends ConsumerState<EmployerEmailOtpField> {
  _OtpStage _stage = _OtpStage.idle;
  String? _statusMessage;
  bool _statusIsError = false;
  String? _verifiedEmail;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onEmailEdited);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onEmailEdited);
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _onEmailEdited() {
    // Mirrors `signup.html:461-463`: editing an already-verified email
    // un-verifies it locally until Confirm succeeds again for the new value.
    if (_verifiedEmail != null && widget.controller.text.trim().toLowerCase() != _verifiedEmail) {
      setState(() {
        _stage = _OtpStage.idle;
        _verifiedEmail = null;
        _statusMessage = null;
      });
      widget.onVerifiedChanged(false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldownSeconds--);
      if (_cooldownSeconds <= 0) timer.cancel();
    });
  }

  Future<void> _sendOtp() async {
    final email = widget.controller.text.trim();
    if (email.isEmpty || Validators.email(email) != null) {
      setState(() {
        _statusIsError = true;
        _statusMessage = 'Enter this email address first.';
      });
      return;
    }
    setState(() {
      _stage = _OtpStage.sending;
      _statusIsError = false;
      _statusMessage = 'Sending code…';
    });
    final result = widget.sendOtp != null
        ? await widget.sendOtp!(ref, email)
        : await ref.read(employerAuthRepositoryProvider).sendOtp(email);
    if (!mounted) return;
    switch (result) {
      case Success(value: final message):
        setState(() {
          _stage = _OtpStage.sent;
          _statusIsError = false;
          _statusMessage = message;
        });
        _codeController.clear();
        _startCooldown();
      case Failed(failure: final failure):
        setState(() {
          _stage = _OtpStage.idle;
          _statusIsError = true;
          _statusMessage = failure.message;
        });
    }
  }

  Future<void> _confirmOtp() async {
    final email = widget.controller.text.trim();
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _statusIsError = true;
        _statusMessage = 'Enter the 6-digit code from your email.';
      });
      return;
    }
    setState(() {
      _stage = _OtpStage.verifying;
      _statusIsError = false;
      _statusMessage = 'Verifying…';
    });
    final result = widget.verifyOtp != null
        ? await widget.verifyOtp!(ref, email: email, code: code)
        : await ref.read(employerAuthRepositoryProvider).verifyOtp(email: email, code: code);
    if (!mounted) return;
    switch (result) {
      case Success():
        setState(() {
          _stage = _OtpStage.verified;
          _verifiedEmail = email.toLowerCase();
          _statusIsError = false;
          _statusMessage = '✔ Verified';
        });
        widget.onVerifiedChanged(true);
      case Failed(failure: final failure):
        setState(() {
          _stage = _OtpStage.sent;
          _statusIsError = true;
          _statusMessage = failure.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final verified = _stage == _OtpStage.verified;
    final busy = _stage == _OtpStage.sending || _stage == _OtpStage.verifying;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: widget.label,
                controller: widget.controller,
                keyboardType: TextInputType.emailAddress,
                readOnly: verified,
                enabled: !verified,
                validator: (value) => Validators.email(value, fieldName: widget.label),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (!verified)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: OutlinedButton(
                  // Theme uses Size.fromHeight(48) (infinite width), which breaks inside a Row.
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: busy || _cooldownSeconds > 0 ? null : _sendOtp,
                  child: Text(
                    _cooldownSeconds > 0
                        ? '${_stage == _OtpStage.sent ? 'Resend' : 'Verify'} (${_cooldownSeconds}s)'
                        : (_stage == _OtpStage.sent ? 'Resend' : 'Verify'),
                  ),
                ),
              ),
          ],
        ),
        if (verified) ...[
          const SizedBox(height: 4),
          const Row(
            children: [
              Icon(Icons.check_circle, size: 14, color: AppColors.success),
              SizedBox(width: 4),
              Text('Verified', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
        ] else if (_stage == _OtpStage.sent || _stage == _OtpStage.verifying) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Enter 6-digit code',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              TextButton(onPressed: busy ? null : _confirmOtp, child: const Text('Confirm')),
            ],
          ),
        ],
        if (_statusMessage != null) ...[
          const SizedBox(height: 4),
          Text(
            _statusMessage!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _statusIsError ? AppColors.danger : AppColors.success,
            ),
          ),
        ],
      ],
    );
  }
}
