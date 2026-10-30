import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/create_resume_state.dart';
import '../../domain/entities/create_resume_validation_error.dart';
import '../providers/resume_providers.dart';
import 'manual_resume_form_widgets.dart';

/// `LANGUAGE_PROFICIENCY` (`static/js/create_resume.js:387`), confirmed
/// directly.
const List<String> _kProficiencyLevels = [
  'Basic',
  'Conversational',
  'Intermediate',
  'Professional',
  'Native',
];

/// `ADDITIONAL_FIELDS`'s 6 keys, in order (`career_app/create_resume.py:29-31`),
/// paired with the real builder's own FORM-LABEL text
/// (`static/js/create_resume.js:72-73` — note this differs in casing from
/// the Python tuple's labels, which are used for the final document's
/// section labels instead; both are real, confirmed directly, not a
/// discrepancy to reconcile).
const List<(String key, String label)> _kAdditionalFields = [
  ('memberships', 'Professional memberships (one point per line)'),
  ('publications', 'Publications (one point per line)'),
  ('research', 'Research (one point per line)'),
  ('activities', 'Extracurricular activities (one point per line)'),
  ('hobbies', 'Hobbies & interests (one point per line)'),
  ('other', 'Other relevant information (one point per line)'),
];

/// Step 10 — Languages & Additional Information: **one real tab holding a
/// repeatable Languages list plus 6 flat optional fields**, confirmed
/// directly (`static/js/create_resume.js:386-398`, two `<h4 class="cr-sub">`
/// sub-headings under one tab). Languages
/// (`ENTRY_FIELDS['languages']`/`ENTRY_REQUIRED['languages']`,
/// `create_resume.py:89,124,136`) is the only repeatable section where the
/// select (`proficiency`), not just the free-text field, is required for
/// completeness, and renders as a simple always-visible row rather than the
/// shared collapsible entry-card other repeatable sections use (confirmed:
/// a bespoke renderer, not `entryList()`). Additional Information
/// (`ADDITIONAL_FIELDS`/`ADDITIONAL_RULES`, `create_resume.py:29-31,91-95`)
/// is a flat dict, not a repeatable list — no add/remove, no requiredness.
class CreateResumeLanguagesAdditionalStep extends ConsumerWidget {
  const CreateResumeLanguagesAdditionalStep({
    required this.languages,
    required this.additional,
    required this.serverErrors,
    super.key,
  });

  final List<CreateResumeLanguageEntry> languages;
  final CreateResumeAdditionalInfo additional;
  final List<CreateResumeValidationError> serverErrors;

  String? _languageErrorFor(int index, String field) => serverErrors
      .where((e) => e.field == 'languages.$index.$field')
      .map((e) => e.message)
      .firstOrNull;

  String? _additionalErrorFor(String field) => serverErrors
      .where((e) => e.field == 'additional.$field')
      .map((e) => e.message)
      .firstOrNull;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(createResumeBuilderControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const Text('Languages', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 4),
        // `create_resume.js:395`'s own help text, verbatim.
        const Text(
          'All optional. Empty items never appear on your resume.',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < languages.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ManualResumeTextField(
                    label: 'Language',
                    required: true,
                    value: languages[i].name,
                    errorText: _languageErrorFor(i, 'name'),
                    onChanged: (v) => controller.updateLanguage(i, (e) => e.copyWith(name: v)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: languages[i].proficiency.isEmpty ? null : languages[i].proficiency,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Proficiency *',
                      errorText: _languageErrorFor(i, 'proficiency'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final level in _kProficiencyLevels)
                        DropdownMenuItem(value: level, child: Text(level)),
                    ],
                    onChanged: (v) =>
                        controller.updateLanguage(i, (e) => e.copyWith(proficiency: v ?? '')),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove',
                  onPressed: () async {
                    if (!languages[i].isBlank && !await confirmRemoveEntry(context, 'language')) {
                      return;
                    }
                    controller.removeLanguage(i);
                  },
                ),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: languages.length >= 20 ? null : controller.addLanguage,
          icon: const Icon(Icons.add),
          label: const Text('Add language'),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text('Additional information', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: AppSpacing.sm),
        for (final (key, label) in _kAdditionalFields)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ManualResumeTextField(
              label: label,
              value: switch (key) {
                'memberships' => additional.memberships,
                'publications' => additional.publications,
                'research' => additional.research,
                'activities' => additional.activities,
                'hobbies' => additional.hobbies,
                _ => additional.other,
              },
              maxLines: 2,
              errorText: _additionalErrorFor(key),
              onChanged: (v) => controller.updateAdditional(
                (a) => switch (key) {
                  'memberships' => a.copyWith(memberships: v),
                  'publications' => a.copyWith(publications: v),
                  'research' => a.copyWith(research: v),
                  'activities' => a.copyWith(activities: v),
                  'hobbies' => a.copyWith(hobbies: v),
                  _ => a.copyWith(other: v),
                },
              ),
            ),
          ),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
