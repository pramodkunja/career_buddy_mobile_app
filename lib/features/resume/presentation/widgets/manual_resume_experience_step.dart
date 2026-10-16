import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/manual_resume_draft.dart';
import '../../domain/entities/resume_role.dart';
import '../../domain/validation/manual_resume_validation.dart';
import '../providers/resume_providers.dart';
import 'manual_resume_form_widgets.dart';

bool _jobTouched(ManualResumeJobEntry e) =>
    e.title.isNotEmpty || e.company.isNotEmpty || e.location.isNotEmpty || e.start.isNotEmpty || e.end.isNotEmpty || e.bullets.isNotEmpty;

bool _projectTouched(ManualResumeProjectEntry e) =>
    e.name.isNotEmpty || e.context.isNotEmpty || e.tools.isNotEmpty || e.start.isNotEmpty || e.end.isNotEmpty || e.bullets.isNotEmpty;

/// Step 3 — Experience (verified, `landing.html:8588-8597`): employment,
/// internships and projects, each a repeatable list capped at
/// [kMaxItems] (15). Section order mirrors the real builder's own
/// level-dependent order (fresher: Projects/Internships/Employment;
/// everyone else: Employment/Projects/Internships, `landing.html:8589-8596`).
class ManualResumeExperienceStep extends ConsumerWidget {
  const ManualResumeExperienceStep({
    required this.draft,
    required this.role,
    required this.visibleErrors,
    super.key,
  });

  final ManualResumeDraft draft;
  final ResumeRole? role;
  final List<ManualResumeValidationError> visibleErrors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(manualResumeBuilderControllerProvider.notifier);
    final levelSuggestions = draft.level.isEmpty ? null : role?.levels[draft.level];
    final employmentError = visibleErrors.where((e) => e.field == 'employment' && e.step == kStepExperience).firstOrNull;

    final employmentSection = _JobListSection(
      title: 'Employment',
      addLabel: '+ Add Employment',
      entries: draft.employment,
      visibleErrors: visibleErrors,
      fieldPrefix: 'employment',
      suggestions: levelSuggestions?.responsibilities ?? const [],
      onAdd: controller.addEmployment,
      onRemove: controller.removeEmployment,
      onUpdate: controller.updateEmployment,
      onTouch: controller.markTouched,
      onSuggestionTap: controller.appendEmploymentBulletSuggestion,
    );
    final internshipSection = _JobListSection(
      title: 'Internships',
      addLabel: '+ Add Internship',
      entries: draft.internships,
      visibleErrors: visibleErrors,
      fieldPrefix: 'internships',
      suggestions: levelSuggestions?.responsibilities ?? const [],
      onAdd: controller.addInternship,
      onRemove: controller.removeInternship,
      onUpdate: controller.updateInternship,
      onTouch: controller.markTouched,
      onSuggestionTap: controller.appendInternshipBulletSuggestion,
    );
    final projectSection = _ProjectListSection(
      entries: draft.projects,
      visibleErrors: visibleErrors,
      projectIdeas: draft.level == 'fresher' ? (levelSuggestions?.projects ?? const []) : const [],
      onAdd: controller.addProject,
      onAddNamed: controller.addProjectNamed,
      onRemove: controller.removeProject,
      onUpdate: controller.updateProject,
      onTouch: controller.markTouched,
    );

    final sections = draft.level == 'fresher'
        ? [projectSection, internshipSection, employmentSection]
        : [employmentSection, projectSection, internshipSection];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (employmentError != null) ...[
          Text(employmentError.message, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: AppSpacing.md),
        ],
        for (final section in sections) ...[section, const SizedBox(height: AppSpacing.lg)],
      ],
    );
  }
}

class _JobListSection extends StatelessWidget {
  const _JobListSection({
    required this.title,
    required this.addLabel,
    required this.entries,
    required this.visibleErrors,
    required this.fieldPrefix,
    required this.suggestions,
    required this.onAdd,
    required this.onRemove,
    required this.onUpdate,
    required this.onTouch,
    required this.onSuggestionTap,
  });

  final String title;
  final String addLabel;
  final List<ManualResumeJobEntry> entries;
  final List<ManualResumeValidationError> visibleErrors;
  final String fieldPrefix;
  final List<String> suggestions;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final void Function(int, ManualResumeJobEntry Function(ManualResumeJobEntry)) onUpdate;
  final void Function(String) onTouch;
  final void Function(int, String) onSuggestionTap;

  String? _errorFor(int index, String field) =>
      visibleErrors.where((e) => e.field == '$fieldPrefix.$index.$field').map((e) => e.message).firstOrNull;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < entries.length; i++)
          ManualResumeEntryCard(
            title: entries[i].title.isEmpty ? '$title ${i + 1}' : entries[i].title,
            onRemove: () async {
              if (_jobTouched(entries[i]) && !await confirmRemoveEntry(context, title.toLowerCase())) return;
              onRemove(i);
            },
            child: Column(
              children: [
                ManualResumeTextField(
                  label: 'Job title',
                  value: entries[i].title,
                  errorText: _errorFor(i, 'title'),
                  onChanged: (v) => onUpdate(i, (e) => e.copyWith(title: v)),
                  onBlur: () => onTouch('$fieldPrefix.$i.title'),
                ),
                const SizedBox(height: AppSpacing.sm),
                ManualResumeTextField(
                  label: 'Company',
                  value: entries[i].company,
                  errorText: _errorFor(i, 'company'),
                  onChanged: (v) => onUpdate(i, (e) => e.copyWith(company: v)),
                  onBlur: () => onTouch('$fieldPrefix.$i.company'),
                ),
                const SizedBox(height: AppSpacing.sm),
                ManualResumeTextField(
                  label: 'Location',
                  value: entries[i].location,
                  errorText: _errorFor(i, 'location'),
                  onChanged: (v) => onUpdate(i, (e) => e.copyWith(location: v)),
                  onBlur: () => onTouch('$fieldPrefix.$i.location'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: ManualResumeMonthField(
                        label: 'Start',
                        value: entries[i].start,
                        onChanged: (v) => onUpdate(i, (e) => e.copyWith(start: v)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ManualResumeMonthField(
                        label: 'End',
                        value: entries[i].end,
                        enabled: !entries[i].current,
                        onChanged: (v) => onUpdate(i, (e) => e.copyWith(end: v)),
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  key: Key('$fieldPrefix-$i-current'),
                  value: entries[i].current,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Current / Ongoing'),
                  onChanged: (v) => onUpdate(i, (e) => e.copyWith(current: v ?? false)),
                ),
                ManualResumeTextField(
                  label: 'Responsibilities & achievements (one per line)',
                  value: entries[i].bullets,
                  maxLines: 5,
                  maxLength: 1500,
                  errorText: _errorFor(i, 'bullets'),
                  onChanged: (v) => onUpdate(i, (e) => e.copyWith(bullets: v)),
                  onBlur: () => onTouch('$fieldPrefix.$i.bullets'),
                ),
                ManualResumeSuggestionRow(
                  label: 'Suggested responsibilities',
                  options: suggestions,
                  onTap: (s) => onSuggestionTap(i, s),
                ),
              ],
            ),
          ),
        if (entries.length < kMaxItems) OutlinedButton(onPressed: onAdd, child: Text(addLabel)),
      ],
    );
  }
}

class _ProjectListSection extends StatelessWidget {
  const _ProjectListSection({
    required this.entries,
    required this.visibleErrors,
    required this.projectIdeas,
    required this.onAdd,
    required this.onAddNamed,
    required this.onRemove,
    required this.onUpdate,
    required this.onTouch,
  });

  final List<ManualResumeProjectEntry> entries;
  final List<ManualResumeValidationError> visibleErrors;
  final List<String> projectIdeas;
  final VoidCallback onAdd;
  final void Function(String) onAddNamed;
  final void Function(int) onRemove;
  final void Function(int, ManualResumeProjectEntry Function(ManualResumeProjectEntry)) onUpdate;
  final void Function(String) onTouch;

  String? _errorFor(int index, String field) =>
      visibleErrors.where((e) => e.field == 'projects.$index.$field').map((e) => e.message).firstOrNull;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Projects', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < entries.length; i++)
          ManualResumeEntryCard(
            title: entries[i].name.isEmpty ? 'Project ${i + 1}' : entries[i].name,
            onRemove: () async {
              if (_projectTouched(entries[i]) && !await confirmRemoveEntry(context, 'project')) return;
              onRemove(i);
            },
            child: Column(
              children: [
                ManualResumeTextField(
                  label: 'Project name',
                  value: entries[i].name,
                  errorText: _errorFor(i, 'name'),
                  onChanged: (v) => onUpdate(i, (e) => e.copyWith(name: v)),
                  onBlur: () => onTouch('projects.$i.name'),
                ),
                const SizedBox(height: AppSpacing.sm),
                ManualResumeTextField(
                  label: 'Type / context',
                  value: entries[i].context,
                  errorText: _errorFor(i, 'context'),
                  onChanged: (v) => onUpdate(i, (e) => e.copyWith(context: v)),
                  onBlur: () => onTouch('projects.$i.context'),
                ),
                const SizedBox(height: AppSpacing.sm),
                ManualResumeTextField(
                  label: 'Tools / technologies',
                  value: entries[i].tools,
                  errorText: _errorFor(i, 'tools'),
                  onChanged: (v) => onUpdate(i, (e) => e.copyWith(tools: v)),
                  onBlur: () => onTouch('projects.$i.tools'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: ManualResumeMonthField(
                        label: 'Start',
                        value: entries[i].start,
                        onChanged: (v) => onUpdate(i, (e) => e.copyWith(start: v)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ManualResumeMonthField(
                        label: 'End',
                        value: entries[i].end,
                        onChanged: (v) => onUpdate(i, (e) => e.copyWith(end: v)),
                      ),
                    ),
                  ],
                ),
                ManualResumeTextField(
                  label: 'What you did and the result (one per line)',
                  value: entries[i].bullets,
                  maxLines: 5,
                  maxLength: 1200,
                  errorText: _errorFor(i, 'bullets'),
                  onChanged: (v) => onUpdate(i, (e) => e.copyWith(bullets: v)),
                  onBlur: () => onTouch('projects.$i.bullets'),
                ),
              ],
            ),
          ),
        if (entries.length < kMaxItems) OutlinedButton(onPressed: onAdd, child: const Text('+ Add Project')),
        ManualResumeSuggestionRow(label: 'Project ideas', options: projectIdeas, onTap: onAddNamed),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
