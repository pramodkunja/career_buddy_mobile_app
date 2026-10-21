import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import 'home_section_header.dart';

/// `#create-resume` (`templates/landing.html:7155-7183`) — the landing
/// page's own resume-maker teaser. The real section embeds the full,
/// interactive Create Resume builder (template picker, form, live preview)
/// directly in the page; this phase deliberately does **not** duplicate
/// that — the real builder already exists as its own full screen
/// (`CreateResumeBuilderScreen`, Phase 39/42), reachable from the hero's own
/// "Create Resume" button. Embedding a second, cut-down copy of the same
/// form here would be exactly the kind of duplicate resume system this
/// phase's own instructions warn against. Instead, this is a teaser —
/// template names (decorative, matching the real 3 choices) plus a
/// description and a CTA into the one real builder.
class HomeResumeMakerTeaser extends StatelessWidget {
  const HomeResumeMakerTeaser({required this.onCreateResume, super.key});

  final VoidCallback onCreateResume;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const HomeSectionHeader(
          eyebrow: 'Resume maker',
          title: 'Create your resume',
          description:
              'Choose a template, enter your own details section by section, and download an '
              'ATS-friendly PDF. Everything on your resume is written by you.',
          centered: true,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            _TemplateChip(label: 'Classic', selected: true),
            SizedBox(width: AppSpacing.sm),
            _TemplateChip(label: 'Modern', selected: false),
            SizedBox(width: AppSpacing.sm),
            _TemplateChip(label: 'Minimal', selected: false),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: onCreateResume,
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('Create Resume'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
              shape: const StadiumBorder(),
            ),
          ),
        ),
      ],
    );
  }
}

class _TemplateChip extends StatelessWidget {
  const _TemplateChip({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(
          color: selected ? AppColors.action : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(height: 3, width: 20, color: AppColors.textMuted),
                const SizedBox(height: 4),
                Container(height: 2, width: 24, color: AppColors.border),
                const SizedBox(height: 2),
                Container(height: 2, width: 18, color: AppColors.border),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.action : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
