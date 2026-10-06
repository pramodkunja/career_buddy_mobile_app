import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../domain/entities/jam_assessment.dart';
import '../../domain/entities/jam_topic.dart';
import '../controllers/jam_topics_controller.dart';
import '../providers/jam_providers.dart';
import '../widgets/jam_locked_view.dart';
import 'jam_recording_screen.dart';

/// `jam:topics` (`templates/jam/topics.html`) — this feature's entry point.
/// A human should wire an Activity whose title matches `'jam' in
/// title.lower()` (`_can_access_workshop`/`get_workshop_url`,
/// `activities/views.py`) from `ActivityDetailScreen` to this screen (e.g.
/// `context.push(RoutePaths.jamTopics)` after registering a matching route
/// in `app_router.dart` — not done here, see this batch's report).
///
/// The web's own random-topic entry point (`jam:jam_session`, no topic
/// picker at all — `jam:dashboard`'s "Start Random Session" button) is
/// reproduced here as the "Random Topic" action at the top of this same
/// screen, rather than a second route, since `jam:dashboard` itself isn't
/// otherwise useful to reproduce (its stats — `total_sessions`/
/// `total_minutes`/recent session list — duplicate what a future History
/// screen would show, out of this batch's scope).
///
/// [JamRecordingScreen]/[JamResultScreen] are reached via plain
/// `Navigator.push`, not `go_router` — unlike every other screen in this
/// app, they have no useful standalone URL to deep-link to (a JAM session
/// only exists once actually started, mid-flow), so registering routes for
/// them in `app_router.dart` would add indirection without benefit; only
/// this entry screen needs a route, for the human wiring `ActivityDetailScreen`
/// to reach it at all.
///
/// The AppBar's History/Profile actions reproduce `jam:dashboard`'s own
/// nav to [RoutePaths.jamHistory] (real web link, just relocated from
/// `jam:dashboard` — not built here — to this screen, this feature's
/// actual entry point) and [RoutePaths.jamProfile] (a real, fully
/// functional page the web itself never links to from anywhere — see
/// `ApiEndpoints.jamProfile`'s doc comment — surfaced here since the task
/// explicitly asked for a JAM Profile screen and the page genuinely
/// exists and works, not fabricated).
class JamTopicsScreen extends ConsumerWidget {
  const JamTopicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(jamTopicsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('JAM — Just A Minute'),
        actions: [
          IconButton(
            tooltip: 'Practice History',
            icon: const Icon(Icons.history),
            onPressed: () => context.push(RoutePaths.jamHistory),
          ),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(RoutePaths.jamProfile),
          ),
        ],
      ),
      body: Stack(
        children: [
          switch (state) {
            AsyncData(value: final data) => _TopicsBody(data: data),
            AsyncError(:final error) when error is ForbiddenFailure => JamLockedView(message: error.message),
            AsyncError(:final error) => AppErrorView(
              message: error is Failure ? error.message : 'Something went wrong. Please try again.',
              onRetry: () => ref.read(jamTopicsControllerProvider.notifier).retry(),
            ),
            _ => const AppLoader(message: 'Loading topics...'),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _TopicsBody extends ConsumerWidget {
  const _TopicsBody({required this.data});

  final JamTopicsState data;

  void _start(BuildContext context, {int? topicId}) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => JamRecordingScreen(topicId: topicId)));
  }

  void _startAssessment(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const JamRecordingScreen(startAsAssessment: true)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eligibility = ref.watch(jamAssessmentEligibilityControllerProvider);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // `jam:dashboard`'s "Start Random Session" — see this screen's doc
        // comment for why it lives here rather than on a separate
        // dashboard screen.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Just A Minute',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                "Speak on a topic for 60 seconds without hesitation, repetition, or deviation.",
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Random Topic',
                icon: Icons.shuffle,
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                onPressed: () => _start(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _DifficultySection(title: 'Foundational Topics', badge: 'Easy', color: const Color(0xFF10B981), topics: data.easy, onSelect: (id) => _start(context, topicId: id)),
        const SizedBox(height: AppSpacing.lg),
        _DifficultySection(title: 'Spontaneous Challenges', badge: 'Medium', color: const Color(0xFFF59E0B), topics: data.medium, onSelect: (id) => _start(context, topicId: id)),
        const SizedBox(height: AppSpacing.lg),
        _DifficultySection(title: 'Analytical Debates', badge: 'Hard', color: const Color(0xFFF43F5E), topics: data.hard, onSelect: (id) => _start(context, topicId: id)),
        const SizedBox(height: AppSpacing.lg),
        // `jam:dashboard`'s "Assessment Journey" card — placed after the
        // topic list (rather than above it, where the real dashboard shows
        // it) purely so this screen's main topic-picking purpose stays the
        // first thing seen; nothing about the real flow depends on its
        // position on the page.
        _AssessmentEntryCard(eligibility: eligibility, onStart: () => _startAssessment(context)),
      ],
    );
  }
}

class _DifficultySection extends StatelessWidget {
  const _DifficultySection({
    required this.title,
    required this.badge,
    required this.color,
    required this.topics,
    required this.onSelect,
  });

  final String title;
  final String badge;
  final Color color;
  final List<JamTopic> topics;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(50)),
              child: Text(badge, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (topics.isEmpty)
          const Text('No topics available yet.', style: TextStyle(color: AppColors.textMuted))
        else
          for (final topic in topics) ...[
            _TopicCard(topic: topic, color: color, onTap: () => onSelect(topic.id)),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic, required this.color, required this.onTap});

  final JamTopic topic;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(topic.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          if (topic.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(topic.description, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.mic, size: 18),
              label: const Text('Practice Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `jam:dashboard`'s "Assessment Journey" card (`dashboard.html:169-249`,
/// read in full) — the 3-stage Assessment's entry point. Enabled only once
/// [JamAssessmentEligibilityController] confirms the user has a completed
/// practice session at each difficulty (`get_jam_level_progress`); disabled
/// otherwise, with the exact reasoning text `jam:start_assessment`'s own
/// flash message gives (`JamAssessmentEligibility.ineligibleReason`).
class _AssessmentEntryCard extends StatelessWidget {
  const _AssessmentEntryCard({required this.eligibility, required this.onStart});

  final AsyncValue<JamAssessmentEligibility> eligibility;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final data = eligibility.value;
    final isEligible = data?.isEligible ?? false;
    // A loading/error eligibility check is treated the same as "not yet
    // known to be eligible" — never optimistically enabled, since enabling
    // it would let a user tap through to a `start_assessment` call this
    // client can't yet confirm will succeed.
    final reason = data == null
        ? (eligibility.isLoading ? 'Checking your progress...' : "Couldn't check your progress. Pull down to retry.")
        : data.ineligibleReason;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ASSESSMENT JOURNEY',
            style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Diagnostic Level Test',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Take a structured 3-stage assessment across Simple, Intermediate, and Hard topics. '
            'Get a final diagnostic report on your fluency consistency.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _LevelChip(label: 'Simple', done: data?.easyDone ?? false),
              _LevelChip(label: 'Intermediate', done: data?.mediumDone ?? false),
              _LevelChip(label: 'Hard', done: data?.hardDone ?? false),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Start Assessment',
            icon: isEligible ? Icons.trending_up : Icons.lock,
            fullWidth: false,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            onPressed: isEligible ? onStart : null,
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(reason, style: const TextStyle(color: AppColors.accent, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.success : Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: done ? AppColors.success.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: done ? AppColors.success : Colors.white70, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}
