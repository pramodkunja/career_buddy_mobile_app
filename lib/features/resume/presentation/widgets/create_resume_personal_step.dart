import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/create_resume_state.dart';
import '../../domain/entities/create_resume_validation_error.dart';
import '../providers/resume_providers.dart';
import 'manual_resume_form_widgets.dart';

/// Step 1 — Personal (`PERSONAL_FIELDS`/`PERSONAL_REQUIRED`, confirmed
/// directly against `career_app/create_resume.py`). Reuses [ManualResumeTextField]
/// from the Manual Resume Builder's own widget file — its behavior (a
/// labelled, blur-tracking text field with an optional error) is generic,
/// not specific to that feature, so duplicating it here would only add
/// unnecessary maintenance surface.
class CreateResumePersonalStep extends ConsumerWidget {
  const CreateResumePersonalStep({
    required this.personal,
    required this.serverErrors,
    super.key,
  });

  final CreateResumePersonalInfo personal;
  final List<CreateResumeValidationError> serverErrors;

  String? _errorFor(String field) {
    for (final e in serverErrors) {
      if (e.field == 'personal.$field') return e.message;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(createResumeBuilderControllerProvider.notifier);
    void update(
      CreateResumePersonalInfo Function(CreateResumePersonalInfo) fn,
    ) => controller.updatePersonal(fn);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        ManualResumeTextField(
          label: 'Full name',
          required: true,
          value: personal.name,
          errorText: _errorFor('name'),
          onChanged: (v) => update((p) => p.copyWith(name: v)),
        ),
        const SizedBox(height: AppSpacing.md),
        ManualResumeTextField(
          label: 'Professional title / target role',
          required: true,
          value: personal.title,
          hint: 'e.g. Senior Backend Engineer',
          errorText: _errorFor('title'),
          onChanged: (v) => update((p) => p.copyWith(title: v)),
        ),
        const SizedBox(height: AppSpacing.md),
        ManualResumeTextField(
          label: 'Email',
          required: true,
          value: personal.email,
          keyboardType: TextInputType.emailAddress,
          errorText: _errorFor('email'),
          onChanged: (v) => update((p) => p.copyWith(email: v)),
        ),
        const SizedBox(height: AppSpacing.md),
        ManualResumeTextField(
          label: 'Phone',
          required: true,
          value: personal.phone,
          hint: '+91 98765 43210',
          keyboardType: TextInputType.phone,
          errorText: _errorFor('phone'),
          onChanged: (v) => update((p) => p.copyWith(phone: v)),
        ),
        const SizedBox(height: AppSpacing.md),
        ManualResumeTextField(
          label: 'City',
          required: true,
          value: personal.city,
          errorText: _errorFor('city'),
          onChanged: (v) => update((p) => p.copyWith(city: v)),
        ),
        const SizedBox(height: AppSpacing.md),
        ManualResumeTextField(
          label: 'State',
          required: true,
          value: personal.state,
          errorText: _errorFor('state'),
          onChanged: (v) => update((p) => p.copyWith(state: v)),
        ),
        const SizedBox(height: AppSpacing.md),
        ManualResumeTextField(
          label: 'Country',
          required: true,
          value: personal.country,
          errorText: _errorFor('country'),
          onChanged: (v) => update((p) => p.copyWith(country: v)),
        ),
        const SizedBox(height: AppSpacing.md),
        ManualResumeTextField(
          label: 'Full address (optional)',
          value: personal.address,
          maxLines: 2,
          errorText: _errorFor('address'),
          onChanged: (v) => update((p) => p.copyWith(address: v)),
        ),
        const SizedBox(height: AppSpacing.md),
        ManualResumeTextField(
          label: 'LinkedIn (optional)',
          value: personal.linkedin,
          hint: 'linkedin.com/in/your-name',
          errorText: _errorFor('linkedin'),
          onChanged: (v) => update((p) => p.copyWith(linkedin: v)),
        ),
        const SizedBox(height: AppSpacing.md),
        ManualResumeTextField(
          label: 'GitHub (optional)',
          value: personal.github,
          hint: 'github.com/your-name',
          errorText: _errorFor('github'),
          onChanged: (v) => update((p) => p.copyWith(github: v)),
        ),
        const SizedBox(height: AppSpacing.md),
        ManualResumeTextField(
          label: 'Portfolio (optional)',
          value: personal.portfolio,
          errorText: _errorFor('portfolio'),
          onChanged: (v) => update((p) => p.copyWith(portfolio: v)),
        ),
        const SizedBox(height: AppSpacing.md),
        ManualResumeTextField(
          label: 'Website (optional)',
          value: personal.website,
          errorText: _errorFor('website'),
          onChanged: (v) => update((p) => p.copyWith(website: v)),
        ),
      ],
    );
  }
}
