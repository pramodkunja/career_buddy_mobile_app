import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/validators/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/widgets/employer_phone_input_field.dart';
import '../../domain/entities/public_job_detail.dart';
import '../controllers/public_job_detail_controller.dart';

/// `jobs_app.views.job_detail` (`templates/jobs/job_detail.html`) — the
/// public job listing + apply page. Reachable by anyone; the apply form
/// is only shown when the signed-in session isn't an employer portal
/// session (mirrors the real `request.session.portal != 'employer'`
/// check, read from the already-known auth state rather than re-derived
/// from HTML).
class PublicJobDetailScreen extends ConsumerWidget {
  const PublicJobDetailScreen({required this.jobId, super.key});

  final int jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(publicJobDetailControllerProvider(jobId));
    final authState = ref.watch(authControllerProvider);
    final isEmployerSession = authState is AuthAuthenticated && authState.user.isEmployer;

    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: Stack(
        children: [
          switch (state) {
            AsyncData(value: final data) => _JobDetailBody(jobId: jobId, data: data, showApplyForm: !isEmployerSession),
            AsyncError() => AppErrorView(
              message: 'Could not load this job.',
              onRetry: () => ref.read(publicJobDetailControllerProvider(jobId).notifier).retry(),
            ),
            _ => const AppLoader(),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _JobDetailBody extends ConsumerStatefulWidget {
  const _JobDetailBody({required this.jobId, required this.data, required this.showApplyForm});

  final int jobId;
  final PublicJobDetail data;
  final bool showApplyForm;

  @override
  ConsumerState<_JobDetailBody> createState() => _JobDetailBodyState();
}

class _JobDetailBodyState extends ConsumerState<_JobDetailBody> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _skills = TextEditingController();
  final _yearsExperience = TextEditingController();
  final _currentCompany = TextEditingController();
  final _currentSalary = TextEditingController();
  final _expectedSalary = TextEditingController();
  final _coverLetter = TextEditingController();
  String _phoneE164 = '';
  PlatformFile? _resume;
  bool _submitting = false;
  String? _submitError;
  bool _submitted = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _skills, _yearsExperience, _currentCompany, _currentSalary, _expectedSalary, _coverLetter]) {
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
    if (_phoneE164.isEmpty) {
      setState(() => _submitError = 'Phone number is required.');
      return;
    }
    setState(() => _submitting = true);

    final submission = PublicJobApplicationSubmission(
      name: _name.text.trim(),
      email: _email.text.trim(),
      phoneE164: _phoneE164,
      resumePath: _resume?.path,
      coverLetter: _coverLetter.text.trim(),
      skills: _skills.text.trim(),
      yearsExperience: int.tryParse(_yearsExperience.text.trim()),
      currentCompany: _currentCompany.text.trim(),
      currentSalary: double.tryParse(_currentSalary.text.trim()),
      expectedSalary: double.tryParse(_expectedSalary.text.trim()),
    );

    final result = await ref.read(publicJobDetailControllerProvider(widget.jobId).notifier).apply(submission);
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (result) {
      case Success():
        setState(() => _submitted = true);
      case Failed(failure: final failure):
        setState(() => _submitError = failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                if (data.companyName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(data.companyName, style: const TextStyle(color: Color(0xFF64748B))),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (data.jobType.isNotEmpty) _badge(data.jobType, const Color(0xFF185ADB)),
                    if (data.experience.isNotEmpty) _badge(data.experience, const Color(0xFF64748B)),
                    if (data.location.isNotEmpty) _badge(data.location, const Color(0xFF0EA5E9)),
                    if (data.salaryDisplay.isNotEmpty) _badge(data.salaryDisplay, const Color(0xFF16A34A)),
                    if (data.openings.isNotEmpty) _badge(data.openings, const Color(0xFFD97706)),
                  ],
                ),
                const Divider(height: AppSpacing.lg),
                const Text('Job Description', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(data.description),
                const SizedBox(height: AppSpacing.md),
                const Text('Requirements', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(data.requirements),
                if (data.skills.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Text('Skills Required', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final s in data.skills) _skillChip(s)]),
                ],
                if (data.deadline.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text('Application Deadline: ${data.deadline}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                ],
              ],
            ),
          ),
          if (widget.showApplyForm) ...[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: _submitted
                  ? const _SubmittedConfirmation()
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Apply for this Position', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: AppSpacing.sm),
                          TextFormField(
                            controller: _name,
                            decoration: const InputDecoration(labelText: 'Full Name', isDense: true),
                            validator: Validators.required,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextFormField(
                            controller: _email,
                            decoration: const InputDecoration(labelText: 'Email', isDense: true),
                            validator: Validators.email,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          EmployerPhoneInputField(hint: 'Phone Number', onChanged: (v) => _phoneE164 = v),
                          const SizedBox(height: AppSpacing.sm),
                          TextFormField(
                            controller: _skills,
                            decoration: const InputDecoration(labelText: 'Skills (optional)', hintText: 'e.g. Python, Django, React, SQL', isDense: true),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextFormField(
                            controller: _yearsExperience,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Years of Experience (optional)', isDense: true),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextFormField(
                            controller: _currentCompany,
                            decoration: const InputDecoration(labelText: 'Current Company (optional)', isDense: true),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextFormField(
                            controller: _currentSalary,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Current Salary (optional)', isDense: true),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextFormField(
                            controller: _expectedSalary,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Expected Salary (optional)', isDense: true),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextFormField(
                            controller: _coverLetter,
                            maxLines: 4,
                            decoration: const InputDecoration(labelText: 'Cover Letter (optional)', isDense: true),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _ResumePicker(fileName: _resume?.name, onPick: _submitting ? null : _pickResume),
                          if (_submitError != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(_submitError!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          AppButton(label: 'Submit My Application', icon: Icons.send_outlined, isLoading: _submitting, onPressed: _submit),
                        ],
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(50)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _skillChip(String skill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
      child: Text(skill, style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _SubmittedConfirmation extends StatelessWidget {
  const _SubmittedConfirmation();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 40),
        SizedBox(height: AppSpacing.sm),
        Text('Application submitted successfully!', style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 4),
        Text(
          'A confirmation email has been sent.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
      ],
    );
  }
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
                fileName ?? 'Upload resume (optional)',
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
