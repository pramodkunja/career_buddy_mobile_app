import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import 'home_section_header.dart';

class _WhyCard {
  const _WhyCard(this.number, this.borderColor, this.title, this.description);
  final String number;
  final Color borderColor;
  final String title;
  final String description;
}

/// `#why` (`templates/landing.html:7101-7154`) — "About CareerBuddy", 8
/// numbered cards, each with a colored top border cycling through the same
/// 4 brand accent colors twice (confirmed directly against the real
/// markup's `.why-card` border-color sequence).
class HomeAboutSection extends StatelessWidget {
  const HomeAboutSection({super.key});

  static const _cards = [
    _WhyCard('01', Color(0xFF185ADB), 'Career-Focused Learning', 'Every module ties directly back to employability, not abstract lessons.'),
    _WhyCard('02', Color(0xFFF59E0B), 'AI-Powered Assistance', 'Buddy and the resume/interview tools use AI to give specific, useful feedback.'),
    _WhyCard('03', Color(0xFFDB2777), 'Practical Activities', 'Speaking, writing, negotiation and workshops you can actually use at work.'),
    _WhyCard('04', Color(0xFFF59E0B), 'Resume & Interview Prep', 'ATS scoring and AI mock interviews that mirror the real thing.'),
    _WhyCard('05', Color(0xFF185ADB), 'Job Discovery', 'Matches based on your actual resume and skills, not keyword spam.'),
    _WhyCard('06', Color(0xFF7C3AED), 'Employer Hiring Tools', 'Post, search and manage applications without extra software.'),
    _WhyCard('07', Color(0xFFDB2777), 'Certifications', 'Verified credentials you can show employers, earned through real modules.'),
    _WhyCard('08', Color(0xFFF59E0B), 'One Connected Journey', 'Learning, resume, interviews and jobs — in a single account.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(
          eyebrow: 'About CareerBuddy',
          title: 'Why job seekers and employers choose CareerBuddy',
        ),
        const SizedBox(height: AppSpacing.md),
        for (final card in _cards)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.mdRadius,
                border: Border(top: BorderSide(color: card.borderColor, width: 3)),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.number,
                    style: TextStyle(
                      color: card.borderColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.description,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
