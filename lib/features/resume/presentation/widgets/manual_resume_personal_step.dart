import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/manual_resume_draft.dart';
import '../../domain/validation/manual_resume_validation.dart';
import '../providers/resume_providers.dart';
import 'manual_resume_form_widgets.dart';

/// Step 1 — Personal (verified field list/order, `landing.html:8561-8571`):
/// full name, email, phone, location, LinkedIn, portfolio/website, date of
/// birth, passport number.
class ManualResumePersonalStep extends ConsumerWidget {
  const ManualResumePersonalStep({required this.draft, required this.visibleErrors, super.key});

  final ManualResumeDraft draft;
  final List<ManualResumeValidationError> visibleErrors;

  String? _errorFor(String field) => visibleErrors.where((e) => e.field == field).map((e) => e.message).firstOrNull;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(manualResumeBuilderControllerProvider.notifier);
    final p = draft.personal;

    void update(ManualResumePersonalInfo Function(ManualResumePersonalInfo) fn) => controller.updatePersonal(fn);
    void touch(String field) => controller.markTouched(field);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        ManualResumeTextField(
          label: 'Full name',
          required: true,
          value: p.name,
          errorText: _errorFor('personal.name'),
          onChanged: (v) => update((p) => p.copyWith(name: v)),
          onBlur: () => touch('personal.name'),
        ),
        const SizedBox(height: AppSpacing.md),
        ManualResumeTextField(
          label: 'Email',
          required: true,
          value: p.email,
          keyboardType: TextInputType.emailAddress,
          errorText: _errorFor('personal.email'),
          onChanged: (v) => update((p) => p.copyWith(email: v)),
          onBlur: () => touch('personal.email'),
        ),
        const SizedBox(height: AppSpacing.md),
        ManualResumeTextField(
          label: 'Phone',
          required: true,
          value: p.phone,
          hint: '+91 98765 43210',
          keyboardType: TextInputType.phone,
          errorText: _errorFor('personal.phone'),
          onChanged: (v) => update((p) => p.copyWith(phone: v)),
          onBlur: () => touch('personal.phone'),
        ),
        const SizedBox(height: AppSpacing.md),
        ManualResumeTextField(
          label: 'Location',
          value: p.location,
          hint: 'City, State',
          errorText: _errorFor('personal.location'),
          onChanged: (v) => update((p) => p.copyWith(location: v)),
          onBlur: () => touch('personal.location'),
        ),
        const SizedBox(height: AppSpacing.md),
        ManualResumeTextField(
          label: 'LinkedIn',
          value: p.linkedin,
          hint: 'linkedin.com/in/your-name',
          errorText: _errorFor('personal.linkedin'),
          onChanged: (v) => update((p) => p.copyWith(linkedin: v)),
          onBlur: () => touch('personal.linkedin'),
        ),
        const SizedBox(height: AppSpacing.md),
        ManualResumeTextField(
          label: 'Portfolio / website',
          value: p.website,
          hint: 'github.com/your-name',
          errorText: _errorFor('personal.website'),
          onChanged: (v) => update((p) => p.copyWith(website: v)),
          onBlur: () => touch('personal.website'),
        ),
        const SizedBox(height: AppSpacing.md),
        _DateOfBirthField(
          value: p.dob,
          errorText: _errorFor('personal.dob'),
          onChanged: (v) {
            update((p) => p.copyWith(dob: v));
            touch('personal.dob');
          },
        ),
        const SizedBox(height: AppSpacing.md),
        ManualResumeTextField(
          label: 'Passport No.',
          value: p.passport,
          hint: 'e.g. Y1234567',
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [UpperCaseTextFormatter()],
          errorText: _errorFor('personal.passport'),
          onChanged: (v) => update((p) => p.copyWith(passport: v)),
          onBlur: () => touch('personal.passport'),
        ),
      ],
    );
  }
}

/// Mirrors the server's own `.upper()` normalization of the passport field
/// (`resume_document.py:157`) so what the candidate sees matches what gets
/// validated/stored.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class _DateOfBirthField extends StatelessWidget {
  const _DateOfBirthField({required this.value, required this.onChanged, this.errorText});

  final String value;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(value);
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: parsed ?? DateTime(DateTime.now().year - 20),
          firstDate: DateTime(1940),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          onChanged(
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
          );
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date of birth (optional)',
          border: const OutlineInputBorder(),
          errorText: errorText,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(value.isEmpty ? 'Select a date' : value),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
