import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/create_resume_state.dart';
import '../../domain/entities/create_resume_validation_error.dart';
import '../providers/resume_providers.dart';
import 'manual_resume_form_widgets.dart';

/// Step 7 — Certifications & Training
/// (`ENTRY_FIELDS['certifications']`/`ENTRY_REQUIRED['certifications']`,
/// confirmed directly against `career_app/create_resume.py:78-79,117-118,132`
/// and `static/js/create_resume.js:103-105`: `name`/`issuer` required, no
/// "current" flag — certifications have no ongoing state).
class CreateResumeCertificationsStep extends ConsumerWidget {
  const CreateResumeCertificationsStep({
    required this.entries,
    required this.serverErrors,
    super.key,
  });

  final List<CreateResumeCertificationEntry> entries;
  final List<CreateResumeValidationError> serverErrors;

  String? _errorFor(int index, String field) => serverErrors
      .where((e) => e.field == 'certifications.$index.$field')
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
            title: entries[i].name.isEmpty ? 'Certification ${i + 1}' : entries[i].name,
            onRemove: () async {
              if (!entries[i].isBlank && !await confirmRemoveEntry(context, 'certification entry')) {
                return;
              }
              controller.removeCertification(i);
            },
            child: _CertificationFields(
              entry: entries[i],
              errorFor: (field) => _errorFor(i, field),
              onChanged: (fn) => controller.updateCertification(i, fn),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: entries.length >= 20 ? null : controller.addCertification,
          icon: const Icon(Icons.add),
          label: Text(entries.isEmpty ? 'Add certification' : 'Add another certification'),
        ),
      ],
    );
  }
}

class _CertificationFields extends StatelessWidget {
  const _CertificationFields({
    required this.entry,
    required this.errorFor,
    required this.onChanged,
  });

  final CreateResumeCertificationEntry entry;
  final String? Function(String field) errorFor;
  final void Function(CreateResumeCertificationEntry Function(CreateResumeCertificationEntry)) onChanged;

  String _monthYear(String month, String year) =>
      year.isEmpty ? '' : '$year-${month.padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ManualResumeTextField(
          label: 'Certification / course name',
          required: true,
          value: entry.name,
          errorText: errorFor('name'),
          onChanged: (v) => onChanged((e) => e.copyWith(name: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Issuing organisation',
          required: true,
          value: entry.issuer,
          errorText: errorFor('issuer'),
          onChanged: (v) => onChanged((e) => e.copyWith(issuer: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Credential ID (optional)',
          value: entry.credentialId,
          errorText: errorFor('credential_id'),
          onChanged: (v) => onChanged((e) => e.copyWith(credentialId: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeMonthField(
          label: 'Issue month',
          value: _monthYear(entry.issueMonth, entry.issueYear),
          onChanged: (v) {
            final parts = v.split('-');
            onChanged((e) => e.copyWith(issueYear: parts[0], issueMonth: parts[1]));
          },
        ),
        if (errorFor('issue_year') != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              errorFor('issue_year')!,
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeMonthField(
          label: 'Expiry month (optional)',
          value: _monthYear(entry.expMonth, entry.expYear),
          onChanged: (v) {
            final parts = v.split('-');
            onChanged((e) => e.copyWith(expYear: parts[0], expMonth: parts[1]));
          },
        ),
        if (errorFor('exp_year') != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              errorFor('exp_year')!,
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Credential verification URL (optional)',
          value: entry.url,
          hint: 'https://',
          keyboardType: TextInputType.url,
          errorText: errorFor('url'),
          onChanged: (v) => onChanged((e) => e.copyWith(url: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Description (optional)',
          value: entry.description,
          maxLines: 2,
          errorText: errorFor('description'),
          onChanged: (v) => onChanged((e) => e.copyWith(description: v)),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
