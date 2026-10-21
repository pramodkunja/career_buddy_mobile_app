import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import 'home_section_header.dart';
import 'home_tutorial_video_dialog.dart';

class _WhatCanYouDo {
  const _WhatCanYouDo(this.icon, this.title, this.description);
  final IconData icon;
  final String title;
  final String description;
}

class _FeaturedTutorial {
  const _FeaturedTutorial(this.videoId, this.duration, this.category, this.title, this.description);
  final String videoId;
  final String duration;
  final String category;
  final String title;
  final String description;
}

/// `#videos` (`templates/landing.html:7184-7245`) — "Tutorials", covering
/// the journey-chip sequence, the 9 "What can you do with CareerBuddy?"
/// cards and the 5 real "Featured tutorials" video cards.
///
/// Of the real `careerBuddyTutorials` JS array's 37 entries, only 9
/// reference a video id, and of those only **5 have a real file on disk**
/// (confirmed directly, Phase 40's audit): `welcome`, `resume`, `skillup`,
/// `match`, `chatbot` — exactly the 5 reproduced here as "Featured
/// tutorials". The "What can you do" cards' own "Watch Tutorial" links
/// mostly point at tutorials with no real video (the web itself shows a
/// "coming soon" placeholder for those) — reproduced here as the same 5
/// real videos only, with the remaining "Watch Tutorial" actions left
/// unwired rather than faked, per this phase's explicit "do not invent
/// videos or pretend unavailable media is playable" instruction.
class HomeTutorialsSection extends StatelessWidget {
  const HomeTutorialsSection({super.key});

  static const _journey = [
    'Explore', 'Choose career path', 'Build skills', 'Practice', 'Create resume',
    'Check ATS', 'Prepare for interviews', 'Get certified', 'Find jobs', 'Apply', 'Grow',
  ];

  static const _whatCanYouDo = [
    _WhatCanYouDo(Icons.school_outlined, 'Learn', 'Build professional and career skills.'),
    _WhatCanYouDo(Icons.extension_outlined, 'Practice', 'Complete activities and practical exercises.'),
    _WhatCanYouDo(Icons.description_outlined, 'Build your resume', 'Create and improve your resume.'),
    _WhatCanYouDo(Icons.trending_up, 'Check ATS score', 'Analyze resume compatibility.'),
    _WhatCanYouDo(Icons.mic_outlined, 'Practice interviews', 'Prepare with AI interview tools.'),
    _WhatCanYouDo(Icons.workspace_premium_outlined, 'Get certified', 'Complete supported assessments and certifications.'),
    _WhatCanYouDo(Icons.search, 'Find jobs', 'Discover relevant opportunities.'),
    _WhatCanYouDo(Icons.smart_toy_outlined, 'Get AI guidance', 'Ask Buddy for help.'),
    _WhatCanYouDo(Icons.apartment_outlined, 'Hire talent', 'Employers can post jobs and find candidates.'),
  ];

  static const _featured = [
    _FeaturedTutorial('welcome', '1:57', 'GETTING STARTED', 'Welcome to CareerBuddy',
        'Choose IT or Non-IT, then Technical or Non-Technical, and tour your dashboard.'),
    _FeaturedTutorial('resume', '1:07', 'RESUME & CAREER TOOLS', 'How to Create Your Resume',
        'Switch templates, edit with live preview, save a draft and print or save as PDF.'),
    _FeaturedTutorial('skillup', '1:16', 'SKILL UP', 'Skill Gap → Skill Up → Verified',
        'Find your gaps, learn with Skill Up, pass the assessment and watch your score rise.'),
    _FeaturedTutorial('match', '1:14', 'FOR JOB SEEKERS', 'Find Jobs: Match Score & Recommendations',
        'See how every job is scored, then save or apply to recommended jobs.'),
    _FeaturedTutorial('chatbot', '0:53', 'BUDDY', 'Meet Buddy: Your AI Career Assistant',
        'Ask in plain words and jump straight to the right module.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(
          eyebrow: 'Tutorials',
          title: 'Learn How CareerBuddy Works',
          description: 'Explore CareerBuddy through short, practical tutorials and discover everything '
              'you can do on the platform.',
          centered: true,
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final step in _journey)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(step, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'What can you do with CareerBuddy?',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final item in _whatCanYouDo)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.mdRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.action.withValues(alpha: 0.1),
                      borderRadius: AppRadius.smRadius,
                    ),
                    child: Icon(item.icon, size: 20, color: AppColors.action),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(item.description, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Featured tutorials',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final tutorial in _featured) _FeaturedTutorialCard(tutorial: tutorial),
      ],
    );
  }
}

class _FeaturedTutorialCard extends StatelessWidget {
  const _FeaturedTutorialCard({required this.tutorial});
  final _FeaturedTutorial tutorial;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgRadius,
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // The whole card is tappable (thumbnail, title and the "Watch
          // Tutorial" row all open the same dialog) — simpler and more
          // forgiving to tap than requiring the thumbnail or the small text
          // link specifically.
          onTap: () => HomeTutorialVideoDialog.show(context, videoId: tutorial.videoId, title: tutorial.title),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF14213D), Color(0xFF185ADB)],
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 12,
                      top: 10,
                      child: Text(
                        'CAREERBUDDY',
                        style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                        child: Text(tutorial.duration, style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                    const Center(
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.accent,
                        child: Icon(Icons.play_arrow, color: AppColors.onAccent, size: 28),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tutorial.category,
                      style: const TextStyle(color: AppColors.accentDark, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(tutorial.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(tutorial.description, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4)),
                    const SizedBox(height: AppSpacing.sm),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Watch Tutorial', style: TextStyle(color: AppColors.action, fontWeight: FontWeight.w700, fontSize: 13)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 14, color: AppColors.action),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
