import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';

/// Phase 49 — the real landing page's auto-shown "path picker" popup
/// (`templates/landing.html:6781-6834`, `<dialog id="cpModal">`), confirmed
/// still missing from the Flutter app (Phase 40's finding, re-verified
/// directly against the current source and the current `HomeChoosePath`
/// widget, whose own doc comment already notes the popup exists on the web
/// but was never built here — only its "Find your fit" eyebrow copy was
/// reused for the always-visible inline section).
///
/// Real content, read directly from the template (step 1: `#cpmStep1`,
/// step 2: `#cpmStep2`) — note this is its own copy, not identical to
/// [HomeChoosePath]'s inline section text, which must not be changed to
/// match (they are two genuinely different, if similar, strings on the
/// real page).
class HomePathPickerPopup extends StatefulWidget {
  const HomePathPickerPopup({required this.onItJobSeeker, required this.onNonIt, super.key});

  /// `<a href="{% url 'career_path' 'it' %}">` — a plain link on the web,
  /// reused here as the existing `RoutePaths.careerDepartments` (track
  /// `'it'`) destination `HomeChoosePath`'s own IT card already uses.
  final VoidCallback onItJobSeeker;

  /// Step 2's "Technical"/"Non-Technical" links
  /// (`{% url 'career_path' 'technical' %}`/`'non-technical'`) both land on
  /// one Flutter destination — `RoutePaths.careerDepartments` (track
  /// `'non-it'`) — the same simplification `HomeChoosePath`'s own Non-IT
  /// card and Phase 43's `CareerDepartmentsScreen` already use (that screen
  /// shows both Non-IT groups together, so there is no separate
  /// technical-only/non-technical-only destination to point at without
  /// inventing one — out of this phase's scope).
  final VoidCallback onNonIt;

  @override
  State<HomePathPickerPopup> createState() => _HomePathPickerPopupState();
}

class _HomePathPickerPopupState extends State<HomePathPickerPopup> {
  bool _showingStep2 = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'FIND YOUR FIT',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentDark, letterSpacing: 0.6),
                  ),
                ),
                IconButton(
                  key: const Key('path-picker-close-button'),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (_showingStep2) ..._step2() else ..._step1(),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_showingStep2)
                  TextButton.icon(
                    onPressed: () => setState(() => _showingStep2 = false),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Back'),
                  )
                else
                  const SizedBox.shrink(),
                TextButton(
                  key: const Key('path-picker-maybe-later-button'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Maybe later'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _step1() => [
    const SizedBox(height: AppSpacing.sm),
    const Text('Which path suits you?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
    const SizedBox(height: 4),
    const Text("Pick a track and we'll show you the roles that match.", style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
    const SizedBox(height: AppSpacing.md),
    _PathPickerCard(
      key: const Key('path-picker-it-card'),
      icon: Icons.computer_outlined,
      title: 'IT Job Seeker',
      description: 'Software, data, AI, cloud, testing and security roles.',
      onTap: () {
        Navigator.of(context).pop();
        widget.onItJobSeeker();
      },
    ),
    const SizedBox(height: AppSpacing.sm),
    _PathPickerCard(
      key: const Key('path-picker-nonit-card'),
      icon: Icons.groups_outlined,
      title: 'Non-IT Job Seeker',
      description: 'Technical and Non-Technical opportunities beyond IT.',
      onTap: () => setState(() => _showingStep2 = true),
    ),
  ];

  List<Widget> _step2() => [
    const SizedBox(height: AppSpacing.sm),
    const Text('Technical or Non-Technical?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
    const SizedBox(height: 4),
    const Text(
      'Choose the kind of Non-IT work you want to explore.',
      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
    ),
    const SizedBox(height: AppSpacing.md),
    _PathPickerCard(
      key: const Key('path-picker-technical-card'),
      icon: Icons.engineering_outlined,
      title: 'Technical',
      description: 'Engineering, EPC, PMC, HSE, shutdowns, plant O&M, renewables and HR-tech platforms.',
      onTap: () {
        Navigator.of(context).pop();
        widget.onNonIt();
      },
    ),
    const SizedBox(height: AppSpacing.sm),
    _PathPickerCard(
      key: const Key('path-picker-nontechnical-card'),
      icon: Icons.business_center_outlined,
      title: 'Non-Technical',
      description: 'Managed staffing, RPO, global mobility, payroll, executive search, skill development.',
      onTap: () {
        Navigator.of(context).pop();
        widget.onNonIt();
      },
    ),
  ];
}

class _PathPickerCard extends StatelessWidget {
  const _PathPickerCard({required this.icon, required this.title, required this.description, required this.onTap, super.key});

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdRadius,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.action.withValues(alpha: 0.1), borderRadius: AppRadius.smRadius),
              child: Icon(icon, color: AppColors.action, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(description, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
