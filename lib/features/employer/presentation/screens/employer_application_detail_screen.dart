import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/media/media_url_resolver.dart';
import '../../../../core/media/protected_media_download_controller.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../domain/entities/employer_application_detail.dart';
import '../controllers/employer_application_detail_controller.dart';

/// `jobs_app.views.application_detail` (`templates/employer/
/// application_detail.html`) — the real web page an employer uses to
/// review one candidate and change their recruitment status (which emails
/// the candidate server-side on a real change). No JSON API; parsed from
/// the same server-rendered HTML the web renders, via
/// `parseEmployerApplicationDetailHtml`.
///
/// The resume and interview recording are both downloaded through this
/// app's own authenticated Dio client and opened locally
/// (`ProtectedMediaDownloadController`) — not the device's external
/// browser, which doesn't carry this app's session cookie.
class EmployerApplicationDetailScreen extends ConsumerWidget {
  const EmployerApplicationDetailScreen({required this.applicationId, super.key});

  final int applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(employerApplicationDetailControllerProvider(applicationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Application Details')),
      body: Stack(
        children: [
          switch (state) {
            AsyncData(value: final data) => _ApplicationDetailBody(applicationId: applicationId, data: data),
            AsyncError() => AppErrorView(
              message: 'Could not load this application.',
              onRetry: () => ref.read(employerApplicationDetailControllerProvider(applicationId).notifier).retry(),
            ),
            _ => const AppLoader(),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _ApplicationDetailBody extends ConsumerStatefulWidget {
  const _ApplicationDetailBody({required this.applicationId, required this.data});

  final int applicationId;
  final EmployerApplicationDetail data;

  @override
  ConsumerState<_ApplicationDetailBody> createState() => _ApplicationDetailBodyState();
}

class _ApplicationDetailBodyState extends ConsumerState<_ApplicationDetailBody> {
  late String _status;
  late final TextEditingController _notes;
  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _status = widget.data.status;
    _notes = TextEditingController(text: widget.data.employerNotes);
  }

  @override
  void didUpdateWidget(covariant _ApplicationDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _status = widget.data.status;
      _notes.text = widget.data.employerNotes;
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    final result = await ref
        .read(employerApplicationDetailControllerProvider(widget.applicationId).notifier)
        .updateStatus(status: _status, employerNotes: _notes.text.trim());
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (result) {
      case Success():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application updated. The candidate is notified by email if the status changed.')),
        );
      case Failed(failure: final failure):
        setState(() => _submitError = failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final resolvedResumeUrl = resolveMediaUrl(data.resumeUrl);
    final resumeDownload = resolvedResumeUrl == null
        ? const ProtectedMediaDownloadIdle()
        : ref.watch(protectedMediaDownloadControllerProvider(resolvedResumeUrl));
    final resolvedVideoUrl = resolveMediaUrl(data.interviewVideoUrl);
    final videoDownload = resolvedVideoUrl == null
        ? const ProtectedMediaDownloadIdle()
        : ref.watch(protectedMediaDownloadControllerProvider(resolvedVideoUrl));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFFE2E8F0),
                  child: Text(
                    data.applicantName.isEmpty ? '?' : data.applicantName[0].toUpperCase(),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF185ADB)),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    'Applicant for ${data.jobTitle}',
                    style: const TextStyle(color: Color(0xFF185ADB), fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  data.applicantName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.md,
                  alignment: WrapAlignment.center,
                  children: [
                    Text(data.applicantEmail, style: const TextStyle(color: Color(0xFF64748B))),
                    Text(data.applicantPhone, style: const TextStyle(color: Color(0xFF64748B))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Candidate Background', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(child: _infoTile('Experience', '${data.yearsExperience} Year(s)')),
                    Expanded(child: _infoTile('Current Company', data.currentCompany)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _infoTile('Current Salary', data.currentSalary)),
                    Expanded(child: _infoTile('Expected Salary', data.expectedSalary)),
                  ],
                ),
                if (resolvedResumeUrl != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'View Resume Document',
                    icon: Icons.picture_as_pdf_outlined,
                    isLoading: resumeDownload is ProtectedMediaDownloading,
                    onPressed: () => ref
                        .read(protectedMediaDownloadControllerProvider(resolvedResumeUrl).notifier)
                        .downloadAndOpen(protectedMediaFilename(resolvedResumeUrl, '${data.applicantName}_resume.pdf')),
                  ),
                  if (resumeDownload is ProtectedMediaDownloadFailed)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        resumeDownload.failure.message,
                        style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                      ),
                    ),
                ],
                if (data.interviewScore != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      const Icon(Icons.videocam_outlined, color: Color(0xFF185ADB), size: 18),
                      const SizedBox(width: 6),
                      const Text('AI Mock Interview Recording', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(50)),
                        child: Text(
                          'Score ${data.interviewScore}/100',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  if (data.interviewRecordedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Recorded ${data.interviewRecordedAt}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                    ),
                  if (resolvedVideoUrl != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    OutlinedButton.icon(
                      onPressed: videoDownload is ProtectedMediaDownloading
                          ? null
                          : () => ref
                                .read(protectedMediaDownloadControllerProvider(resolvedVideoUrl).notifier)
                                .downloadAndOpen(protectedMediaFilename(resolvedVideoUrl, '${data.applicantName}_interview.mp4')),
                      icon: videoDownload is ProtectedMediaDownloading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.play_circle_outline, size: 18),
                      label: const Text('Open Recording'),
                    ),
                    if (videoDownload is ProtectedMediaDownloadFailed)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          videoDownload.failure.message,
                          style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                        ),
                      ),
                  ],
                ],
                if (data.coverLetter != null && data.coverLetter!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Text('Cover Letter / Statement', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(data.coverLetter!),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Recruitment Decision', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: AppSpacing.sm),
                const Text('Current Stage', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    for (final o in kApplicationStatusOptions) DropdownMenuItem(value: o.value, child: Text(o.label)),
                  ],
                  onChanged: _submitting ? null : (v) => setState(() => _status = v ?? _status),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text('Internal Notes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  enabled: !_submitting,
                  decoration: const InputDecoration(isDense: true),
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(_submitError!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                ],
                const SizedBox(height: AppSpacing.sm),
                AppButton(label: 'Update Status', icon: Icons.save_outlined, isLoading: _submitting, onPressed: _submit),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text('Applied on ${data.appliedAt}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w700)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
