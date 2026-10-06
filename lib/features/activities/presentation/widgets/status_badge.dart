import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/sub_activity_status.dart';

/// Mirrors the web's sub-activity status badge — exact labels AND exact
/// colors from `.sub-status-badge.status-{{ status }}`
/// (`static/css/style.css:1636-1646`): flat pastel fills, not a
/// theme-color-tinted overlay, and a fully-rounded pill (`border-radius:
/// 999px`), not the smaller `--radius-sm` card-corner radius.
class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});

  final SubActivityStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (status) {
      SubActivityStatus.completed => ('Completed', const Color(0xFFDCFCE7), const Color(0xFF166534)),
      SubActivityStatus.inProgress => ('In Progress', const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
      SubActivityStatus.notStarted => ('Not Started', const Color(0xFFF1F5F9), const Color(0xFF64748B)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}
