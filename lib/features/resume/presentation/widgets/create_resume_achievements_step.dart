import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/create_resume_state.dart';
import '../../domain/entities/create_resume_validation_error.dart';
import '../providers/resume_providers.dart';
import 'manual_resume_form_widgets.dart';

/// Step 8 — Achievements & Awards
/// (`ENTRY_FIELDS['achievements']`/`ENTRY_REQUIRED['achievements']`,
/// confirmed directly against `career_app/create_resume.py:80-81,119,133`
/// and `static/js/create_resume.js:106-107`: `title` is the only field
/// required for completeness).
class CreateResumeAchievementsStep extends ConsumerWidget {
  const CreateResumeAchievementsStep({
    required this.entries,
    required this.serverErrors,
    super.key,
  });

  final List<CreateResumeAchievementEntry> entries;
  final List<CreateResumeValidationError> serverErrors;

  String? _errorFor(int index, String field) => serverErrors
      .where((e) => e.field == 'achievements.$index.$field')
      .map((e) => e.message)
      .firstOrNull;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(createResumeBuilderControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        for (var i = 0; i < entries.length; i++)
          ManualResumeEntryCard(
            title: entries[i].title.isEmpty ? 'Achievement ${i + 1}' : entries[i].title,
            onRemove: () async {
              if (!entries[i].isBlank && !await confirmRemoveEntry(context, 'achievement entry')) {
                return;
              }
              controller.removeAchievement(i);
            },
            child: _AchievementFields(
              entry: entries[i],
              errorFor: (field) => _errorFor(i, field),
              onChanged: (fn) => controller.updateAchievement(i, fn),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: entries.length >= 20 ? null : controller.addAchievement,
          icon: const Icon(Icons.add),
          label: Text(entries.isEmpty ? 'Add achievement' : 'Add another achievement'),
        ),
      ],
    );
  }
}

class _AchievementFields extends StatelessWidget {
  const _AchievementFields({
    required this.entry,
    required this.errorFor,
    required this.onChanged,
  });

  final CreateResumeAchievementEntry entry;
  final String? Function(String field) errorFor;
  final void Function(CreateResumeAchievementEntry Function(CreateResumeAchievementEntry)) onChanged;

  String _monthYear(String month, String year) =>
      year.isEmpty ? '' : '$year-${month.padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ManualResumeTextField(
          label: 'Achievement title',
          required: true,
          value: entry.title,
          errorText: errorFor('title'),
          onChanged: (v) => onChanged((e) => e.copyWith(title: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Organisation (optional)',
          value: entry.organization,
          onChanged: (v) => onChanged((e) => e.copyWith(organization: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeMonthField(
          label: 'Date (optional)',
          value: _monthYear(entry.month, entry.year),
          onChanged: (v) {
            final parts = v.split('-');
            onChanged((e) => e.copyWith(year: parts[0], month: parts[1]));
          },
        ),
        if (errorFor('year') != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              errorFor('year')!,
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Description (optional)',
          value: entry.description,
          maxLines: 2,
          errorText: errorFor('description'),
          onChanged: (v) => onChanged((e) => e.copyWith(description: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Supporting URL (optional)',
          value: entry.url,
          hint: 'https://',
          keyboardType: TextInputType.url,
          errorText: errorFor('url'),
          onChanged: (v) => onChanged((e) => e.copyWith(url: v)),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
