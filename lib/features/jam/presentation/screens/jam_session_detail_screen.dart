import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../controllers/jam_history_detail_controller.dart';
import 'jam_result_screen.dart';

/// Thin fetch-by-id wrapper around [JamResultScreen] — reached only from
/// [JamHistoryScreen] (the live recording flow already has the result in
/// memory and pushes [JamResultScreen] directly).
class JamSessionDetailScreen extends ConsumerWidget {
  const JamSessionDetailScreen({required this.sessionId, super.key});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(jamSessionDetailControllerProvider(sessionId));

    return switch (state) {
      AsyncData(value: final result) => JamResultScreen(result: result),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(title: const Text('JAM Session Result')),
        body: Stack(
          children: [
            AppErrorView(
              message: error is Failure ? error.message : 'Could not load this session.',
              onRetry: () => ref.read(jamSessionDetailControllerProvider(sessionId).notifier).retry(),
            ),
            const BuddyChatbotOverlay(),
          ],
        ),
      ),
      _ => const Scaffold(body: AppLoader()),
    };
  }
}
