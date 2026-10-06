import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';

/// A deliberate navigation adaptation, not web-mirrored data: on the web,
/// every mock test (OOP Mastery, DSA, Python, …) is reached several hops
/// deep inside a separate static hash-routed SPA (`/skill-up/` → Tech
/// Center → the subject's own guide page), not through any Django-templated
/// page this app otherwise mirrors, so there is no single `<a href>` to
/// reproduce 1:1 the way `jobDetail`/`pro` were. This card is the chosen,
/// documented entry point into `MockTestsHubScreen`, which lists every mock
/// test actually implemented (W020 + W021) — see `route_paths.dart`'s
/// `mockTestsHub` doc comment.
class MockTestsEntryCard extends StatelessWidget {
  const MockTestsEntryCard({required this.onTap, super.key});

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
              Icon(Icons.quiz_outlined),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mock Tests', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('OOP Mastery, DSA, Python & more'),
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
