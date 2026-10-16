import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/level_common_suggestions.dart';
import '../../domain/entities/manual_resume_draft.dart';
import '../../domain/entities/resume_role.dart';
import '../../domain/validation/manual_resume_validation.dart';
import '../providers/resume_providers.dart';
import 'manual_resume_form_widgets.dart';

/// Step 5 — Summary (verified, `landing.html:8604-8620`): professional
/// summary (with the role's own editable templates for the selected
/// level), a "Fill [placeholders] from my details" button, achievements
/// (with `LEVEL_COMMON` suggestion chips), languages, additional
/// information, and the declaration (checkbox + place + date — `decl_date`
/// is never auto-filled with today's date, confirmed directly against the
/// real builder's own initial state).
class ManualResumeSummaryStep extends ConsumerWidget {
  const ManualResumeSummaryStep({
    required this.draft,
    required this.role,
    required this.levelCommon,
    required this.visibleErrors,
    super.key,
  });

  final ManualResumeDraft draft;
  final ResumeRole? role;
  final Map<String, LevelCommonSuggestions> levelCommon;
  final List<ManualResumeValidationError> visibleErrors;

  String? _errorFor(String field) => visibleErrors.where((e) => e.field == field).map((e) => e.message).firstOrNull;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(manualResumeBuilderControllerProvider.notifier);
    final templates = draft.level.isEmpty ? const <String>[] : (role?.summaries[draft.level] ?? const []);
    final achievementSuggestions = draft.level.isEmpty ? const <String>[] : (levelCommon[draft.level]?.achievements ?? const []);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const Text('Professional summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        for (final template in templates)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(template, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        if (draft.summary.isNotEmpty) {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Replace your summary?'),
                              content: const Text('This will replace your current professional summary.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Replace')),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                        }
                        controller.applySummaryTemplate(template);
                      },
                      child: const Text('Use this template'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ManualResumeTextField(
          label: 'Professional summary',
          value: draft.summary,
          maxLines: 6,
          maxLength: 1200,
          errorText: _errorFor('summary'),
          onChanged: controller.setSummary,
          onBlur: () => controller.markTouched('summary'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: controller.fillPlaceholders,
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: const Text('Fill [placeholders] from my details'),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text('Achievements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        ManualResumeTextField(
          label: 'Achievements',
          value: draft.achievements,
          maxLines: 4,
          maxLength: 800,
          errorText: _errorFor('achievements'),
          onChanged: controller.setAchievements,
          onBlur: () => controller.markTouched('achievements'),
        ),
        ManualResumeSuggestionRow(
          label: 'Suggested achievements',
          options: achievementSuggestions,
          onTap: controller.appendAchievementSuggestion,
        ),
        const SizedBox(height: AppSpacing.lg),
        ManualResumeTextField(
          label: 'Languages',
          value: draft.languages,
          errorText: _errorFor('languages'),
          onChanged: controller.setLanguages,
          onBlur: () => controller.markTouched('languages'),
        ),
        const SizedBox(height: AppSpacing.md),
        ManualResumeTextField(
          label: 'Additional information',
          value: draft.additional,
          maxLines: 3,
          maxLength: 800,
          hint: 'One per line',
          errorText: _errorFor('additional'),
          onChanged: controller.setAdditional,
          onBlur: () => controller.markTouched('additional'),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text('Declaration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        CheckboxListTile(
          key: const Key('declaration-checkbox'),
          value: draft.declaration,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'I hereby declare that the information provided above is true and accurate to the best of my knowledge and belief.',
          ),
          onChanged: (v) => controller.setDeclaration(v ?? false),
        ),
        ManualResumeTextField(
          label: 'Place',
          value: draft.place,
          hint: 'e.g. Hyderabad',
          errorText: _errorFor('place'),
          onChanged: controller.setPlace,
          onBlur: () => controller.markTouched('place'),
        ),
        const SizedBox(height: AppSpacing.md),
        ManualResumeTextField(
          label: 'Date',
          value: draft.declDate,
          hint: 'YYYY-MM-DD',
          keyboardType: TextInputType.datetime,
          onChanged: controller.setDeclDate,
        ),
        if (visibleErrors.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const Text('Outstanding items', style: TextStyle(fontWeight: FontWeight.w700)),
          for (final error in visibleErrors)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('• ${error.message}', style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
        ],
      ],
    );
  }
}
