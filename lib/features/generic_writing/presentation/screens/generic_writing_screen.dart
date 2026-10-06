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
import '../../domain/entities/generic_writing_exercise.dart';
import '../controllers/generic_writing_controller.dart';
import '../generic_writing_route_args.dart';
import '../widgets/generic_writing_in_progress_body.dart';
import '../widgets/generic_writing_result_view.dart';

/// W013 — Generic Writing exercise-taking screen. Same reasoning as
/// `MatchingExerciseScreen`/`BingoExerciseScreen`/`FillBlankExerciseScreen`:
/// reads via HTML extraction (no JSON API exists for this `exercise_type`)
/// and submits through the existing, generic `submit_exercise` POST
/// unchanged. **Not** the AI Writing module screen (`AiWritingScreen`) —
/// see `GenericWritingExercise`'s doc comment for how routing tells the
/// two apart.
class GenericWritingScreen extends ConsumerWidget {
  const GenericWritingScreen({
    required this.exerciseId,
    required this.args,
    super.key,
  });

  final int exerciseId;
  final GenericWritingRouteArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = genericWritingControllerProvider((
      exerciseId,
      args.title,
      args.order,
    ));
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen<GenericWritingState>(provider, (previous, next) {
      final loadFailure = next is GenericWritingLoadFailed
          ? next.failure
          : null;
      if (loadFailure is UnauthorizedFailure) {
        ref.read(authControllerProvider.notifier).logout();
      }
    });

    final exercise = switch (state) {
      GenericWritingInProgress(:final exercise) => exercise,
      GenericWritingSubmitted(:final exercise) => exercise,
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
            GenericWritingLoading() => const AppLoader(
              message: 'Loading exercise...',
            ),
            GenericWritingLoadFailed(:final failure)
                when failure is! UnauthorizedFailure =>
              AppErrorView(
                message: failure.message,
                onRetry: controller.retryLoad,
              ),
            GenericWritingLoadFailed() => const AppLoader(),
            GenericWritingInProgress() => Column(
              children: [
                _Hero(exercise: state.exercise),
                Expanded(
                  child: GenericWritingInProgressBody(
                    state: state,
                    controller: controller,
                    previousAttempt: args.previousAttempt,
                  ),
                ),
              ],
            ),
            GenericWritingSubmitted(:final exercise, :final result) => Column(
              children: [
                _Hero(exercise: exercise),
                Expanded(
                  child: GenericWritingResultView(
                    exercise: exercise,
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

  final GenericWritingExercise exercise;

  @override
  Widget build(BuildContext context) {
    final (icon, tint) = exerciseHeroIconFor('writing');
    return ExerciseHero(
      activityTitle: exercise.heroMeta?.activityTitle ?? '',
      subActivityTitle: exercise.heroMeta?.subActivityTitle ?? '',
      exerciseTitle: exercise.title,
      // `EXERCISE_TYPE_CHOICES`'s exact display label
      // (`activities/models.py:26`) — `get_exercise_type_display()`.
      exerciseTypeDisplay: 'Writing Submission',
      icon: icon,
      iconTint: tint,
      heroColorSlug: exercise.heroMeta?.colorSlug,
    );
  }
}
