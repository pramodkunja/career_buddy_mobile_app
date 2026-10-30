import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/create_resume_state.dart';
import '../../domain/entities/create_resume_validation_error.dart';
import '../providers/resume_providers.dart';
import 'manual_resume_form_widgets.dart';

/// `PROJECT_TYPES` (`static/js/create_resume.js:100`), confirmed directly.
const List<String> _kProjectTypes = [
  'Academic Project',
  'Personal Project',
  'Professional Project',
  'Internship Project',
  'Research Project',
  'Other',
];

/// Step 6 — Projects (`ENTRY_FIELDS['projects']`/`ENTRY_REQUIRED['projects']`,
/// confirmed directly against `career_app/create_resume.py:74-77,115-116,131`
/// and `static/js/create_resume.js:99-102`: only `title` required, up to
/// `MAX_ENTRIES`=20 entries). Reuses the same shared entry-card widgets the
/// Experience/Education steps already use.
class CreateResumeProjectsStep extends ConsumerWidget {
  const CreateResumeProjectsStep({
    required this.entries,
    required this.serverErrors,
    super.key,
  });

  final List<CreateResumeProjectEntry> entries;
  final List<CreateResumeValidationError> serverErrors;

  String? _errorFor(int index, String field) => serverErrors
      .where((e) => e.field == 'projects.$index.$field')
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
            title: entries[i].title.isEmpty ? 'Project ${i + 1}' : entries[i].title,
            onRemove: () async {
              if (!entries[i].isBlank && !await confirmRemoveEntry(context, 'project entry')) {
                return;
              }
              controller.removeProject(i);
            },
            child: _ProjectFields(
              entry: entries[i],
              errorFor: (field) => _errorFor(i, field),
              onChanged: (fn) => controller.updateProject(i, fn),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: entries.length >= 20 ? null : controller.addProject,
          icon: const Icon(Icons.add),
          label: Text(entries.isEmpty ? 'Add project' : 'Add another project'),
        ),
      ],
    );
  }
}

class _ProjectFields extends StatelessWidget {
  const _ProjectFields({
    required this.entry,
    required this.errorFor,
    required this.onChanged,
  });

  final CreateResumeProjectEntry entry;
  final String? Function(String field) errorFor;
  final void Function(CreateResumeProjectEntry Function(CreateResumeProjectEntry)) onChanged;

  String _monthYear(String month, String year) =>
      year.isEmpty ? '' : '$year-${month.padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ManualResumeTextField(
          label: 'Project title',
          required: true,
          value: entry.title,
          errorText: errorFor('title'),
          onChanged: (v) => onChanged((e) => e.copyWith(title: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          initialValue: entry.type.isEmpty ? null : entry.type,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Project type',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            for (final t in _kProjectTypes) DropdownMenuItem(value: t, child: Text(t)),
          ],
          onChanged: (v) => onChanged((e) => e.copyWith(type: v ?? '')),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Organisation / institution (optional)',
          value: entry.organization,
          onChanged: (v) => onChanged((e) => e.copyWith(organization: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeMonthField(
          label: 'Start month',
          value: _monthYear(entry.startMonth, entry.startYear),
          onChanged: (v) {
            final parts = v.split('-');
            onChanged((e) => e.copyWith(startYear: parts[0], startMonth: parts[1]));
          },
        ),
        if (errorFor('start_year') != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              errorFor('start_year')!,
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Ongoing project'),
          value: entry.current,
          onChanged: (v) => onChanged((e) => e.copyWith(current: v ?? false)),
        ),
        if (!entry.current) ...[
          ManualResumeMonthField(
            label: 'End month',
            value: _monthYear(entry.endMonth, entry.endYear),
            onChanged: (v) {
              final parts = v.split('-');
              onChanged((e) => e.copyWith(endYear: parts[0], endMonth: parts[1]));
            },
          ),
          if (errorFor('end_year') != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                errorFor('end_year')!,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Project overview (optional)',
          value: entry.overview,
          maxLines: 3,
          errorText: errorFor('overview'),
          onChanged: (v) => onChanged((e) => e.copyWith(overview: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Your role (optional)',
          value: entry.role,
          errorText: errorFor('role'),
          onChanged: (v) => onChanged((e) => e.copyWith(role: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Project URL (optional)',
          value: entry.url,
          hint: 'https://',
          keyboardType: TextInputType.url,
          errorText: errorFor('url'),
          onChanged: (v) => onChanged((e) => e.copyWith(url: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Responsibilities (optional, one per line)',
          value: entry.responsibilities,
          maxLines: 3,
          errorText: errorFor('responsibilities'),
          onChanged: (v) => onChanged((e) => e.copyWith(responsibilities: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Technologies / tools used (optional)',
          value: entry.technologies,
          errorText: errorFor('technologies'),
          onChanged: (v) => onChanged((e) => e.copyWith(technologies: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Outcomes (optional, one per line)',
          value: entry.outcomes,
          maxLines: 2,
          errorText: errorFor('outcomes'),
          onChanged: (v) => onChanged((e) => e.copyWith(outcomes: v)),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
