import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/create_resume_state.dart';
import '../../domain/entities/create_resume_validation_error.dart';
import '../providers/resume_providers.dart';
import 'manual_resume_form_widgets.dart';

/// Step 9 — Internships & Volunteering: **one real tab on the site holding
/// two separate repeatable lists**, confirmed directly
/// (`static/js/create_resume.js:384-385`, two `<h4 class="cr-sub">`
/// sub-headings — "Internships" then "Volunteering" — under one tab, not
/// two tabs; `SECTION_OF['volunteering'] == 'internships'`,
/// `career_app/create_resume.py:138`, routes volunteering's own server
/// errors to this same tab). Building this as two separate top-level steps
/// would invent a tab structure the real site doesn't have.
///
/// Internships (`ENTRY_FIELDS['internships']`/`ENTRY_REQUIRED['internships']`,
/// `create_resume.py:82-85,120-121,134`): organization/title/start_year
/// required, same "end date required unless ongoing" rule as Experience.
/// Volunteering (`ENTRY_FIELDS['volunteering']`/`ENTRY_REQUIRED['volunteering']`,
/// `create_resume.py:86-88,122-123,135`): organization/role required —
/// unlike Internships, no end-date-required rule (confirmed: `volunteering`
/// is not in `END_REQUIRED`).
class CreateResumeInternshipsVolunteeringStep extends ConsumerWidget {
  const CreateResumeInternshipsVolunteeringStep({
    required this.internships,
    required this.volunteering,
    required this.serverErrors,
    super.key,
  });

  final List<CreateResumeInternshipEntry> internships;
  final List<CreateResumeVolunteeringEntry> volunteering;
  final List<CreateResumeValidationError> serverErrors;

  String? _internshipErrorFor(int index, String field) => serverErrors
      .where((e) => e.field == 'internships.$index.$field')
      .map((e) => e.message)
      .firstOrNull;

  String? _volunteeringErrorFor(int index, String field) => serverErrors
      .where((e) => e.field == 'volunteering.$index.$field')
      .map((e) => e.message)
      .firstOrNull;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(createResumeBuilderControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // `create_resume.js:384`'s own help text for this tab, verbatim.
        const Text(
          'Both optional — they only appear on your resume when filled in.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text('Internships', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < internships.length; i++)
          ManualResumeEntryCard(
            title: internships[i].title.isEmpty ? 'Internship ${i + 1}' : internships[i].title,
            onRemove: () async {
              if (!internships[i].isBlank && !await confirmRemoveEntry(context, 'internship entry')) {
                return;
              }
              controller.removeInternship(i);
            },
            child: _InternshipFields(
              entry: internships[i],
              errorFor: (field) => _internshipErrorFor(i, field),
              onChanged: (fn) => controller.updateInternship(i, fn),
            ),
          ),
        OutlinedButton.icon(
          onPressed: internships.length >= 20 ? null : controller.addInternship,
          icon: const Icon(Icons.add),
          label: Text(internships.isEmpty ? 'Add internship' : 'Add another internship'),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text('Volunteering', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < volunteering.length; i++)
          ManualResumeEntryCard(
            title: volunteering[i].organization.isEmpty
                ? 'Volunteering ${i + 1}'
                : volunteering[i].organization,
            onRemove: () async {
              if (!volunteering[i].isBlank && !await confirmRemoveEntry(context, 'volunteering entry')) {
                return;
              }
              controller.removeVolunteering(i);
            },
            child: _VolunteeringFields(
              entry: volunteering[i],
              errorFor: (field) => _volunteeringErrorFor(i, field),
              onChanged: (fn) => controller.updateVolunteering(i, fn),
            ),
          ),
        OutlinedButton.icon(
          onPressed: volunteering.length >= 20 ? null : controller.addVolunteering,
          icon: const Icon(Icons.add),
          label: Text(volunteering.isEmpty ? 'Add volunteering' : 'Add another volunteering entry'),
        ),
      ],
    );
  }
}

class _InternshipFields extends StatelessWidget {
  const _InternshipFields({
    required this.entry,
    required this.errorFor,
    required this.onChanged,
  });

  final CreateResumeInternshipEntry entry;
  final String? Function(String field) errorFor;
  final void Function(CreateResumeInternshipEntry Function(CreateResumeInternshipEntry)) onChanged;

  String _monthYear(String month, String year) =>
      year.isEmpty ? '' : '$year-${month.padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ManualResumeTextField(
          label: 'Organisation',
          required: true,
          value: entry.organization,
          errorText: errorFor('organization'),
          onChanged: (v) => onChanged((e) => e.copyWith(organization: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Internship title',
          required: true,
          value: entry.title,
          errorText: errorFor('title'),
          onChanged: (v) => onChanged((e) => e.copyWith(title: v)),
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
          title: const Text('Ongoing internship'),
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
          label: 'Responsibilities (optional, one per line)',
          value: entry.responsibilities,
          maxLines: 3,
          errorText: errorFor('responsibilities'),
          onChanged: (v) => onChanged((e) => e.copyWith(responsibilities: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Projects (optional, one per line)',
          value: entry.projects,
          maxLines: 2,
          errorText: errorFor('projects'),
          onChanged: (v) => onChanged((e) => e.copyWith(projects: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Skills & tools used (optional)',
          value: entry.skills,
          errorText: errorFor('skills'),
          onChanged: (v) => onChanged((e) => e.copyWith(skills: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Achievements (optional, one per line)',
          value: entry.achievements,
          maxLines: 2,
          errorText: errorFor('achievements'),
          onChanged: (v) => onChanged((e) => e.copyWith(achievements: v)),
        ),
      ],
    );
  }
}

class _VolunteeringFields extends StatelessWidget {
  const _VolunteeringFields({
    required this.entry,
    required this.errorFor,
    required this.onChanged,
  });

  final CreateResumeVolunteeringEntry entry;
  final String? Function(String field) errorFor;
  final void Function(CreateResumeVolunteeringEntry Function(CreateResumeVolunteeringEntry)) onChanged;

  String _monthYear(String month, String year) =>
      year.isEmpty ? '' : '$year-${month.padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ManualResumeTextField(
          label: 'Organisation',
          required: true,
          value: entry.organization,
          errorText: errorFor('organization'),
          onChanged: (v) => onChanged((e) => e.copyWith(organization: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Role',
          required: true,
          value: entry.role,
          errorText: errorFor('role'),
          onChanged: (v) => onChanged((e) => e.copyWith(role: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Location (optional)',
          value: entry.location,
          onChanged: (v) => onChanged((e) => e.copyWith(location: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeMonthField(
          label: 'Start month (optional)',
          value: _monthYear(entry.startMonth, entry.startYear),
          onChanged: (v) {
            final parts = v.split('-');
            onChanged((e) => e.copyWith(startYear: parts[0], startMonth: parts[1]));
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Currently volunteering'),
          value: entry.current,
          onChanged: (v) => onChanged((e) => e.copyWith(current: v ?? false)),
        ),
        if (!entry.current)
          ManualResumeMonthField(
            label: 'End month (optional)',
            value: _monthYear(entry.endMonth, entry.endYear),
            onChanged: (v) {
              final parts = v.split('-');
              onChanged((e) => e.copyWith(endYear: parts[0], endMonth: parts[1]));
            },
          ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Responsibilities (optional, one per line)',
          value: entry.responsibilities,
          maxLines: 2,
          errorText: errorFor('responsibilities'),
          onChanged: (v) => onChanged((e) => e.copyWith(responsibilities: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Contributions (optional, one per line)',
          value: entry.contributions,
          maxLines: 2,
          errorText: errorFor('contributions'),
          onChanged: (v) => onChanged((e) => e.copyWith(contributions: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Achievements (optional, one per line)',
          value: entry.achievements,
          maxLines: 2,
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
