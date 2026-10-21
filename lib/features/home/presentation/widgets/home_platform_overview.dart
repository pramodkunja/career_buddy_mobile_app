import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import 'home_feature_grid.dart';
import 'home_section_header.dart';

/// `#features` (`templates/landing.html:6611-6672`) — "Platform overview",
/// the 6-card feature grid. Card colors/icons are the literal inline-style
/// values from the real markup, not approximated; destinations follow
/// `core/navigation.py`'s `NAV_MAP` (the real `nav_go` gateway each card
/// link resolves through) mapped onto the closest existing Flutter route —
/// see this widget's constructor callers for the exact mapping and its
/// justification where the web's own target has no direct Flutter screen
/// (`#choose-path` for "Check your resume").
class HomePlatformOverview extends StatelessWidget {
  const HomePlatformOverview({
    required this.onExploreSkillUp,
    required this.onCheckResume,
    required this.onStartMockInterview,
    required this.onBrowseActivities,
    required this.onSeeMatchingJobs,
    required this.onMeetBuddy,
    super.key,
  });

  final VoidCallback onExploreSkillUp;
  final VoidCallback onCheckResume;
  final VoidCallback onStartMockInterview;
  final VoidCallback onBrowseActivities;
  final VoidCallback onSeeMatchingJobs;
  final VoidCallback onMeetBuddy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(
          eyebrow: 'Platform overview',
          title: 'Everything you need to move your career forward',
          description:
              'Six connected tools, one platform — each one already live in your CareerBuddy account.',
        ),
        const SizedBox(height: AppSpacing.md),
        HomeFeatureGrid(
          cards: [
            HomeFeatureCardData(
              icon: Icons.school_outlined,
              iconBackground: const Color(0xFFDBEAFE),
              iconColor: const Color(0xFF185ADB),
              title: 'Learn & Improve',
              description:
                  'Professional English, grammar, vocabulary and communication skills across seven core areas.',
              actionLabel: 'Explore Skill Up',
              onAction: onExploreSkillUp,
            ),
            HomeFeatureCardData(
              icon: Icons.description_outlined,
              iconBackground: const Color(0xFFFDE3E3),
              iconColor: const Color(0xFFDC4848),
              title: 'Build Your Resume',
              description:
                  'AI resume parsing, ATS scoring and guided improvements that keep your resume current.',
              actionLabel: 'Check your resume',
              onAction: onCheckResume,
            ),
            HomeFeatureCardData(
              icon: Icons.videocam_outlined,
              iconBackground: const Color(0xFFECE3FB),
              iconColor: const Color(0xFF7C4DDB),
              title: 'Practice Interviews',
              description:
                  'AI-powered mock interviews with instant feedback, so the real one feels familiar.',
              actionLabel: 'Start a mock interview',
              onAction: onStartMockInterview,
            ),
            HomeFeatureCardData(
              icon: Icons.grid_view_outlined,
              iconBackground: const Color(0xFFE1F7E9),
              iconColor: const Color(0xFF209A52),
              title: 'Develop Skills',
              description:
                  'Activities, assessments, workshops and certifications that build verifiable, job-ready skills.',
              actionLabel: 'Browse activities',
              onAction: onBrowseActivities,
            ),
            HomeFeatureCardData(
              icon: Icons.search,
              iconBackground: const Color(0xFFFFF4E0),
              iconColor: const Color(0xFFB8760A),
              title: 'Find Opportunities',
              description:
                  'Job matching based on your actual profile, resume and skills — not generic listings.',
              actionLabel: 'See matching jobs',
              onAction: onSeeMatchingJobs,
            ),
            HomeFeatureCardData(
              icon: Icons.smart_toy_outlined,
              iconBackground: const Color(0xFFDBEAFE),
              iconColor: const Color(0xFF185ADB),
              title: 'Get AI Guidance',
              description:
                  'Buddy helps you navigate CareerBuddy, answer questions and get to the right place fast.',
              actionLabel: 'Meet Buddy',
              onAction: onMeetBuddy,
            ),
          ],
        ),
      ],
    );
  }
}
