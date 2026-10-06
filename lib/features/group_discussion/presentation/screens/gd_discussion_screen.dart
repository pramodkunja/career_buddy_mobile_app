import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../domain/entities/gd_message.dart';
import '../controllers/gd_session_controller.dart';
import '../providers/gd_providers.dart';
import 'gd_report_screen.dart';

/// The live discussion room — `GD_app:gd_room` (`templates/GD_app/room.html`
/// + `gd.js`, read in full), reproduced as a native transcript + mic control
/// instead of the web's DOM message bubbles + browser Speech APIs. Reached
/// after [GdTopicScreen] successfully creates a session and connects the
/// WebSocket (`GdSessionController.startDiscussion`) — not a registered
/// `go_router` route, same reasoning as `JamRecordingScreen`.
class GdDiscussionScreen extends ConsumerWidget {
  const GdDiscussionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gdSessionControllerProvider);

    ref.listen<GdState>(gdSessionControllerProvider, (previous, next) {
      if (next is GdReportReady) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute<void>(builder: (_) => GdReportScreen(report: next.report)));
      }
    });

    return PopScope(
      canPop: state is! GdLive,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave the discussion?'),
            content: const Text('Ending here will close the discussion without a final report.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Stay')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Leave')),
            ],
          ),
        );
        if ((leave ?? false) && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Group Discussion'),
          actions: [
            if (state is GdLive)
              IconButton(
                icon: const Icon(Icons.stop_circle_outlined),
                tooltip: 'End discussion',
                onPressed: () => ref.read(gdSessionControllerProvider.notifier).endDiscussion(),
              ),
          ],
        ),
        body: Stack(
          children: [
            switch (state) {
              GdLive() => _LiveBody(state: state),
              GdEnding() => const AppLoader(message: 'Analyzing the discussion...'),
              GdConnectionLost() => _ConnectionLostBody(
                onReconnect: () => ref.read(gdSessionControllerProvider.notifier).reconnect(),
              ),
              GdConnectingSocket() => const AppLoader(message: 'Connecting...'),
              _ => const AppLoader(),
            },
            const BuddyChatbotOverlay(),
          ],
        ),
      ),
    );
  }
}

class _ConnectionLostBody extends StatelessWidget {
  const _ConnectionLostBody({required this.onReconnect});

  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 40, color: AppColors.danger),
            const SizedBox(height: AppSpacing.md),
            const Text('Connection lost', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'The connection to the discussion room was lost. Your transcript so far is kept — tap below to reconnect.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(label: 'Reconnect', icon: Icons.refresh, fullWidth: false, onPressed: onReconnect),
          ],
        ),
      ),
    );
  }
}

class _LiveBody extends ConsumerWidget {
  const _LiveBody({required this.state});

  final GdLive state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listening = state.micState == GdMicState.listening;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              for (final message in state.messages) _MessageBubble(message: message),
              if (state.typingSpeaker != null) _TypingIndicator(speakerName: state.typingSpeaker!.speakerName),
              if (listening) _ListeningBubble(text: state.livePartialText),
            ],
          ),
        ),
        if (state.sttError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(state.sttError!, style: const TextStyle(color: AppColors.danger), textAlign: TextAlign.center),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppButton(
            label: listening ? 'Done Speaking' : 'Speak Now',
            icon: listening ? Icons.stop : Icons.mic,
            backgroundColor: listening ? AppColors.danger : AppColors.accent,
            foregroundColor: listening ? Colors.white : AppColors.onAccent,
            onPressed: () {
              final notifier = ref.read(gdSessionControllerProvider.notifier);
              if (listening) {
                notifier.finishUserTurn();
              } else {
                notifier.startUserTurn();
              }
            },
          ),
        ),
      ],
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.speakerName});

  final String speakerName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('$speakerName is typing...', style: const TextStyle(color: AppColors.textMuted, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

class _ListeningBubble extends StatelessWidget {
  const _ListeningBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(AppSpacing.sm),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text.isEmpty ? 'Listening...' : text, style: const TextStyle(fontStyle: FontStyle.italic)),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final GdMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final color = _parseColor(message.colorHex) ?? AppColors.primary;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(AppSpacing.sm),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(message.avatar),
                const SizedBox(width: 4),
                Text(message.speakerName, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
              ],
            ),
            const SizedBox(height: 4),
            Text(message.content),
          ],
        ),
      ),
    );
  }

  Color? _parseColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }
}
