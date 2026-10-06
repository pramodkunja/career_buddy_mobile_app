import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/entities/certificate_info.dart';
import '../../domain/entities/certification_category.dart';
import '../../domain/entities/certification_state.dart';
import '../../domain/entities/certification_subject.dart';
import '../../domain/entities/certifications_status.dart';
import '../controllers/certificate_download_controller.dart';
import '../controllers/certificate_form_controller.dart';
import '../providers/certifications_providers.dart';

/// The Skill Up page's `#section-certifications` anchor
/// (`skillup_assessment` app — the real, live `@login_required` JSON API,
/// see `ApiEndpoints`'s Certifications doc comment), reproduced as a
/// self-contained, standalone widget for a human to later slot into the
/// Skill Up hub screen's 4th tab. Fetches its own data via its own
/// providers; deliberately owns no `Scaffold`/`AppBar`/outer scroll view —
/// callers are expected to place it inside their own scrollable, sized
/// parent (mirrors how `_HistoryContent`/`_ResultBody` etc. work in the
/// resume feature).
class CertificationsSection extends ConsumerWidget {
  const CertificationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(certificationsStatusControllerProvider);

    return switch (state) {
      AsyncData(value: final status) => _CertificationsContent(status: status),
      AsyncError(:final error) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: AppErrorView(
          message: error is Failure ? error.message : 'Could not load your certifications. Please try again.',
          onRetry: () => ref.read(certificationsStatusControllerProvider.notifier).retry(),
        ),
      ),
      _ => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: AppLoader(message: 'Loading your certifications...'),
      ),
    };
  }
}

/// Maps a subject slug to the existing, already-built mock-test route it
/// should open — never a new quiz-taking screen. `oop` gets its own
/// dedicated W020 flow, `amcat`/`cocubes` their own standalone endpoints
/// (both excluded from `kQuizSubjects`, see that list's doc comment); every
/// other subject slug is a real entry of `kQuizSubjects` and uses the
/// generic per-subject quiz route.
String _quizRouteFor(String subject) {
  switch (subject) {
    case 'oop':
      return RoutePaths.oopMasteryMockTest;
    case 'amcat':
      return RoutePaths.amcatMockTest;
    case 'cocubes':
      return RoutePaths.cocubesMockTest;
    default:
      return RoutePaths.subjectQuiz(subject);
  }
}

class _CertificationsContent extends StatelessWidget {
  const _CertificationsContent({required this.status});

  final CertificationsStatus status;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryHeader(status: status),
        const SizedBox(height: AppSpacing.lg),
        for (final category in status.categories) ...[
          _CategorySection(category: category),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

/// Overall progress — `total_count`/`attempted_count`/`earned_count`, all
/// computed server-side (`api_certifications_status`), never re-derived
/// here.
class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.status});

  final CertificationsStatus status;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(child: _SummaryStat(label: 'Total', value: status.totalCount)),
          _SummaryDivider(),
          Expanded(child: _SummaryStat(label: 'Attempted', value: status.attemptedCount)),
          _SummaryDivider(),
          Expanded(child: _SummaryStat(label: 'Certified', value: status.earnedCount, color: AppColors.success)),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 40, color: AppColors.border);
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value, this.color});

  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: color ?? AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category});

  final CertificationCategory category;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  category.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${category.earned}/${category.total} earned',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        for (final subject in category.subjects) ...[
          _SubjectCard(subject: subject),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// Pill color per state — chosen to reuse the app's existing semantic
/// [AppColors] rather than inventing a new palette:
/// - [CertificationState.notAttempted]: [AppColors.textMuted] (neutral —
///   nothing has happened yet).
/// - [CertificationState.locked]: [AppColors.warning] (attempted, but below
///   the pass threshold — needs attention, not yet an error).
/// - [CertificationState.eligible]: [AppColors.action] (the app's existing
///   "primary interactive/CTA" blue — something the user can now act on).
/// - [CertificationState.certified]: [AppColors.success] (achieved).
Color _stateColor(CertificationState state) {
  switch (state) {
    case CertificationState.notAttempted:
      return AppColors.textMuted;
    case CertificationState.locked:
      return AppColors.warning;
    case CertificationState.eligible:
      return AppColors.action;
    case CertificationState.certified:
      return AppColors.success;
  }
}

String _stateLabel(CertificationState state) {
  switch (state) {
    case CertificationState.notAttempted:
      return 'Not Attempted';
    case CertificationState.locked:
      return 'Locked';
    case CertificationState.eligible:
      return 'Eligible';
    case CertificationState.certified:
      return 'Certified';
  }
}

class _SubjectCard extends ConsumerWidget {
  const _SubjectCard({required this.subject});

  final CertificationSubject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _stateColor(subject.state);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subject.label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatePill(state: subject.state, color: color),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(_resultCopy(subject), style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: AppSpacing.sm),
          _SubjectActions(subject: subject),
        ],
      ),
    );
  }

  String _resultCopy(CertificationSubject subject) {
    final result = subject.result;
    if (!result.completed || result.score == null || result.total == null) {
      return 'Not attempted yet. Pass with ${subject.passThreshold}% or higher to earn a certificate.';
    }
    final percentage = result.percentage?.round() ?? 0;
    return 'Best score: ${result.score}/${result.total} ($percentage%) · pass mark ${subject.passThreshold}%';
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.state, required this.color});

  final CertificationState state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(
        _stateLabel(state),
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}

class _SubjectActions extends ConsumerWidget {
  const _SubjectActions({required this.subject});

  final CertificationSubject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (subject.state) {
      case CertificationState.notAttempted:
        return AppButton(
          label: 'Take Mock Test',
          icon: Icons.play_circle_outline,
          variant: AppButtonVariant.outlined,
          fullWidth: false,
          onPressed: () => context.push(_quizRouteFor(subject.subject)),
        );
      case CertificationState.locked:
        // Informational copy only — no retake action here, matching the
        // spec's "(if not locked) a Take Mock Test button" — a button is
        // shown only for the not-yet-attempted state above.
        return const Text(
          'Score below the pass mark on your last attempt. Keep practicing!',
          style: TextStyle(color: AppColors.warning, fontSize: 12, fontStyle: FontStyle.italic),
        );
      case CertificationState.eligible:
        return _GenerateCertificateButton(subject: subject);
      case CertificationState.certified:
        return _CertifiedActions(subject: subject);
    }
  }
}

class _GenerateCertificateButton extends ConsumerWidget {
  const _GenerateCertificateButton({required this.subject});

  final CertificationSubject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(certificateFormControllerProvider(subject.subject));
    final isSubmitting = formState is CertificateFormSubmitting;

    return AppButton(
      label: 'Generate Certificate',
      icon: Icons.workspace_premium_outlined,
      variant: AppButtonVariant.primary,
      fullWidth: false,
      isLoading: isSubmitting,
      onPressed: isSubmitting ? null : () => _showNameDialog(context, ref, subject: subject, isRegenerate: false),
    );
  }
}

class _CertifiedActions extends ConsumerWidget {
  const _CertifiedActions({required this.subject});

  final CertificationSubject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(certificateFormControllerProvider(subject.subject));
    final downloadState = ref.watch(certificateDownloadControllerProvider(subject.subject));
    final isSubmitting = formState is CertificateFormSubmitting;
    final isDownloading = downloadState is CertificateDownloading;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        AppButton(
          label: 'View / Download',
          icon: Icons.file_download_outlined,
          variant: AppButtonVariant.primary,
          fullWidth: false,
          isLoading: isDownloading,
          onPressed: isDownloading
              ? null
              : () async {
                  await ref.read(certificateDownloadControllerProvider(subject.subject).notifier).downloadAndOpen();
                  final latest = ref.read(certificateDownloadControllerProvider(subject.subject));
                  if (context.mounted && latest is CertificateDownloadFailed) {
                    AppSnackbar.showError(context, latest.failure.message);
                  }
                },
        ),
        AppButton(
          label: 'Edit Name & Regenerate',
          icon: Icons.edit_outlined,
          variant: AppButtonVariant.outlined,
          fullWidth: false,
          isLoading: isSubmitting,
          onPressed: isSubmitting ? null : () => _showNameDialog(context, ref, subject: subject, isRegenerate: true),
        ),
      ],
    );
  }
}

/// The "Generate Certificate" / "Edit Name & Regenerate" name-entry dialog
/// — pre-filled from [CertificationSubject.prefillName] (generate) or the
/// existing [CertificateInfo.certificateName] (regenerate). Submits via
/// [CertificateFormController], which re-derives eligibility and re-renders
/// the PDF server-side; this dialog never computes or sends a score/state
/// itself.
Future<void> _showNameDialog(
  BuildContext context,
  WidgetRef ref, {
  required CertificationSubject subject,
  required bool isRegenerate,
}) async {
  final initialName = isRegenerate ? (subject.certificate?.certificateName ?? subject.prefillName) : subject.prefillName;
  final controller = TextEditingController(text: initialName);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Consumer(
        builder: (context, dialogRef, _) {
          final formState = dialogRef.watch(certificateFormControllerProvider(subject.subject));
          final isSubmitting = formState is CertificateFormSubmitting;
          final failure = formState is CertificateFormFailed ? formState.failure : null;

          return AlertDialog(
            title: Text(isRegenerate ? 'Edit Certificate Name' : 'Generate Certificate'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${subject.label} · this name will be printed on your certificate.'),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Full name',
                  controller: controller,
                  enabled: !isSubmitting,
                ),
                if (failure != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(failure.message, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              AppButton(
                label: isRegenerate ? 'Save & Regenerate' : 'Generate',
                fullWidth: false,
                isLoading: isSubmitting,
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final name = controller.text.trim();
                        final notifier = dialogRef.read(certificateFormControllerProvider(subject.subject).notifier);
                        final ok = isRegenerate ? await notifier.regenerate(name) : await notifier.generate(name);
                        if (ok && dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                          if (context.mounted) {
                            AppSnackbar.showSuccess(
                              context,
                              isRegenerate ? 'Certificate updated.' : 'Certificate generated!',
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      );
    },
  );
}
