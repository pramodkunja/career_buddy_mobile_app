import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/create_resume_state.dart';
import '../../domain/entities/create_resume_validation_error.dart';
import '../providers/resume_providers.dart';
import 'manual_resume_form_widgets.dart';

/// `EMPLOYMENT_TYPES`, confirmed directly against `career_app/create_resume.py`.
const List<String> _kEmploymentTypes = [
  'Full-time',
  'Part-time',
  'Internship',
  'Contract',
  'Freelance',
  'Apprenticeship',
  'Other', //
];

/// Step 4 — Experience (`ENTRY_FIELDS['experience']`/`ENTRY_REQUIRED
/// ['experience']`, confirmed directly: company/title/start date required,
/// up to `MAX_ENTRIES`=20 entries). Reuses [ManualResumeEntryCard]/
/// [confirmRemoveEntry]/[ManualResumeMonthField] from the Manual Resume
/// Builder's own generic form widgets.
class CreateResumeExperienceStep extends ConsumerWidget {
  const CreateResumeExperienceStep({
    required this.entries,
    required this.serverErrors,
    super.key,
  });

  final List<CreateResumeExperienceEntry> entries;
  final List<CreateResumeValidationError> serverErrors;

  String? _errorFor(int index, String field) => serverErrors
      .where((e) => e.field == 'experience.$index.$field')
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
            title: entries[i].company.isEmpty
                ? 'Experience ${i + 1}'
                : entries[i].company,
            onRemove: () async {
              if (!entries[i].isBlank && !await confirmRemoveEntry(context, 'experience entry')) {
                return;
              }
              controller.removeExperience(i);
            },
            child: _ExperienceFields(
              entry: entries[i],
              errorFor: (field) => _errorFor(i, field),
              onChanged: (fn) => controller.updateExperience(i, fn),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: entries.length >= 20 ? null : controller.addExperience,
          icon: const Icon(Icons.add),
          label: const Text('Add experience'),
        ),
      ],
    );
  }
}

class _ExperienceFields extends StatelessWidget {
  const _ExperienceFields({
    required this.entry,
    required this.errorFor,
    required this.onChanged,
  });

  final CreateResumeExperienceEntry entry;
  final String? Function(String field) errorFor;
  final void Function(
    CreateResumeExperienceEntry Function(CreateResumeExperienceEntry),
  )
  onChanged;

  String _monthYear(String month, String year) =>
      year.isEmpty ? '' : '$year-${month.padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ManualResumeTextField(
          label: 'Company name',
          required: true,
          value: entry.company,
          errorText: errorFor('company'),
          onChanged: (v) => onChanged((e) => e.copyWith(company: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Job title',
          required: true,
          value: entry.title,
          errorText: errorFor('title'),
          onChanged: (v) => onChanged((e) => e.copyWith(title: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          initialValue: entry.type.isEmpty ? null : entry.type,
          decoration: const InputDecoration(
            labelText: 'Employment type',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            for (final t in _kEmploymentTypes)
              DropdownMenuItem(value: t, child: Text(t)),
          ],
          onChanged: (v) => onChanged((e) => e.copyWith(type: v ?? '')),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Location (optional)',
          value: entry.location,
          onChanged: (v) => onChanged((e) => e.copyWith(location: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeMonthField(
          label: 'Start month',
          value: _monthYear(entry.startMonth, entry.startYear),
          onChanged: (v) {
            final parts = v.split('-');
            onChanged(
              (e) => e.copyWith(startYear: parts[0], startMonth: parts[1]),
            );
          },
        ),
        if (errorFor('start_year') != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              errorFor('start_year')!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Currently working here'),
          value: entry.current,
          onChanged: (v) => onChanged((e) => e.copyWith(current: v ?? false)),
        ),
        if (!entry.current) ...[
          ManualResumeMonthField(
            label: 'End month',
            value: _monthYear(entry.endMonth, entry.endYear),
            onChanged: (v) {
              final parts = v.split('-');
              onChanged(
                (e) => e.copyWith(endYear: parts[0], endMonth: parts[1]),
              );
            },
          ),
          if (errorFor('end_year') != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                errorFor('end_year')!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Roles & responsibilities (one per line)',
          value: entry.responsibilities,
          maxLines: 4,
          errorText: errorFor('responsibilities'),
          onChanged: (v) => onChanged((e) => e.copyWith(responsibilities: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Projects handled (optional, one per line)',
          value: entry.projects,
          maxLines: 3,
          errorText: errorFor('projects'),
          onChanged: (v) => onChanged((e) => e.copyWith(projects: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Key achievements (optional, one per line)',
          value: entry.achievements,
          maxLines: 3,
          errorText: errorFor('achievements'),
          onChanged: (v) => onChanged((e) => e.copyWith(achievements: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Tools & technologies (optional)',
          value: entry.tools,
          errorText: errorFor('tools'),
          onChanged: (v) => onChanged((e) => e.copyWith(tools: v)),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
