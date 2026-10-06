import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';

/// A deliberate navigation adaptation, not web-mirrored data: the web's own
/// dedicated Interactive Workshop page (`workshop_dashboard`,
/// `/activities/workshop/`) is confirmed unreachable from any normal web
/// navigation — the only template referencing it is Role Play's own "back
/// to workshop dashboard" link — so there is no single existing `<a href>`
/// on another page to reproduce 1:1. This card is the chosen, documented
/// entry point into `WorkshopDashboardScreen` (W013), matching the
/// established pattern for `MockTestsEntryCard` (W020's own
/// similarly-unlinked entry point).
class WorkshopEntryCard extends StatelessWidget {
  const WorkshopEntryCard({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.groups_outlined),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Interactive Workshop', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('Group Discussion, JAM & Role Play'),
                  ],
                ),
              ),
              Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
