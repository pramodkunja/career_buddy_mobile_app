import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/create_resume_state.dart';
import '../../domain/entities/create_resume_validation_error.dart';
import '../providers/resume_providers.dart';
import 'manual_resume_form_widgets.dart';

/// `QUALIFICATIONS`, confirmed directly against `career_app/create_resume.py`.
const List<String> _kQualifications = [
  'PhD',
  "Master's Degree",
  "Bachelor's Degree",
  'Diploma',
  'Higher Secondary',
  'Secondary School',
  'Other', //
];

/// Step 5 — Education (`ENTRY_FIELDS['education']`/`ENTRY_REQUIRED
/// ['education']`, confirmed directly: qualification/institution required,
/// year-only dates — this section has no month fields, unlike Experience).
class CreateResumeEducationStep extends ConsumerWidget {
  const CreateResumeEducationStep({
    required this.entries,
    required this.serverErrors,
    super.key,
  });

  final List<CreateResumeEducationEntry> entries;
  final List<CreateResumeValidationError> serverErrors;

  String? _errorFor(int index, String field) => serverErrors
      .where((e) => e.field == 'education.$index.$field')
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
            title: entries[i].institution.isEmpty
                ? 'Education ${i + 1}'
                : entries[i].institution,
            onRemove: () async {
              if (!entries[i].isBlank && !await confirmRemoveEntry(context, 'education entry')) {
                return;
              }
              controller.removeEducation(i);
            },
            child: _EducationFields(
              entry: entries[i],
              errorFor: (field) => _errorFor(i, field),
              onChanged: (fn) => controller.updateEducation(i, fn),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: entries.length >= 20 ? null : controller.addEducation,
          icon: const Icon(Icons.add),
          label: const Text('Add education'),
        ),
      ],
    );
  }
}

class _YearField extends StatelessWidget {
  const _YearField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final years = [for (var y = DateTime.now().year + 10; y >= 1960; y--) y];
    return DropdownButtonFormField<int>(
      initialValue: int.tryParse(value),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final y in years) DropdownMenuItem(value: y, child: Text('$y')),
      ],
      onChanged: (y) => onChanged(y?.toString() ?? ''),
    );
  }
}

class _EducationFields extends StatelessWidget {
  const _EducationFields({
    required this.entry,
    required this.errorFor,
    required this.onChanged,
  });

  final CreateResumeEducationEntry entry;
  final String? Function(String field) errorFor;
  final void Function(
    CreateResumeEducationEntry Function(CreateResumeEducationEntry),
  )
  onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: entry.qualification.isEmpty
              ? null
              : entry.qualification,
          decoration: InputDecoration(
            labelText: 'Qualification *',
            border: const OutlineInputBorder(),
            isDense: true,
            errorText: errorFor('qualification'),
          ),
          items: [
            for (final q in _kQualifications)
              DropdownMenuItem(value: q, child: Text(q)),
          ],
          onChanged: (v) =>
              onChanged((e) => e.copyWith(qualification: v ?? '')),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Degree (optional)',
          value: entry.degree,
          onChanged: (v) => onChanged((e) => e.copyWith(degree: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Specialization (optional)',
          value: entry.specialization,
          onChanged: (v) => onChanged((e) => e.copyWith(specialization: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Institution',
          required: true,
          value: entry.institution,
          errorText: errorFor('institution'),
          onChanged: (v) => onChanged((e) => e.copyWith(institution: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'College location (optional)',
          value: entry.location,
          onChanged: (v) => onChanged((e) => e.copyWith(location: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        _YearField(
          label: 'Start year',
          value: entry.startYear,
          onChanged: (v) => onChanged((e) => e.copyWith(startYear: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Currently studying here'),
          value: entry.current,
          onChanged: (v) => onChanged((e) => e.copyWith(current: v ?? false)),
        ),
        if (!entry.current)
          _YearField(
            label: 'End year',
            value: entry.endYear,
            onChanged: (v) => onChanged((e) => e.copyWith(endYear: v)),
          ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Grade / GPA (optional)',
          value: entry.grade,
          onChanged: (v) => onChanged((e) => e.copyWith(grade: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Relevant coursework (optional)',
          value: entry.coursework,
          maxLines: 2,
          errorText: errorFor('coursework'),
          onChanged: (v) => onChanged((e) => e.copyWith(coursework: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Academic achievements (optional, one per line)',
          value: entry.achievements,
          maxLines: 3,
          errorText: errorFor('achievements'),
          onChanged: (v) => onChanged((e) => e.copyWith(achievements: v)),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
