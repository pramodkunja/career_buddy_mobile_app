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
import '../../domain/entities/fill_blank_exercise.dart';
import '../controllers/fill_blank_exercise_controller.dart';
import '../fill_blank_route_args.dart';
import '../widgets/fill_blank_in_progress_body.dart';
import '../widgets/fill_blank_result_view.dart';

/// W010 — Fill in the Blank exercise-taking screen. Same reasoning as
/// `MatchingExerciseScreen`/`BingoExerciseScreen`: reads via HTML
/// extraction (no JSON API exists for this `exercise_type`) and submits
/// through the existing, generic `submit_exercise` POST unchanged.
class FillBlankExerciseScreen extends ConsumerWidget {
  const FillBlankExerciseScreen({
    required this.exerciseId,
    required this.args,
    super.key,
  });

  final int exerciseId;
  final FillBlankRouteArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = fillBlankExerciseControllerProvider((
      exerciseId,
      args.title,
      args.order,
    ));
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen<FillBlankExerciseState>(provider, (previous, next) {
      final loadFailure = next is FillBlankExerciseLoadFailed
          ? next.failure
          : null;
      if (loadFailure is UnauthorizedFailure) {
        ref.read(authControllerProvider.notifier).logout();
      }
    });

    final exercise = switch (state) {
      FillBlankExerciseInProgress(:final exercise) => exercise,
      FillBlankExerciseSubmitted(:final exercise) => exercise,
      _ => null,
    };
    final (heroStart, _) =
        resolveActivityHeroGradient(exercise?.heroMeta?.colorSlug) ??
        kDefaultActivityHeroGradient;

    return Scaffold(
      // `.exercise-hero` replaces the bare AppBar title once loaded —
      // same reasoning as `MatchingExerciseScreen`.
      appBar: AppBar(
        title: exercise == null ? Text(args.title) : null,
        backgroundColor: exercise == null ? null : heroStart,
        foregroundColor: exercise == null ? null : Colors.white,
        elevation: exercise == null ? null : 0,
      ),
      body: Stack(
        children: [
          switch (state) {
            FillBlankExerciseLoading() => const AppLoader(
              message: 'Loading exercise...',
            ),
            FillBlankExerciseLoadFailed(:final failure)
                when failure is! UnauthorizedFailure =>
              AppErrorView(
                message: failure.message,
                onRetry: controller.retryLoad,
              ),
            FillBlankExerciseLoadFailed() => const AppLoader(),
            FillBlankExerciseInProgress() => Column(
              children: [
                _Hero(exercise: state.exercise),
                Expanded(
                  child: FillBlankInProgressBody(
                    state: state,
                    controller: controller,
                    previousAttempt: args.previousAttempt,
                  ),
                ),
              ],
            ),
            FillBlankExerciseSubmitted(
              :final exercise,
              :final checkedResults,
              :final result,
            ) =>
              Column(
                children: [
                  _Hero(exercise: exercise),
                  Expanded(
                    child: FillBlankResultView(
                      exercise: exercise,
                      checkedResults: checkedResults,
                      result: result,
                      onTryAgain: controller.tryAgain,
                      // See MatchingExerciseScreen's onBackToSubActivity for
                      // why this pops onto the already-loaded screen instead
                      // of pushReplacement-ing a fresh one.
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

  final FillBlankExercise exercise;

  @override
  Widget build(BuildContext context) {
    final (icon, tint) = exerciseHeroIconFor('fill_blank');
    return ExerciseHero(
      activityTitle: exercise.heroMeta?.activityTitle ?? '',
      subActivityTitle: exercise.heroMeta?.subActivityTitle ?? '',
      exerciseTitle: exercise.title,
      exerciseTypeDisplay: 'Fill in the Blank',
      icon: icon,
      iconTint: tint,
      heroColorSlug: exercise.heroMeta?.colorSlug,
    );
  }
}
