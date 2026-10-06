import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../domain/entities/gd_session_summary.dart';
import '../controllers/gd_history_controller.dart';
import '../providers/gd_providers.dart';
import 'gd_report_screen.dart';

/// Batch 10 — `GD_app:api_sessions`'s "past sessions" list
/// (`templates/GD_app/home.html`'s history section), reached from
/// [GdTopicScreen]. Real data, real ordering (the API's own
/// `GDSession.Meta.ordering = ['-created_at']` — newest first, never
/// re-sorted client-side), real per-session navigation into its report via
/// `GD_app:session_report` (`GdRepository.getSessionReport`, already built
/// and tested in Batch 9, just not previously reachable from any screen).
class GdHistoryScreen extends ConsumerWidget {
  const GdHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gdHistoryControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Past Discussions')),
      body: Stack(
        children: [
          switch (state) {
            AsyncData(value: final sessions) => _HistoryList(sessions: sessions),
            AsyncError(:final error) => AppErrorView(
              message: error is Failure ? error.message : 'Something went wrong. Please try again.',
              onRetry: () => ref.read(gdHistoryControllerProvider.notifier).retry(),
            ),
            _ => const AppLoader(message: 'Loading your past discussions...'),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList({required this.sessions});

  final List<GdSessionSummary> sessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sessions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text(
            "You haven't had a Group Discussion yet. Start one from the previous screen to see it here.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => _SessionTile(session: sessions[index]),
    );
  }
}

class _SessionTile extends ConsumerStatefulWidget {
  const _SessionTile({required this.session});

  final GdSessionSummary session;

  @override
  ConsumerState<_SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends ConsumerState<_SessionTile> {
  bool _opening = false;

  Future<void> _open() async {
    setState(() => _opening = true);
    final result = await ref.read(gdRepositoryProvider).getSessionReport(widget.session.id);
    if (!mounted) return;
    setState(() => _opening = false);

    switch (result) {
      case Success(value: final report):
        if (report == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This discussion hasn\'t been analyzed yet.')),
          );
        } else {
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GdReportScreen(report: report)));
        }
      case Failed(failure: final failure):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(widget.session.createdAt);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _opening ? null : _open,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.session.topic,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (createdAt != null)
                          Text(formatMonthDayYear(createdAt), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        if (widget.session.isActive) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const _StatusPill(label: 'In progress', color: AppColors.warning),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (_opening)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
