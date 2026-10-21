import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import 'home_about_section.dart';
import 'home_career_journey.dart';
import 'home_choose_path.dart';
import 'home_hero.dart';
import 'home_meet_buddy_section.dart';
import 'home_platform_overview.dart';
import 'home_resume_maker_teaser.dart';
import 'home_skill_up_teaser.dart';
import 'home_testimonials_section.dart';
import 'home_trust_strip.dart';
import 'home_tutorials_section.dart';
import 'portal_card.dart';

/// The guest branch of `{% block content %}` (`templates/landing.html`).
///
/// Landing-page parity phase: every section of the real page is now
/// reproduced, in the real page's own order (`landing.html`'s section
/// comments, read top to bottom): Hero → Trust strip → Platform overview
/// (`#features`) → Career journey (`.journey-sec`) → Choose Your Path
/// (`#choose-path`) → Job seeker / Employer story cards (`#job-seeker`/
/// `#employer`, pre-existing [PortalCard]s) → Skill Up (`#skillup`) →
/// Resume & AI (`#resume`, reusing the same [PortalCard] the job-seeker/
/// employer sections already use — `#resume`'s own markup is the identical
/// `.story` layout) → Meet Buddy (`#buddy`) → About CareerBuddy (`#why`) →
/// Resume maker teaser (`#create-resume`) → Tutorials (`#videos`) →
/// Testimonials (`#stories`). The footer ([HomeLandingFooter]) is composed
/// by [HomeScreen] itself, unchanged.
///
/// See `docs/LANDING_PAGE_WEB_MOBILE_PARITY_REPORT.md` for the full
/// section-by-section before/after and every route-mapping decision below.
class PublicHomeBody extends StatelessWidget {
  const PublicHomeBody({
    required this.onGetStarted,
    required this.onFindJobs,
    required this.onCreateResume,
    required this.onLogin,
    required this.onRegister,
    required this.onEmployerLogin,
    required this.onEmployerRegister,
    required this.onAskBuddy,
    required this.onItJobSeeker,
    required this.onNonItJobSeeker,
    super.key,
  });

  final VoidCallback onGetStarted;
  final VoidCallback onFindJobs;
  final VoidCallback onCreateResume;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback onEmployerLogin;
  final VoidCallback onEmployerRegister;

  /// Phase 49 — same destinations `HomeChoosePath`'s 2 cards already push
  /// (`RoutePaths.careerDepartments`, track `'it'`/`'non-it'`), now passed
  /// in from [HomeScreen] instead of being hardcoded here, so it can also
  /// cancel its own path-picker popup timer the instant either card is
  /// tapped directly (mirrors the real page's `clearTimeout(t)`).
  final VoidCallback onItJobSeeker;
  final VoidCallback onNonItJobSeeker;

  /// Opens [BuddyChatbotOverlay]'s panel (`buddyOverlayOpenRequestProvider`)
  /// — shared by the Platform Overview "Meet Buddy" link and the Meet Buddy
  /// section's own "Ask Buddy" button, matching the real web's "Meet Buddy"
  /// card linking to `#buddy` (the page scrolls to the same panel this one
  /// opens directly) and `#buddy`'s own CTA calling `window.openChat()`.
  final VoidCallback onAskBuddy;

  static const _primaryCtaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF185ADB), Color(0xFF7C3AED), Color(0xFFDB2777)],
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          HomeHero(
            onGetStarted: onGetStarted,
            onFindJobs: onFindJobs,
            onCreateResume: onCreateResume,
            onJobSeeker: onRegister,
            onEmployer: onEmployerRegister,
          ),
          const SizedBox(height: AppSpacing.md),
          const HomeTrustStrip(),
          const SizedBox(height: AppSpacing.xl),
          HomePlatformOverview(
            onExploreSkillUp: () => _push(context, RoutePaths.skillUp),
            onCheckResume: () => _push(context, RoutePaths.resumeBuilder),
            onStartMockInterview: () => _push(context, RoutePaths.resumeBuilder),
            onBrowseActivities: () => _push(context, RoutePaths.activities),
            onSeeMatchingJobs: onFindJobs,
            onMeetBuddy: onAskBuddy,
          ),
          const SizedBox(height: AppSpacing.xl),
          const HomeCareerJourney(),
          const SizedBox(height: AppSpacing.xl),
          HomeChoosePath(
            onItJobSeeker: onItJobSeeker,
            onNonItJobSeeker: onNonItJobSeeker,
          ),
          const SizedBox(height: AppSpacing.xl),
          PortalCard(
            eyebrow: 'For job seekers',
            title: 'Built for your career journey',
            description:
                'From your first lesson to your next offer, your Job Seeker Portal keeps everything connected — '
                'learning, resume, interviews and opportunities, all in one dashboard.',
            checklist: const [
              'AI-powered Resume & Interview Preparation',
              'Skills & Training with earned certifications',
              'Job matches based on your real profile',
              'One dashboard to track it all',
            ],
            ctaLabel: 'Explore Job Seeker Portal',
            onCta: onRegister,
            ctaGradient: _primaryCtaGradient,
            ctaFallbackColor: AppColors.action,
            secondaryLabel: 'Login',
            onSecondary: onLogin,
            caption: 'Learn, practice, get hired',
            avatarColors: const [
              Color(0xFF93C5FD),
              Color(0xFFF9A8D4),
              Color(0xFFFCD34D),
            ],
            isDarkVisual: true,
            highlights: const [
              PortalHighlight(
                icon: Icons.description_outlined,
                title: 'Resume & AI',
                description: 'AI feedback on every upload, ATS-ready.',
              ),
              PortalHighlight(
                icon: Icons.school_outlined,
                title: 'Skills & Training',
                description: '20+ activities, 100+ exercises, free to start.',
              ),
              PortalHighlight(
                icon: Icons.videocam_outlined,
                title: 'Interviews',
                description: 'Practice with AI, arrive prepared.',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          PortalCard(
            eyebrow: 'For employers',
            title: 'Build your hiring pipeline with CareerBuddy',
            description:
                'Post roles, search verified candidate profiles and manage every application from one dashboard — '
                'built for teams that need to hire quickly without losing quality.',
            checklist: const [
              'Post and manage job openings in minutes',
              'Search candidates by skills, not just keywords',
              'Review every application in one place',
              'Keep your company profile current',
            ],
            ctaLabel: 'Explore Employer Portal',
            onCta: onEmployerRegister,
            ctaFallbackColor: AppColors.primary,
            secondaryLabel: 'Login',
            onSecondary: onEmployerLogin,
            caption: 'Post, screen, hire faster',
            avatarColors: const [
              Color(0xFFF9A8D4),
              Color(0xFFFCD34D),
              Color(0xFF6EE7B7),
            ],
            isDarkVisual: false,
            highlights: const [
              PortalHighlight(
                icon: Icons.work_outline,
                title: 'Manage Jobs',
                description: 'Create and manage postings in one place.',
              ),
              PortalHighlight(
                icon: Icons.search,
                title: 'Find Candidates',
                description: 'Search verified, skills-matched profiles.',
              ),
              PortalHighlight(
                icon: Icons.inbox_outlined,
                title: 'Applications',
                description: 'Review every candidate who applies.',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          HomeSkillUpTeaser(
            onSpeaking: () => _push(context, RoutePaths.activitiesWithCategory('speaking')),
            onWriting: () => _push(context, RoutePaths.activitiesWithCategory('writing')),
            onVocabulary: () => _push(context, RoutePaths.skillUpSections),
            onNegotiation: () => _push(context, RoutePaths.activitiesWithCategory('negotiation')),
            onCommunication: () => _push(context, RoutePaths.activitiesWithCategory('communication')),
            onAnalysis: () => _push(context, RoutePaths.activitiesWithCategory('analysis')),
            onWorkshops: () => _push(context, RoutePaths.activitiesWithCategory('workshop')),
            onBrowseAll: () => _push(context, RoutePaths.skillUpSections),
          ),
          const SizedBox(height: AppSpacing.xl),
          PortalCard(
            eyebrow: 'Resume & AI',
            title: 'Turn your resume into a career advantage',
            description:
                "Upload your resume and get real, specific AI feedback — not generic tips. See your ATS score, "
                "fix what's holding you back, and track every version.",
            checklist: const [
              'AI-powered resume parsing & analysis',
              'ATS compatibility scoring',
              'Resume history across every version',
              'Job match analytics based on your resume',
            ],
            ctaLabel: 'Check Your Resume',
            onCta: () => _push(context, RoutePaths.resumeBuilder),
            ctaFallbackColor: AppColors.action,
            secondaryLabel: 'Resume History',
            onSecondary: () => _push(context, RoutePaths.resumeHistory),
            caption: 'Build a resume that gets noticed',
            avatarColors: const [
              Color(0xFFFEF3C7),
              Color(0xFFD1FAE5),
              Color(0xFFDBEAFE),
            ],
            isDarkVisual: true,
            highlights: const [
              PortalHighlight(
                icon: Icons.check_circle_outline,
                title: 'Resume Score',
                description: '87/100 — Strong keyword match, 2 formatting fixes suggested.',
              ),
              PortalHighlight(
                icon: Icons.history,
                title: 'Version History',
                description: 'Every analysis saved, so you can compare and improve.',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          HomeMeetBuddySection(onAskBuddy: onAskBuddy),
          const SizedBox(height: AppSpacing.xl),
          const HomeAboutSection(),
          const SizedBox(height: AppSpacing.xl),
          HomeResumeMakerTeaser(onCreateResume: onCreateResume),
          const SizedBox(height: AppSpacing.xl),
          const HomeTutorialsSection(),
          const SizedBox(height: AppSpacing.xl),
          const HomeTestimonialsSection(),
        ],
      ),
    );
  }

  void _push(BuildContext context, String path) => context.push(path);
}
