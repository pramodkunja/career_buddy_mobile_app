import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/writing_prompt.dart';
import '../../domain/services/writing_limits.dart';
import '../../domain/services/writing_word_count.dart';

// Precomputed `WritingLimits` is passed in by the caller (from
// `GenericWritingInProgress.limitsFor`) rather than recomputed here, since
// that computation depends on the whole exercise's title (the "Proposal
// Section Writing" special case, `getWritingLimits`'s first branch) — a
// value this widget doesn't otherwise need to know.

/// `.writing-prompt-card` (`static/css/exercises.css:282-297`) — one
/// prompt, its Guide (if any), its textarea, and a live word counter with
/// a min/max hint. Literal colors verified directly against the web CSS:
/// card border `#e2e8f0`, guide box `#fffbeb`/`#fde68a`/`#92400e`
/// (`.writing-guide`). Word-count colors come from `refreshWritingState()`
/// (`static/js/exercises.js:770-784`): neutral `#64748b` at zero words,
/// green `#198754` once within range, red `#dc3545` otherwise.
class GenericWritingPromptCard extends StatefulWidget {
  const GenericWritingPromptCard({
    required this.prompt,
    required this.draft,
    required this.limits,
    required this.onChanged,
    super.key,
  });

  final WritingPrompt prompt;
  final String draft;
  final WritingLimits limits;
  final void Function(String text) onChanged;

  @override
  State<GenericWritingPromptCard> createState() => _GenericWritingPromptCardState();
}

class _GenericWritingPromptCardState extends State<GenericWritingPromptCard> {
  late final _controller = TextEditingController(text: widget.draft);

  static const _neutral = Color(0xFF64748B);
  static const _valid = Color(0xFF198754);
  static const _invalid = Color(0xFFDC3545);
  static const _guideBg = Color(0xFFFFFBEB);
  static const _guideBorder = Color(0xFFFDE68A);
  static const _guideText = Color(0xFF92400E);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final words = countWritingWords(widget.draft);
    final limits = widget.limits;
    final isValid = words >= limits.min && (limits.max == null || words <= limits.max!);
    final countColor = words == 0 ? _neutral : (isValid ? _valid : _invalid);
    final hint = limits.max != null ? '${limits.min}–${limits.max} words required' : 'Minimum ${limits.min} words required';

    return Container(
      width: double.infinity,
      // `.writing-prompt-card{padding:1.5rem 1.75rem}` = 24px/28px
      // (`static/css/exercises.css:284`).
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prompt ${widget.prompt.position}',
            style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(widget.prompt.questionText, style: theme.textTheme.titleSmall),
          if ((widget.prompt.guide ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(color: _guideBg, border: Border.all(color: _guideBorder), borderRadius: BorderRadius.circular(8)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Guide: ', style: TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(text: widget.prompt.guide),
                        ],
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(color: _guideText),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          // `.writing-input{border-radius:8px}` +
          // `:focus{border-color:#2563eb}` (`static/css/exercises.css:
          // 291-296`) — the outer focus glow
          // (`box-shadow:0 0 0 3px rgba(37,99,235,.1)`) has no direct
          // `InputDecoration` equivalent and isn't reproduced here.
          TextField(
            controller: _controller,
            minLines: 6,
            maxLines: 12,
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              hintText: 'Write your response here...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2563EB)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$words word${words != 1 ? 's' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(color: countColor, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              // A range hint ("80–120 words required") can run long on a
              // narrow phone — wraps rather than overflowing, unlike the
              // web's own single-line `.writing-min-hint`, which simply has
              // more horizontal room to work with on desktop.
              Flexible(
                child: Text(
                  hint,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
