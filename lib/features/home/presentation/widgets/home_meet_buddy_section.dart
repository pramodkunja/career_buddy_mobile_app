import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import 'home_feature_grid.dart';
import 'home_section_header.dart';

/// `#buddy` (`templates/landing.html:7036-7100`) — "Meet Buddy", the 6-card
/// feature grid plus the "Ask Buddy" CTA. The real web's button literally
/// calls `window.openChat()` (confirmed directly in the markup's own
/// `onclick`) — i.e. it opens the same chat widget this app already has as
/// [BuddyChatbotOverlay], not a separate screen — so [onAskBuddy] opens that
/// overlay via `buddyOverlayOpenRequestProvider` rather than navigating
/// anywhere.
class HomeMeetBuddySection extends StatelessWidget {
  const HomeMeetBuddySection({required this.onAskBuddy, super.key});

  final VoidCallback onAskBuddy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const HomeSectionHeader(
          eyebrow: 'Meet Buddy',
          title: 'Your career & learning assistant',
          description:
              'Buddy helps you discover features, navigate CareerBuddy and get things done — just ask.',
          centered: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        HomeFeatureGrid(
          cards: [
            const HomeFeatureCardData(
              icon: Icons.explore_outlined,
              iconBackground: Color(0xFFDBEAFE),
              iconColor: Color(0xFF185ADB),
              title: 'Discover Features',
              description: "Buddy knows what's on CareerBuddy and points you to the right page.",
            ),
            const HomeFeatureCardData(
              icon: Icons.description_outlined,
              iconBackground: Color(0xFFFDE3E3),
              iconColor: Color(0xFFDC4848),
              title: 'Check Your Resume',
              description: 'Ask Buddy to pull up your resume feedback, no menu-hunting.',
            ),
            const HomeFeatureCardData(
              icon: Icons.videocam_outlined,
              iconBackground: Color(0xFFECE3FB),
              iconColor: Color(0xFF7C4DDB),
              title: 'Practice Interviews',
              description: 'Jump straight into a mock interview from any page.',
            ),
            const HomeFeatureCardData(
              icon: Icons.school_outlined,
              iconBackground: Color(0xFFE1F7E9),
              iconColor: Color(0xFF209A52),
              title: 'Explore Learning',
              description: 'Get routed to the right activity or Skill Up module.',
            ),
            const HomeFeatureCardData(
              icon: Icons.search,
              iconBackground: Color(0xFFFFF4E0),
              iconColor: Color(0xFFB8760A),
              title: 'Find Jobs',
              description: 'Ask for matching opportunities based on your profile.',
            ),
            const HomeFeatureCardData(
              icon: Icons.chat_bubble_outline,
              iconBackground: Color(0xFFDBEAFE),
              iconColor: Color(0xFF185ADB),
              title: 'Career Guidance',
              description: 'Available on every page — guest, job seeker or employer.',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: onAskBuddy,
            icon: const Icon(Icons.smart_toy_outlined, size: 18),
            label: const Text('Ask Buddy'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
              shape: const StadiumBorder(),
            ),
          ),
        ),
      ],
    );
  }
}
