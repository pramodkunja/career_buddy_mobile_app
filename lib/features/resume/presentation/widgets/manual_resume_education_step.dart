import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/manual_resume_draft.dart';
import '../../domain/entities/resume_role.dart';
import '../../domain/validation/manual_resume_validation.dart';
import '../providers/resume_providers.dart';
import 'manual_resume_form_widgets.dart';

bool _educationTouched(ManualResumeEducationEntry e) =>
    e.degree.isNotEmpty || e.institution.isNotEmpty || e.location.isNotEmpty || e.year.isNotEmpty || e.score.isNotEmpty;

bool _certTouched(ManualResumeCertificationEntry e) => e.name.isNotEmpty || e.issuer.isNotEmpty || e.year.isNotEmpty;

bool _trainingTouched(ManualResumeTrainingEntry e) => e.name.isNotEmpty || e.provider.isNotEmpty || e.year.isNotEmpty;

/// Step 4 — Education (verified, `landing.html:8598-8603`): education,
/// certifications, training — each a repeatable list capped at
/// [kMaxItems]. Certification/training suggestion chips come from the
/// role's own [ResumeRole.certifications] / the selected level's own
/// training suggestions and create a brand-new, named entry when tapped
/// (verified, `landing.html:8601-8602`).
class ManualResumeEducationStep extends ConsumerWidget {
  const ManualResumeEducationStep({
    required this.draft,
    required this.role,
    required this.visibleErrors,
    super.key,
  });

  final ManualResumeDraft draft;
  final ResumeRole? role;
  final List<ManualResumeValidationError> visibleErrors;

  String? _errorFor(String field) => visibleErrors.where((e) => e.field == field).map((e) => e.message).firstOrNull;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(manualResumeBuilderControllerProvider.notifier);
    final trainingSuggestions = draft.level.isEmpty ? const <String>[] : (role?.levels[draft.level]?.training ?? const []);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (_errorFor('education') != null) ...[
          Text(_errorFor('education')!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: AppSpacing.md),
        ],
        const Text('Education', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < draft.education.length; i++)
          ManualResumeEntryCard(
            title: draft.education[i].degree.isEmpty ? 'Education ${i + 1}' : draft.education[i].degree,
            onRemove: () async {
              if (_educationTouched(draft.education[i]) && !await confirmRemoveEntry(context, 'education entry')) return;
              controller.removeEducation(i);
            },
            child: Column(
              children: [
                ManualResumeTextField(
                  label: 'Degree / qualification',
                  value: draft.education[i].degree,
                  errorText: visibleErrors.where((e) => e.field == 'education.$i.degree').map((e) => e.message).firstOrNull,
                  onChanged: (v) => controller.updateEducation(i, (e) => e.copyWith(degree: v)),
                  onBlur: () => controller.markTouched('education.$i.degree'),
                ),
                const SizedBox(height: AppSpacing.sm),
                ManualResumeTextField(
                  label: 'Institution',
                  value: draft.education[i].institution,
                  onChanged: (v) => controller.updateEducation(i, (e) => e.copyWith(institution: v)),
                  onBlur: () => controller.markTouched('education.$i.institution'),
                ),
                const SizedBox(height: AppSpacing.sm),
                ManualResumeTextField(
                  label: 'Location',
                  value: draft.education[i].location,
                  onChanged: (v) => controller.updateEducation(i, (e) => e.copyWith(location: v)),
                  onBlur: () => controller.markTouched('education.$i.location'),
                ),
                const SizedBox(height: AppSpacing.sm),
                ManualResumeTextField(
                  label: 'Year / duration',
                  value: draft.education[i].year,
                  hint: 'e.g. 2019 – 2023',
                  onChanged: (v) => controller.updateEducation(i, (e) => e.copyWith(year: v)),
                  onBlur: () => controller.markTouched('education.$i.year'),
                ),
                const SizedBox(height: AppSpacing.sm),
                ManualResumeTextField(
                  label: 'Grade / CGPA',
                  value: draft.education[i].score,
                  onChanged: (v) => controller.updateEducation(i, (e) => e.copyWith(score: v)),
                  onBlur: () => controller.markTouched('education.$i.score'),
                ),
              ],
            ),
          ),
        if (draft.education.length < kMaxItems)
          OutlinedButton(onPressed: controller.addEducation, child: const Text('+ Add Education')),
        const SizedBox(height: AppSpacing.lg),
        const Text('Certifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < draft.certifications.length; i++)
          ManualResumeEntryCard(
            title: draft.certifications[i].name.isEmpty ? 'Certification ${i + 1}' : draft.certifications[i].name,
            onRemove: () async {
              if (_certTouched(draft.certifications[i]) && !await confirmRemoveEntry(context, 'certification')) return;
              controller.removeCertification(i);
            },
            child: Column(
              children: [
                ManualResumeTextField(
                  label: 'Certification',
                  value: draft.certifications[i].name,
                  errorText: visibleErrors
                      .where((e) => e.field == 'certifications.$i.name')
                      .map((e) => e.message)
                      .firstOrNull,
                  onChanged: (v) => controller.updateCertification(i, (e) => e.copyWith(name: v)),
                  onBlur: () => controller.markTouched('certifications.$i.name'),
                ),
                const SizedBox(height: AppSpacing.sm),
                ManualResumeTextField(
                  label: 'Issued by',
                  value: draft.certifications[i].issuer,
                  onChanged: (v) => controller.updateCertification(i, (e) => e.copyWith(issuer: v)),
                  onBlur: () => controller.markTouched('certifications.$i.issuer'),
                ),
                const SizedBox(height: AppSpacing.sm),
                ManualResumeTextField(
                  label: 'Year',
                  value: draft.certifications[i].year,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => controller.updateCertification(i, (e) => e.copyWith(year: v)),
                  onBlur: () => controller.markTouched('certifications.$i.year'),
                ),
              ],
            ),
          ),
        if (draft.certifications.length < kMaxItems)
          OutlinedButton(onPressed: controller.addCertification, child: const Text('+ Add Certification')),
        ManualResumeSuggestionRow(
          label: 'Suggested certifications for this role',
          options: role?.certifications ?? const [],
          onTap: controller.addCertificationNamed,
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text('Training', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < draft.training.length; i++)
          ManualResumeEntryCard(
            title: draft.training[i].name.isEmpty ? 'Training ${i + 1}' : draft.training[i].name,
            onRemove: () async {
              if (_trainingTouched(draft.training[i]) && !await confirmRemoveEntry(context, 'training entry')) return;
              controller.removeTraining(i);
            },
            child: Column(
              children: [
                ManualResumeTextField(
                  label: 'Training / course',
                  value: draft.training[i].name,
                  errorText:
                      visibleErrors.where((e) => e.field == 'training.$i.name').map((e) => e.message).firstOrNull,
                  onChanged: (v) => controller.updateTraining(i, (e) => e.copyWith(name: v)),
                  onBlur: () => controller.markTouched('training.$i.name'),
                ),
                const SizedBox(height: AppSpacing.sm),
                ManualResumeTextField(
                  label: 'Provider',
                  value: draft.training[i].provider,
                  onChanged: (v) => controller.updateTraining(i, (e) => e.copyWith(provider: v)),
                  onBlur: () => controller.markTouched('training.$i.provider'),
                ),
                const SizedBox(height: AppSpacing.sm),
                ManualResumeTextField(
                  label: 'Year',
                  value: draft.training[i].year,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => controller.updateTraining(i, (e) => e.copyWith(year: v)),
                  onBlur: () => controller.markTouched('training.$i.year'),
                ),
              ],
            ),
          ),
        if (draft.training.length < kMaxItems)
          OutlinedButton(onPressed: controller.addTraining, child: const Text('+ Add Training')),
        ManualResumeSuggestionRow(label: 'Suggested training', options: trainingSuggestions, onTap: controller.addTrainingNamed),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
