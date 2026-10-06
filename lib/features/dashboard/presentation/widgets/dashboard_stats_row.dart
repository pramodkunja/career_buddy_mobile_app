import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/responsive/breakpoints.dart';
import '../../domain/entities/dashboard_stats.dart';

/// Mirrors the web dashboard's 4-tile stats row (Total Activities,
/// Completed, In Progress, Total Score) — `dashboard.html:65-94`.
class DashboardStatsRow extends StatelessWidget {
  const DashboardStatsRow({required this.stats, super.key});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _StatTile(label: 'Total Activities', value: '${stats.totalActivities}', icon: Icons.menu_book_outlined),
      _StatTile(label: 'Completed', value: '${stats.completedCount}', icon: Icons.check_circle_outline),
      _StatTile(label: 'In Progress', value: '${stats.inProgressCount}', icon: Icons.trending_up),
      _StatTile(label: 'Total Score', value: '${stats.totalScore}', icon: Icons.star_outline),
    ];

    final tablet = isTablet(context);
    return GridView.count(
      crossAxisCount: tablet ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      // Narrower (2-column) phone tiles need proportionally more height for
      // the same content than wider (4-column) tablet tiles — a single
      // fixed ratio overflowed the value+label text on narrow phones
      // (confirmed at 320px width).
      childAspectRatio: tablet ? 1.6 : 1.3,
      children: tiles,
    );
  }
}

/// `.stat-card-blue/green/orange/purple` each define a distinct gradient
/// (`static/css/style.css:1314-1328`), but the site's later "BLACK & GOLD
/// ELEGANCE" override repaints ALL FOUR to the identical navy gradient with
/// a gold icon (`background:linear-gradient(135deg,#14213D,#0b1526)
/// !important`, `.stat-card-icon{color:var(--gold) !important}` —
/// `static/css/style.css:2754-2765`) — confirmed the override wins the
/// cascade, so all 4 tiles render identically navy, not 4 different colors.
class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.mdRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.mdRadius,
          boxShadow: AppShadows.sm,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.12)),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.accent, size: 22),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
