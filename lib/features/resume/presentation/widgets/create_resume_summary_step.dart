import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/create_resume_validation_error.dart';
import '../providers/resume_providers.dart';
import 'manual_resume_form_widgets.dart';

/// Step 2 — Professional Summary (`SUMMARY_MIN`=50, `SUMMARY_LIMIT`=1200,
/// confirmed directly). Optional overall — an empty summary is never an
/// error, only a non-empty one shorter than 50 or longer than 1200
/// characters is (`validate()`'s own `if state['summary']:` guard).
class CreateResumeSummaryStep extends ConsumerWidget {
  const CreateResumeSummaryStep({
    required this.summary,
    required this.serverErrors,
    super.key,
  });

  final String summary;
  final List<CreateResumeValidationError> serverErrors;

  static const int _limit = 1200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(createResumeBuilderControllerProvider.notifier);
    final error = serverErrors
        .where((e) => e.field == 'summary')
        .map((e) => e.message)
        .firstOrNull;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const Text(
          'A short overview of your experience and what you bring to the role. Optional, but recommended — '
          'at least 50 characters once you start writing one.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: AppSpacing.md),
        ManualResumeTextField(
          label: 'Professional summary',
          value: summary,
          maxLines: 8,
          maxLength: _limit,
          errorText: error,
          onChanged: controller.setSummary,
        ),
        ManualResumeCharCounter(current: summary.length, max: _limit),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
