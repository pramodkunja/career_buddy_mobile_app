import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/fill_blank_question.dart';
import '../controllers/fill_blank_exercise_controller.dart';

/// `.fill-question-card` (`static/css/exercises.css:115-137`) — one
/// question, its input, its Check button, and (once checked) inline
/// feedback. Literal colors verified directly against the web CSS:
/// `.fill-input.correct-input`/`.wrong-input` (lines 128-129),
/// `.fill-feedback.correct-fb`/`.wrong-fb`/`.error-fb` (lines 135-137).
class FillBlankQuestionCard extends StatefulWidget {
  const FillBlankQuestionCard({
    required this.question,
    required this.checkedResult,
    required this.showEmptyError,
    required this.onCheck,
    super.key,
  });

  final FillBlankQuestion question;
  final FillBlankCheckedResult? checkedResult;
  final bool showEmptyError;
  final void Function(String given) onCheck;

  @override
  State<FillBlankQuestionCard> createState() => _FillBlankQuestionCardState();
}

class _FillBlankQuestionCardState extends State<FillBlankQuestionCard> {
  final _controller = TextEditingController();

  static const _correctBorder = Color(0xFF10B981);
  static const _correctBg = Color(0xFFECFDF5);
  static const _correctText = Color(0xFF065F46);
  static const _wrongBorder = Color(0xFFEF4444);
  static const _wrongBg = Color(0xFFFEF2F2);
  static const _wrongText = Color(0xFF991B1B);
  static const _errorBg = Color(0xFFFFF1F2);
  static const _errorText = Color(0xFFE11D48);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isChecked = widget.checkedResult != null;
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      // `.fill-question-card{padding:1.5rem 1.75rem}` = 24px/28px
      // (`static/css/exercises.css:116`).
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question ${widget.question.position}',
            style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(widget.question.questionText, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final input = TextField(
                controller: _controller,
                enabled: !isChecked,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'Type your answer here...',
                  filled: isChecked,
                  fillColor: isChecked ? (widget.checkedResult!.isCorrect ? _correctBg : _wrongBg) : null,
                  // `.fill-input:focus{border-color:#2563eb}`
                  // (`static/css/exercises.css:127`) — the outer glow
                  // (`box-shadow:0 0 0 3px rgba(37,99,235,.1)`) has no
                  // direct `InputDecoration` equivalent and isn't
                  // reproduced here.
                  focusedBorder: isChecked ? null : const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2563EB))),
                  enabledBorder: isChecked
                      ? OutlineInputBorder(
                          borderSide: BorderSide(
                            color: widget.checkedResult!.isCorrect ? _correctBorder : _wrongBorder,
                            width: 1.5,
                          ),
                        )
                      : null,
                  disabledBorder: isChecked
                      ? OutlineInputBorder(
                          borderSide: BorderSide(
                            color: widget.checkedResult!.isCorrect ? _correctBorder : _wrongBorder,
                            width: 1.5,
                          ),
                        )
                      : null,
                ),
              );
              final checkButton = OutlinedButton.icon(
                onPressed: isChecked ? null : () => widget.onCheck(_controller.text),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Check'),
              );

              // `.fill-input-row{flex-direction:column}` /
              // `.fill-input-row .btn{width:100%}` at `<=640px`
              // (`static/css/exercises.css:571-572`) — the web's own
              // mobile breakpoint, reproduced with the same threshold.
              if (constraints.maxWidth < 640) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [input, const SizedBox(height: AppSpacing.xs), checkButton],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: input), const SizedBox(width: AppSpacing.sm), checkButton],
              );
            },
          ),
          if (widget.showEmptyError && !isChecked) ...[
            const SizedBox(height: AppSpacing.xs),
            _FeedbackBox(
              bg: _errorBg,
              border: const Color(0xFFFDA4AF),
              textColor: _errorText,
              icon: Icons.error_outline,
              text: 'Please enter an answer first.',
            ),
          ],
          if (isChecked) ...[
            const SizedBox(height: AppSpacing.xs),
            _FeedbackBox(
              bg: widget.checkedResult!.isCorrect ? _correctBg : _wrongBg,
              border: widget.checkedResult!.isCorrect ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
              textColor: widget.checkedResult!.isCorrect ? _correctText : _wrongText,
              icon: widget.checkedResult!.isCorrect ? Icons.check_circle_outline : Icons.cancel_outlined,
              text: widget.checkedResult!.isCorrect
                  ? 'Correct!'
                  : 'Incorrect. Correct answer: ${widget.question.correctAnswer}',
            ),
            if ((widget.question.explanation ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.question.explanation!,
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _FeedbackBox extends StatelessWidget {
  const _FeedbackBox({required this.bg, required this.border, required this.textColor, required this.icon, required this.text});

  final Color bg;
  final Color border;
  final Color textColor;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textColor)),
          ),
        ],
      ),
    );
  }
}
