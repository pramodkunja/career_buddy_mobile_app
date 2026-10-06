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
import '../../../../shared/widgets/coming_soon_screen.dart';
import '../../../ai_listening/domain/services/listening_module_detection.dart';
import '../../../ai_listening/presentation/ai_listening_route_args.dart';
import '../../../ai_reading/domain/services/reading_module_detection.dart';
import '../../../ai_reading/presentation/ai_reading_route_args.dart';
import '../../../ai_speaking/domain/services/speaking_module_detection.dart';
import '../../../ai_speaking/presentation/ai_speaking_route_args.dart';
import '../../../ai_writing/domain/services/writing_module_detection.dart';
import '../../../ai_writing/presentation/ai_writing_route_args.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../bingo/presentation/bingo_route_args.dart';
import '../../../fill_blank/presentation/fill_blank_route_args.dart';
import '../../../generic_writing/presentation/generic_writing_route_args.dart';
import '../../../matching/presentation/matching_route_args.dart';
import '../../../timer_exercise/presentation/timer_exercise_route_args.dart';
import '../../domain/entities/sub_activity_detail.dart';
import '../controllers/mark_sub_complete_controller.dart';
import '../controllers/sub_activity_detail_controller.dart';
import '../controllers/sub_activity_siblings_controller.dart';
import '../widgets/exercise_tile.dart';
import '../widgets/learning_tips_card.dart';
import '../widgets/mark_complete_section.dart';
import '../widgets/status_badge.dart';
import '../widgets/sub_activity_nav_list.dart';
import '../widgets/sub_activity_navigation_bar.dart';

/// Mirrors `templates/activities/sub_activity.html`. Only `mcq` exercises
/// are tappable this phase — every other type stays a read-only summary
/// (see `docs/PHASE_3_EXERCISE_ARCHITECTURE.md`).
class SubActivityDetailScreen extends ConsumerWidget {
  const SubActivityDetailScreen({required this.activityId, required this.subActivityId, super.key});

  final int activityId;
  final int subActivityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = subActivityDetailControllerProvider((activityId: activityId, subActivityId: subActivityId));
    final state = ref.watch(provider);

    ref.listen<AsyncValue<SubActivityDetail>>(provider, (previous, next) {
      final error = next.error;
      if (error is UnauthorizedFailure) {
        ref.read(authControllerProvider.notifier).logout();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Sub-Activity')),
      body: Stack(
        children: [
          switch (state) {
            AsyncData(value: final data) => _SubActivityDetailContent(data: data),
            AsyncError(:final error) when error is ForbiddenFailure => _LockedState(message: error.message),
            AsyncError(:final error) when error is! UnauthorizedFailure => AppErrorView(
              message: error is Failure ? error.message : 'Something went wrong. Please try again.',
              onRetry: () => ref.read(provider.notifier).retry(),
            ),
            _ => const AppLoader(message: 'Loading...'),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _SubActivityDetailContent extends ConsumerWidget {
  const _SubActivityDetailContent({required this.data});

  final SubActivityDetail data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final siblings = ref.watch(subActivitySiblingsControllerProvider(data.activityId)).value ?? const [];
    final markCompleteState = ref.watch(markSubCompleteControllerProvider((activityId: data.activityId, subActivityId: data.id)));

    final index = siblings.indexWhere((s) => s.id == data.id);
    final previous = index > 0 ? siblings[index - 1] : null;
    final next = (index != -1 && index < siblings.length - 1) ? siblings[index + 1] : null;
    final totalCount = siblings.isEmpty ? null : siblings.length;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.activityTitle, style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    totalCount == null ? 'Sub-Activity ${data.order}' : 'Sub-Activity ${data.order} of $totalCount',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            StatusBadge(status: data.status),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(data.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.lg),
        _SectionCard(icon: Icons.info_outline, title: 'Overview', child: Text(data.description)),
        const SizedBox(height: AppSpacing.md),
        _SectionCard(icon: Icons.list_alt_outlined, title: 'Instructions', child: Text(data.instructions)),
        const SizedBox(height: AppSpacing.lg),
        // Matches the web's `{% if exercises %}` — the whole section,
        // heading included, is absent when there are none.
        if (data.exercises.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.videogame_asset_outlined, size: 18, color: AppColors.action),
              const SizedBox(width: AppSpacing.xs),
              Text('Interactive Exercises', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final exercise in data.exercises) ...[
            ExerciseTile(
              exercise: exercise,
              isSpeakingModule: isSpeakingModuleActivity(data.activityTitle),
              isWritingModule: isWritingModuleActivity(data.activityTitle),
              isListeningModule: isListeningModuleActivity(data.activityTitle),
              isReadingModule: isReadingModuleActivity(data.activityTitle),
              onTap: () {
                if (exercise.exerciseType == 'mcq') {
                  context.push(RoutePaths.mcqExercise(exercise.id));
                } else if (exercise.exerciseType == 'matching') {
                  // W008 — reads via HTML extraction (no JSON API for this
                  // exercise type), so `title`/`order` travel as route args
                  // instead of being re-fetched — see
                  // `MatchingRouteArgs`'s doc comment.
                  context.push(
                    RoutePaths.matchingExercise(exercise.id),
                    extra: MatchingRouteArgs(
                      title: exercise.title,
                      order: exercise.order,
                      subActivityId: data.id,
                      activityId: data.activityId,
                      previousAttempt: exercise.lastAttempt,
                    ),
                  );
                } else if (exercise.exerciseType == 'bingo') {
                  // W009 — reads via HTML extraction (no JSON API for this
                  // exercise type either), so `title`/`order` travel as
                  // route args instead of being re-fetched — same
                  // reasoning as `MatchingRouteArgs`.
                  context.push(
                    RoutePaths.bingoExercise(exercise.id),
                    extra: BingoRouteArgs(
                      title: exercise.title,
                      order: exercise.order,
                      subActivityId: data.id,
                      activityId: data.activityId,
                      previousAttempt: exercise.lastAttempt,
                    ),
                  );
                } else if (exercise.exerciseType == 'fill_blank') {
                  // W010 — reads via HTML extraction (no JSON API for this
                  // exercise type either), so `title`/`order` travel as
                  // route args instead of being re-fetched — same
                  // reasoning as `MatchingRouteArgs`/`BingoRouteArgs`.
                  context.push(
                    RoutePaths.fillBlankExercise(exercise.id),
                    extra: FillBlankRouteArgs(
                      title: exercise.title,
                      order: exercise.order,
                      subActivityId: data.id,
                      activityId: data.activityId,
                      previousAttempt: exercise.lastAttempt,
                    ),
                  );
                } else if (exercise.exerciseType == 'timer') {
                  // Timer ("Timed Activity") — reads via HTML extraction
                  // (no JSON API for this exercise type either), so
                  // `title`/`order` travel as route args instead of being
                  // re-fetched — same reasoning as
                  // `MatchingRouteArgs`/`BingoRouteArgs`/`FillBlankRouteArgs`.
                  // Placed alongside `matching`/`bingo`/`fill_blank` (before
                  // the module-detection branches below), unlike
                  // `exercise_type == 'writing'` further down: `timer` has
                  // no module-title-detection ambiguity to worry about (no
                  // AI module renders a `timer` exercise under a different
                  // template), so there is no precedence reason to place it
                  // any later.
                  context.push(
                    RoutePaths.timerExercise(exercise.id),
                    extra: TimerExerciseRouteArgs(
                      title: exercise.title,
                      order: exercise.order,
                      subActivityId: data.id,
                      activityId: data.activityId,
                      previousAttempt: exercise.lastAttempt,
                    ),
                  );
                } else if (isSpeakingModuleActivity(data.activityTitle)) {
                  // W014 — the parent Activity's title matches
                  // `get_module_template()`'s speaking-module rule
                  // (`activities/views.py:27-42`), confirmed the same way
                  // the web itself decides this, not by `exercise_type`
                  // (no DB value for "speaking" exists at all).
                  context.push(
                    RoutePaths.aiSpeaking(exercise.id),
                    extra: AiSpeakingRouteArgs(
                      subActivityId: data.id,
                      activityId: data.activityId,
                      activityTitle: data.activityTitle,
                      previousAttempt: exercise.lastAttempt,
                    ),
                  );
                } else if (isWritingModuleActivity(data.activityTitle)) {
                  // W015 — same title-based routing rule, checked against
                  // the writing branch's own keywords.
                  context.push(
                    RoutePaths.aiWriting(exercise.id),
                    extra: AiWritingRouteArgs(
                      subActivityId: data.id,
                      activityId: data.activityId,
                      activityTitle: data.activityTitle,
                      previousAttempt: exercise.lastAttempt,
                    ),
                  );
                } else if (isListeningModuleActivity(data.activityTitle)) {
                  // W016 — same title-based routing rule, but with no
                  // "professional" keyword requirement — confirmed
                  // independently against `get_module_template()`'s
                  // listening branch, which checks only `"listen" in
                  // title` (the real seed title is `'Listen & Write'`).
                  context.push(
                    RoutePaths.aiListening(exercise.id),
                    extra: AiListeningRouteArgs(
                      subActivityId: data.id,
                      activityId: data.activityId,
                      activityTitle: data.activityTitle,
                      previousAttempt: exercise.lastAttempt,
                    ),
                  );
                } else if (isReadingModuleActivity(data.activityTitle)) {
                  // W017 — same title-based routing rule, requiring
                  // "professional" again (like Speaking/Writing, unlike
                  // Listening).
                  context.push(
                    RoutePaths.aiReading(exercise.id),
                    extra: AiReadingRouteArgs(
                      subActivityId: data.id,
                      activityId: data.activityId,
                      activityTitle: data.activityTitle,
                      previousAttempt: exercise.lastAttempt,
                    ),
                  );
                } else if (exercise.exerciseType == 'writing') {
                  // W013 — Generic Writing. Checked *after* every
                  // module-detection branch above, deliberately: an
                  // AI-module Activity's own exercises also carry
                  // `exercise_type == 'writing'` in the DB, but
                  // `get_module_template()` (`activities/views.py:27-42`)
                  // — which decides the web's own routing — checks the
                  // Activity's *title* first and renders the specialised
                  // module template unconditionally whenever it matches,
                  // never falling through to the generic
                  // `exercise.exercise_type` switch. Placing this branch
                  // last reproduces that exact precedence; placing it
                  // alongside `matching`/`bingo`/`fill_blank` above would
                  // wrongly intercept real AI Writing module exercises.
                  // W008-W010's own HTML-extraction reasoning applies
                  // here too — see `FillBlankRouteArgs`.
                  context.push(
                    RoutePaths.genericWritingExercise(exercise.id),
                    extra: GenericWritingRouteArgs(
                      title: exercise.title,
                      order: exercise.order,
                      subActivityId: data.id,
                      activityId: data.activityId,
                      previousAttempt: exercise.lastAttempt,
                    ),
                  );
                } else {
                  // No JSON API exposes this exercise type's question
                  // content (verified against every `*_api` view in
                  // `activities/views.py` — only MCQ has one) — this is an
                  // honest explanation, not a fake exercise screen. See
                  // `docs/BACKEND_LIMITATIONS_fill_blank.md`.
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ComingSoonScreen(
                        title: exercise.exerciseTypeDisplay,
                        message:
                            '${exercise.exerciseTypeDisplay} exercises aren\'t available in the app yet. '
                            'Please practice this exercise on the Career Buddy website for now.',
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
        MarkCompleteSection(
          allExercisesDone: data.allExercisesDone,
          completedAt: data.completedAt,
          state: markCompleteState,
          onSubmit: () => ref.read(markSubCompleteControllerProvider((activityId: data.activityId, subActivityId: data.id)).notifier).submit(),
        ),
        const SizedBox(height: AppSpacing.md),
        SubActivityNavigationBar(
          previous: previous,
          next: next,
          onSelectSibling: (id) => context.pushReplacement(RoutePaths.subActivityDetail(data.activityId, id)),
          onBackToActivity: () => context.push(RoutePaths.activityDetail(data.activityId)),
          onFinishActivity: () => context.push(RoutePaths.activityDetail(data.activityId)),
        ),
        const SizedBox(height: AppSpacing.lg),
        SubActivityNavList(
          siblings: siblings,
          currentId: data.id,
          onSelect: (id) => context.pushReplacement(RoutePaths.subActivityDetail(data.activityId, id)),
        ),
        if (siblings.isNotEmpty) const SizedBox(height: AppSpacing.md),
        const LearningTipsCard(),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.action),
              const SizedBox(width: AppSpacing.xs),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          DefaultTextStyle.merge(style: Theme.of(context).textTheme.bodyMedium, child: child),
        ],
      ),
    );
  }
}

/// The web never actually renders `sub_activity.html` for a locked
/// activity — it redirects back to the Activities list with the
/// Upgrade-Required modal (`activities/views.py:_locked_redirect`), the
/// same as Activity Detail. Mirrors `ActivityDetailScreen`'s `_LockedState`.
class _LockedState extends StatelessWidget {
  const _LockedState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 40, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'View Plans',
              icon: Icons.workspace_premium_outlined,
              fullWidth: false,
              onPressed: () => context.push(RoutePaths.pro),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Back to Activities',
              variant: AppButtonVariant.text,
              fullWidth: false,
              onPressed: () => context.go(RoutePaths.activities),
            ),
          ],
        ),
      ),
    );
  }
}
