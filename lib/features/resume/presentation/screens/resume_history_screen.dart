import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/media/media_url_resolver.dart';
import '../../../../core/media/protected_media_download_controller.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_footer.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/app_nav_drawer.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../domain/entities/resume_history_item.dart';
import '../providers/resume_providers.dart';

/// `career_app.views.resume_history` (`templates/resume_history.html`).
///
/// "View File" downloads `resume.file.url` (a session-cookie-protected
/// `/media/resumes/...` path, `core/media_views.py:serve_protected_media`)
/// through this app's own authenticated Dio client and opens the saved
/// local copy — not the device's external browser, which doesn't carry
/// this app's session cookie and would otherwise bounce the user to a
/// login prompt. See `ProtectedMediaDownloadController`'s doc comment.
class ResumeHistoryScreen extends ConsumerWidget {
  const ResumeHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(resumeHistoryControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(),
      drawer: const AppNavDrawer(),
      body: Stack(
        children: [
          switch (state) {
            AsyncData(value: final items) => RefreshIndicator(
              onRefresh: () => ref.read(resumeHistoryControllerProvider.notifier).retry(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _HistoryContent(items: items),
                    const AppFooter(),
                  ],
                ),
              ),
            ),
            AsyncError(:final error) => AppErrorView(
              message: error is Failure ? error.message : 'Something went wrong. Please try again.',
              onRetry: () => ref.read(resumeHistoryControllerProvider.notifier).retry(),
            ),
            _ => const AppLoader(message: 'Loading your resume history...'),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _HistoryContent extends StatelessWidget {
  const _HistoryContent({required this.items});

  final List<ResumeHistoryItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            label: 'Upload Another Resume',
            icon: Icons.arrow_back,
            variant: AppButtonVariant.outlined,
            fullWidth: false,
            onPressed: () => context.go(RoutePaths.resumeBuilder),
          ),
          const SizedBox(height: AppSpacing.lg),
          // `.resume-hero` (`resume_history.html:50-57`).
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E3A5F), Color(0xFF0EA5E9)],
                stops: [0.0, 0.6, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.history, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Resume History',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  "Every resume you've uploaded is kept here — uploading a new one never removes the earlier ones.",
                  style: TextStyle(color: Color(0xBFFFFFFF)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (items.isEmpty)
            const _EmptyHistory()
          else ...[
            Text(
              '${items.length} resume${items.length == 1 ? '' : 's'} uploaded so far',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final item in items) ...[
              _HistoryCard(item: item),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ],
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.item});

  final ResumeHistoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedUrl = resolveMediaUrl(item.fileUrl);
    final downloadState = resolvedUrl == null
        ? const ProtectedMediaDownloadIdle()
        : ref.watch(protectedMediaDownloadControllerProvider(resolvedUrl));
    final downloading = downloadState is ProtectedMediaDownloading;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: item.isCurrent ? const Color(0xFFF0F9FF) : Colors.white,
        border: Border.all(color: item.isCurrent ? const Color(0xFF0EA5E9) : const Color(0xFFE2E8F0), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.insert_drive_file_outlined, color: Color(0xFF0EA5E9)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(item.fileName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (item.isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0x1A0EA5E9),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Text(
                          'Current',
                          style: TextStyle(color: Color(0xFF0EA5E9), fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
                Text(
                  'Uploaded ${item.uploadedAtDisplay}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (resolvedUrl != null)
                      OutlinedButton.icon(
                        onPressed: downloading
                            ? null
                            : () => ref
                                  .read(protectedMediaDownloadControllerProvider(resolvedUrl).notifier)
                                  .downloadAndOpen(protectedMediaFilename(resolvedUrl, item.fileName)),
                        icon: downloading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('View File'),
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.read(resumeBuilderControllerProvider.notifier).reanalyze(item.id);
                        context.go(RoutePaths.resumeBuilder);
                      },
                      icon: const Icon(Icons.show_chart, size: 16),
                      label: const Text('View ATS Analysis'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                if (downloadState is ProtectedMediaDownloadFailed) ...[
                  const SizedBox(height: 4),
                  Text(
                    downloadState.failure.message,
                    style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state (`resume_history.html:96-102`).
class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl, horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.help_outline, size: 40, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.md),
          const Text('No resumes uploaded yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
            'Upload your first resume to get an AI-powered ATS score.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Upload a Resume', fullWidth: false, onPressed: () => context.go(RoutePaths.resumeBuilder)),
        ],
      ),
    );
  }
}
