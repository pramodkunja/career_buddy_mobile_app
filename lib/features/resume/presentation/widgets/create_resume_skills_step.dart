import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/create_resume_state.dart';
import '../../domain/entities/create_resume_validation_error.dart';
import '../providers/resume_providers.dart';

/// Step 3 — Skills, the 4 `SKILL_CATEGORIES` (`technical`, `functional`,
/// `soft`, `tools`; `MAX_SKILLS_PER_CATEGORY`=30, `SKILL_MIN`/`SKILL_MAX`=
/// 2–50 characters each, all confirmed directly). A skill is typed, then
/// added as its own chip (comma/semicolon/newline all split it immediately,
/// matching the server's own `_list()` splitting convention that the Manual
/// Resume Builder's text fields already rely on) — chips can be removed
/// individually, so what's on screen always matches what will be submitted.
class CreateResumeSkillsStep extends ConsumerWidget {
  const CreateResumeSkillsStep({
    required this.skills,
    required this.serverErrors,
    super.key,
  });

  final CreateResumeSkills skills;
  final List<CreateResumeValidationError> serverErrors;

  String? _errorFor(String key) => serverErrors
      .where((e) => e.field == 'skills.$key')
      .map((e) => e.message)
      .firstOrNull;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(createResumeBuilderControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _SkillCategoryField(
          label: 'Technical skills',
          hint: 'e.g. Python, SQL, React',
          values: skills.technical,
          errorText: _errorFor('technical'),
          onChanged: (v) =>
              controller.updateSkills((s) => s.copyWith(technical: v)),
        ),
        const SizedBox(height: AppSpacing.lg),
        _SkillCategoryField(
          label: 'Functional skills',
          hint: 'e.g. Project Management, Data Analysis',
          values: skills.functional,
          errorText: _errorFor('functional'),
          onChanged: (v) =>
              controller.updateSkills((s) => s.copyWith(functional: v)),
        ),
        const SizedBox(height: AppSpacing.lg),
        _SkillCategoryField(
          label: 'Soft skills',
          hint: 'e.g. Communication, Leadership',
          values: skills.soft,
          errorText: _errorFor('soft'),
          onChanged: (v) => controller.updateSkills((s) => s.copyWith(soft: v)),
        ),
        const SizedBox(height: AppSpacing.lg),
        _SkillCategoryField(
          label: 'Tools & technologies',
          hint: 'e.g. Git, Docker, Figma',
          values: skills.tools,
          errorText: _errorFor('tools'),
          onChanged: (v) =>
              controller.updateSkills((s) => s.copyWith(tools: v)),
        ),
      ],
    );
  }
}

/// Splits on comma/semicolon/newline, trims, and dedupes case-insensitively
/// (keeping the first occurrence) — the same rule `create_resume.py`'s own
/// `_list()` normalization applies server-side.
List<String> _splitSkillText(String raw, List<String> existing) {
  final out = [...existing];
  final seen = {for (final s in existing) s.toLowerCase()};
  for (final part in raw.split(RegExp(r'[,;\n]'))) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) continue;
    final key = trimmed.toLowerCase();
    if (seen.add(key)) out.add(trimmed);
  }
  return out;
}

class _SkillCategoryField extends StatefulWidget {
  const _SkillCategoryField({
    required this.label,
    required this.hint,
    required this.values,
    required this.onChanged,
    this.errorText,
  });

  final String label;
  final String hint;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final String? errorText;

  @override
  State<_SkillCategoryField> createState() => _SkillCategoryFieldState();
}

class _SkillCategoryFieldState extends State<_SkillCategoryField> {
  final _controller = TextEditingController();

  void _commit() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    widget.onChanged(_splitSkillText(text, widget.values));
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: widget.hint,
            border: const OutlineInputBorder(),
            errorText: widget.errorText,
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add',
              onPressed: _commit,
            ),
          ),
          onSubmitted: (_) => _commit(),
        ),
        if (widget.values.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final skill in widget.values)
                Chip(
                  label: Text(skill),
                  onDeleted: () =>
                      widget.onChanged([...widget.values]..remove(skill)),
                  deleteIconColor: AppColors.textMuted,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
