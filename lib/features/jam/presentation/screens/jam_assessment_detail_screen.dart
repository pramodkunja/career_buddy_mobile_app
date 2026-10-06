import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../controllers/jam_history_detail_controller.dart';
import 'jam_assessment_result_screen.dart';

/// Thin fetch-by-id wrapper around [JamAssessmentResultScreen] — reached
/// only from [JamHistoryScreen] (the live assessment flow already has the
/// result in memory when stage 3 finishes).
class JamAssessmentDetailScreen extends ConsumerWidget {
  const JamAssessmentDetailScreen({required this.assessmentId, super.key});

  final int assessmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(jamAssessmentDetailControllerProvider(assessmentId));

    return switch (state) {
      AsyncData(value: final result) => JamAssessmentResultScreen(result: result),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(title: const Text('Diagnostic Report')),
        body: Stack(
          children: [
            AppErrorView(
              message: error is Failure ? error.message : 'Could not load this assessment.',
              onRetry: () => ref.read(jamAssessmentDetailControllerProvider(assessmentId).notifier).retry(),
            ),
            const BuddyChatbotOverlay(),
          ],
        ),
      ),
      _ => const Scaffold(body: AppLoader()),
    };
  }
}
