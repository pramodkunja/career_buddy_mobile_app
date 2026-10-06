import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_nav_drawer.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../../../shared/widgets/drawer_aware_back_leading.dart';
import '../../domain/entities/quiz_subject.dart';

/// Lists every implemented mock test: W020's OOP Mastery, W022's AMCAT,
/// W023's CoCubes, and W021's 24 generic subjects (`kQuizSubjects`).
/// Deliberately a plain, flat list
/// rather than reproducing the web's own nested "Skill Up hub → Tech
/// Center → per-subject guide page" navigation — that's several
/// static-SPA hops deep and out of scope (see `route_paths.dart`'s
/// `oopMasteryMockTest` doc comment); this hub is the mobile-appropriate,
/// single-level equivalent covering the same destinations.
class MockTestsHubScreen extends StatelessWidget {
  const MockTestsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppNavDrawer(),
      appBar: AppBar(title: const Text('Mock Tests'), leading: drawerAwareBackLeading(context)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _MockTestTile(
                title: 'OOP Mastery',
                subtitle: '50 questions · 60 minutes',
                onTap: () => context.push(RoutePaths.oopMasteryMockTest),
              ),
              const SizedBox(height: AppSpacing.sm),
              _MockTestTile(
                title: 'AMCAT Mock Test',
                subtitle: '5 sections · ~85 minutes total',
                onTap: () => context.push(RoutePaths.amcatMockTest),
              ),
              const SizedBox(height: AppSpacing.sm),
              _MockTestTile(
                title: 'CoCubes Mock Test',
                subtitle: '4 sections · ~150 minutes total',
                onTap: () => context.push(RoutePaths.cocubesMockTest),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final subject in kQuizSubjects) ...[
                _MockTestTile(
                  title: subject.title,
                  subtitle: '50 questions · 60 minutes',
                  onTap: () =>
                      context.push(RoutePaths.subjectQuiz(subject.slug)),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _MockTestTile extends StatelessWidget {
  const _MockTestTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.quiz_outlined),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
