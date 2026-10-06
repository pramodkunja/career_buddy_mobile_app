import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/activity_hero_colors.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../../../shared/widgets/exercise_hero.dart';
import '../../../activities/presentation/controllers/sub_activity_detail_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/matching_exercise.dart';
import '../controllers/matching_exercise_controller.dart';
import '../matching_route_args.dart';
import '../widgets/matching_in_progress_body.dart';
import '../widgets/matching_result_view.dart';

/// W008 — Matching exercise-taking screen. See
/// `docs/EXERCISE_FEASIBILITY_AUDIT.md` §W008 for why this reads via HTML
/// extraction (no JSON API exists for this `exercise_type`) but submits
/// through the existing, generic `submit_exercise` POST unchanged.
class MatchingExerciseScreen extends ConsumerWidget {
  const MatchingExerciseScreen({
    required this.exerciseId,
    required this.args,
    super.key,
  });

  final int exerciseId;
  final MatchingRouteArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = matchingExerciseControllerProvider((
      exerciseId,
      args.title,
      args.order,
    ));
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen<MatchingExerciseState>(provider, (previous, next) {
      final loadFailure = next is MatchingExerciseLoadFailed
          ? next.failure
          : null;
      if (loadFailure is UnauthorizedFailure) {
        ref.read(authControllerProvider.notifier).logout();
      }
    });

    final exercise = switch (state) {
      MatchingExerciseInProgress(:final exercise) => exercise,
      MatchingExerciseSubmitted(:final exercise) => exercise,
      _ => null,
    };
    final (heroStart, _) =
        resolveActivityHeroGradient(exercise?.heroMeta?.colorSlug) ??
        kDefaultActivityHeroGradient;

    return Scaffold(
      // `.exercise-hero` replaces the bare AppBar title once loaded — the
      // AppBar itself stays (for the back button), blended into the
      // hero's own resolved color. See `MatchingExercise.heroMeta`'s doc
      // comment for where `heroColorSlug` comes from.
      appBar: AppBar(
        title: exercise == null ? Text(args.title) : null,
        backgroundColor: exercise == null ? null : heroStart,
        foregroundColor: exercise == null ? null : Colors.white,
        elevation: exercise == null ? null : 0,
      ),
      body: Stack(
        children: [
          switch (state) {
            MatchingExerciseLoading() => const AppLoader(
              message: 'Loading exercise...',
            ),
            MatchingExerciseLoadFailed(:final failure)
                when failure is! UnauthorizedFailure =>
              AppErrorView(
                message: failure.message,
                onRetry: controller.retryLoad,
              ),
            MatchingExerciseLoadFailed() => const AppLoader(),
            MatchingExerciseInProgress() => Column(
              children: [
                _Hero(exercise: state.exercise),
                Expanded(
                  child: MatchingInProgressBody(
                    state: state,
                    controller: controller,
                    previousAttempt: args.previousAttempt,
                  ),
                ),
              ],
            ),
            MatchingExerciseSubmitted(
              :final exercise,
              :final matches,
              :final result,
            ) =>
              Column(
                children: [
                  _Hero(exercise: exercise),
                  Expanded(
                    child: MatchingResultView(
                      exercise: exercise,
                      matches: matches,
                      result: result,
                      onTryAgain: controller.tryAgain,
                      // Pops back onto the already-loaded SubActivityDetailScreen
                      // instance (pushed via `context.push`, still beneath this
                      // route on the Navigator stack) instead of pushReplacement-
                      // ing a fresh one — avoids needing this exercise's parent
                      // `activityId` (the real sub-activity URL needs both ids;
                      // this screen only carries `subActivityId`). Invalidating
                      // the family provider first ensures it re-fetches so the
                      // just-completed exercise's new score/status shows up
                      // rather than the stale pre-exercise state.
                      onBackToSubActivity: () {
                        ref.invalidate(subActivityDetailControllerProvider((activityId: args.activityId, subActivityId: args.subActivityId)));
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.exercise});

  final MatchingExercise exercise;

  @override
  Widget build(BuildContext context) {
    final (icon, tint) = exerciseHeroIconFor('matching');
    return ExerciseHero(
      activityTitle: exercise.heroMeta?.activityTitle ?? '',
      subActivityTitle: exercise.heroMeta?.subActivityTitle ?? '',
      exerciseTitle: exercise.title,
      exerciseTypeDisplay: 'Matching',
      icon: icon,
      iconTint: tint,
      heroColorSlug: exercise.heroMeta?.colorSlug,
    );
  }
}
