import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../controllers/gd_session_controller.dart';
import '../providers/gd_providers.dart';
import '../widgets/gd_locked_view.dart';
import 'gd_discussion_screen.dart';
import 'gd_history_screen.dart';

/// `GD_app:home` (`templates/GD_app/home.html`) — this feature's entry
/// point: pick a topic, then `GD_app:create_session`. The suggested topics
/// below are `home()`'s own hardcoded `suggested_topics` list
/// (`GD_app/views.py`), reproduced verbatim; a learner can also type any
/// other topic, matching the web's own free-text input alongside its
/// suggestion chips.
///
/// Reached from `ActivityDetailScreen` and `WorkshopDashboardScreen` for an
/// Activity whose title matches `isGdModuleActivity` (`'group discussion'
/// in title.lower() or title.lower() == 'gd'`) — both wired and confirmed
/// working. No required constructor params, same as `JamTopicsScreen`/
/// `RoleplayHomeScreen`.
class GdTopicScreen extends ConsumerStatefulWidget {
  const GdTopicScreen({super.key});

  @override
  ConsumerState<GdTopicScreen> createState() => _GdTopicScreenState();
}

class _GdTopicScreenState extends ConsumerState<GdTopicScreen> {
  final _controller = TextEditingController();

  static const _suggestedTopics = [
    'Social media is damaging society',
    'AI will replace human jobs',
    'Climate change needs immediate action',
    'Work from home vs office',
    'Is online education effective?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start(String topic) {
    final trimmed = topic.trim();
    if (trimmed.isEmpty) return;
    ref.read(gdSessionControllerProvider.notifier).startDiscussion(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gdSessionControllerProvider);

    ref.listen<GdState>(gdSessionControllerProvider, (previous, next) {
      if (next is GdLive && previous is! GdLive) {
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GdDiscussionScreen()));
      }
    });

    final isBusy = state is GdCreatingSession || state is GdConnectingSocket;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Group Discussion'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Past Discussions',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GdHistoryScreen())),
          ),
        ],
      ),
      body: Stack(
        children: [
          switch (state) {
            GdCreateFailed(failure: final failure) when failure is ForbiddenFailure => GdLockedView(
              message: failure.message,
            ),
            GdCreateFailed(failure: final failure) => AppErrorView(
              message: failure.message,
              onRetry: () => _start(_controller.text),
            ),
            GdCreatingSession() => const AppLoader(message: 'Starting your discussion...'),
            GdConnectingSocket() => const AppLoader(message: 'Connecting to the discussion room...'),
            _ => _TopicPicker(
              controller: _controller,
              suggestedTopics: _suggestedTopics,
              isBusy: isBusy,
              onStart: _start,
            ),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _TopicPicker extends StatelessWidget {
  const _TopicPicker({
    required this.controller,
    required this.suggestedTopics,
    required this.isBusy,
    required this.onStart,
  });

  final TextEditingController controller;
  final List<String> suggestedTopics;
  final bool isBusy;
  final ValueChanged<String> onStart;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Group Discussion', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              SizedBox(height: 6),
              Text(
                'Discuss a topic live with 3 AI participants — Alex, Maya, and Rishi.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text('Your topic', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Type a discussion topic...',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: onStart,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Start Discussion',
          icon: Icons.forum_outlined,
          onPressed: isBusy ? null : () => onStart(controller.text),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text('Or pick a suggested topic', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: AppSpacing.sm),
        for (final topic in suggestedTopics) ...[
          _SuggestedTopicCard(topic: topic, onTap: isBusy ? null : () => onStart(topic)),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _SuggestedTopicCard extends StatelessWidget {
  const _SuggestedTopicCard({required this.topic, required this.onTap});

  final String topic;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(topic, style: const TextStyle(fontWeight: FontWeight.w600))),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
