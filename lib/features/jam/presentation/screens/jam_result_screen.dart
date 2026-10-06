import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../domain/entities/jam_session_result.dart';

/// `jam:session_detail` / `templates/jam/session_detail.html` — the scored
/// result `jam:complete_session` redirects to. Every field shown here comes
/// straight from [JamSessionResult] (see `parseJamSessionResultHtml`'s doc
/// comment for exactly how each one was extracted from the real page) —
/// nothing on this screen is invented.
class JamResultScreen extends StatelessWidget {
  const JamResultScreen({required this.result, super.key});

  final JamSessionResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('JAM Session Result')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Color(0x14000000), blurRadius: 20),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.topicTitle,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        if (result.topicDifficulty.isNotEmpty)
                          _Pill(
                            text:
                                '${_capitalize(result.topicDifficulty)} Difficulty',
                          ),
                        if (result.durationDisplay.isNotEmpty)
                          _Pill(text: '${result.durationDisplay} spoken'),
                        if (result.createdAtDisplay.isNotEmpty)
                          _Pill(text: result.createdAtDisplay),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: Column(
                        children: [
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 140,
                                  height: 140,
                                  child: CircularProgressIndicator(
                                    value: (result.overallScore / 25)
                                        .clamp(0, 1)
                                        .toDouble(),
                                    strokeWidth: 10,
                                    backgroundColor: AppColors.border,
                                    valueColor: const AlwaysStoppedAnimation(
                                      AppColors.accentDark,
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${result.overallScore}',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Text(
                                      'OVERALL / 25',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ScoreBar(
                      label: 'Confidence',
                      score: result.confidenceScore,
                    ),
                    _ScoreBar(label: 'Fluency', score: result.fluencyScore),
                    _ScoreBar(label: 'Language', score: result.languageScore),
                    _ScoreBar(
                      label: 'Pronunciation',
                      score: result.pronunciationScore,
                    ),
                    _ScoreBar(
                      label: 'Time Management',
                      score: result.timeManagementScore,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _TextCard(
                icon: Icons.auto_awesome,
                title: 'Detailed Feedback',
                body: result.aiFeedback,
              ),
              if (result.transcript.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                _TextCard(
                  icon: Icons.subject,
                  title: 'Speech Transcript',
                  body: result.transcript,
                ),
              ],
              if (result.improvementTips.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                _TextCard(
                  icon: Icons.rocket_launch,
                  title: 'Growth Roadmap',
                  body: result.improvementTips,
                  dark: true,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Back to Topics',
                icon: Icons.arrow_back,
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
              ),
            ],
          ),
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                '$score/5',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: LinearProgressIndicator(
              value: (score / 5).clamp(0, 1).toDouble(),
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.action),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextCard extends StatelessWidget {
  const _TextCard({
    required this.icon,
    required this.title,
    required this.body,
    this.dark = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: dark ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: dark ? null : Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: dark ? AppColors.accent : AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: dark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: TextStyle(
              color: dark ? Colors.white70 : AppColors.textPrimary,
              height: 1.5,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}
