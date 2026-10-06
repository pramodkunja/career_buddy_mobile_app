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
import '../../domain/entities/bingo_exercise.dart';
import '../bingo_route_args.dart';
import '../controllers/bingo_exercise_controller.dart';
import '../widgets/bingo_game_body.dart';
import '../widgets/bingo_result_view.dart';

/// W009 — Vocabulary Bingo exercise-taking screen. See
/// `docs/EXERCISE_FEASIBILITY_AUDIT.md`-style reasoning already
/// established for Matching (W008) — this reads via the same HTML
/// extraction (no JSON API exists for this `exercise_type`) and submits
/// through the same generic, unchanged `submit_exercise` POST.
class BingoExerciseScreen extends ConsumerWidget {
  const BingoExerciseScreen({required this.exerciseId, required this.args, super.key});

  final int exerciseId;
  final BingoRouteArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = bingoExerciseControllerProvider((exerciseId, args.title, args.order));
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen<BingoExerciseState>(provider, (previous, next) {
      final loadFailure = next is BingoExerciseLoadFailed ? next.failure : null;
      if (loadFailure is UnauthorizedFailure) {
        ref.read(authControllerProvider.notifier).logout();
      }
    });

    final exercise = switch (state) {
      BingoExerciseReady(:final exercise) => exercise,
      BingoExercisePlaying(:final exercise) => exercise,
      BingoExerciseResult(:final exercise) => exercise,
      _ => null,
    };
    final (heroStart, _) = resolveActivityHeroGradient(exercise?.heroMeta?.colorSlug) ?? kDefaultActivityHeroGradient;

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
            BingoExerciseLoading() => const AppLoader(message: 'Loading exercise...'),
            BingoExerciseLoadFailed(:final failure) when failure is! UnauthorizedFailure => AppErrorView(
              message: failure.message,
              onRetry: controller.retryLoad,
            ),
            BingoExerciseLoadFailed() => const AppLoader(),
            BingoExerciseReady(:final exercise) => Column(
              children: [
                _Hero(exercise: exercise),
                Expanded(
                  child: BingoReadyBody(
                    exercise: exercise,
                    startLabel: 'Start Game',
                    onStart: controller.start,
                    previousAttempt: args.previousAttempt,
                  ),
                ),
              ],
            ),
            BingoExercisePlaying() => Column(
              children: [
                _Hero(exercise: state.exercise),
                Expanded(
                  child: BingoPlayingBody(
                    state: state,
                    startLabel: 'Restart',
                    onStart: controller.start,
                    onNext: state.markedWord == null ? null : controller.nextRound,
                    onCellTap: controller.selectCell,
                  ),
                ),
              ],
            ),
            BingoExerciseResult() => Column(
              children: [
                _Hero(exercise: state.exercise),
                Expanded(
                  child: BingoResultView(
                    state: state,
                    onTryAgain: controller.start,
                    onRetrySubmit: controller.retrySubmit,
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

  final BingoExercise exercise;

  @override
  Widget build(BuildContext context) {
    final (icon, tint) = exerciseHeroIconFor('bingo');
    return ExerciseHero(
      activityTitle: exercise.heroMeta?.activityTitle ?? '',
      subActivityTitle: exercise.heroMeta?.subActivityTitle ?? '',
      exerciseTitle: exercise.title,
      exerciseTypeDisplay: 'Vocabulary Bingo',
      icon: icon,
      iconTint: tint,
      heroColorSlug: exercise.heroMeta?.colorSlug,
    );
  }
}
