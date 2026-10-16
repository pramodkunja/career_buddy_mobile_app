import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

/// A labelled text field that reports when it loses focus (`onBlur`) so the
/// screen can mark the field "touched" — matching the real builder's own
/// error-visibility rule (an error only shows once its field has been
/// blurred, or the candidate has asked to see everything). Not built on
/// `AppTextField` (`shared/widgets/`) since that widget has no focus-change
/// hook; duplicating a small `TextFormField` here avoids changing a widget
/// used across the whole app for one feature's specific needs.
class ManualResumeTextField extends StatefulWidget {
  const ManualResumeTextField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.onBlur,
    this.required = false,
    this.errorText,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    super.key,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback? onBlur;
  final bool required;
  final String? errorText;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<ManualResumeTextField> createState() => _ManualResumeTextFieldState();
}

class _ManualResumeTextFieldState extends State<ManualResumeTextField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);
  late final FocusNode _focusNode = FocusNode();

  @override
  void didUpdateWidget(covariant ManualResumeTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text && !_focusNode.hasFocus) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (hasFocus) {
        if (!hasFocus) widget.onBlur?.call();
      },
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        keyboardType: widget.keyboardType,
        maxLines: widget.maxLines,
        maxLength: widget.maxLength,
        textCapitalization: widget.textCapitalization,
        inputFormatters: widget.inputFormatters,
        decoration: InputDecoration(
          labelText: widget.required ? '${widget.label} *' : '${widget.label} (optional)',
          hintText: widget.hint,
          errorText: widget.errorText,
          border: const OutlineInputBorder(),
          alignLabelWithHint: widget.maxLines > 1,
        ),
      ),
    );
  }
}

/// Live character counter under a long-text field (verified,
/// `landing.html:8485-8486`/`8804` — every textarea the real builder
/// renders gets one).
class ManualResumeCharCounter extends StatelessWidget {
  const ManualResumeCharCounter({required this.current, required this.max, super.key});

  final int current;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, left: 4),
      child: Text('$current / $max characters', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
    );
  }
}

/// A row of suggestion chips the candidate taps to insert/toggle a value —
/// the shared shape behind skill groups, suggested skills, responsibility
/// suggestions, achievement suggestions, and certification/training/
/// project-idea suggestions (every `chipGroup()`/`sugRow()`/`addRow()` use
/// in the real builder).
class ManualResumeChipGroup extends StatelessWidget {
  const ManualResumeChipGroup({
    required this.label,
    required this.options,
    required this.isSelected,
    required this.onToggle,
    super.key,
  });

  final String label;
  final List<String> options;
  final bool Function(String option) isSelected;
  final void Function(String option) onToggle;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                FilterChip(
                  label: Text(option),
                  selected: isSelected(option),
                  onSelected: (_) => onToggle(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A tappable suggestion ("insert this") rather than a toggle — used for
/// responsibility/achievement lines and certification/training/project
/// names, which get *added*, never selected/deselected in place.
class ManualResumeSuggestionRow extends StatelessWidget {
  const ManualResumeSuggestionRow({
    required this.label,
    required this.options,
    required this.onTap,
    this.isUsed,
    super.key,
  });

  final String label;
  final List<String> options;
  final void Function(String option) onTap;
  final bool Function(String option)? isUsed;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                ActionChip(
                  avatar: Icon(Icons.add, size: 16, color: (isUsed?.call(option) ?? false) ? AppColors.textMuted : null),
                  label: Text(option),
                  onPressed: () => onTap(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A repeatable-entry card: a title row (with a Remove button) around
/// arbitrary [child] fields — the shared shell for employment/internship/
/// project/education/certification/training entries.
class ManualResumeEntryCard extends StatelessWidget {
  const ManualResumeEntryCard({required this.title, required this.onRemove, required this.child, super.key});

  final String title;
  final VoidCallback onRemove;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  tooltip: 'Remove',
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

/// Asks for confirmation before removing a repeatable entry that already
/// has some content — matches the real builder's own confirm-before-remove
/// rule (verified, `landing.html:8851-8856`): an untouched/blank entry is
/// removed immediately by the caller without ever invoking this.
Future<bool> confirmRemoveEntry(BuildContext context, String noun) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Remove this $noun?'),
      content: Text('This $noun has information entered. Are you sure you want to remove it?'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Remove', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// A compact month+year picker producing a `'YYYY-MM'` string — the
/// closest Flutter equivalent of the real builder's native
/// `<input type="month">` (verified, `landing.html:8521-8533`), since
/// Flutter has no built-in month-only picker.
class ManualResumeMonthField extends StatelessWidget {
  const ManualResumeMonthField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];

  (int, int)? get _parsed {
    final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value);
    if (m == null) return null;
    return (int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    final years = [for (var y = DateTime.now().year + 1; y >= 1960; y--) y];

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: parsed?.$2,
            isExpanded: true,
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
            items: [
              for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(_monthNames[m - 1])),
            ],
            onChanged: enabled
                ? (month) {
                    if (month == null) return;
                    final year = parsed?.$1 ?? DateTime.now().year;
                    onChanged('${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}');
                  }
                : null,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: parsed?.$1,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder(), isDense: true),
            items: [for (final y in years) DropdownMenuItem(value: y, child: Text('$y'))],
            onChanged: enabled
                ? (year) {
                    if (year == null) return;
                    final month = parsed?.$2 ?? 1;
                    onChanged('${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}');
                  }
                : null,
          ),
        ),
      ],
    );
  }
}
