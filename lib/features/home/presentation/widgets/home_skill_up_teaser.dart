import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import 'home_section_header.dart';

class _SkillRow {
  const _SkillRow(this.icon, this.title, this.subtitle, this.onTap);
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

/// `#skillup` (`templates/landing.html:6948-6981`) — "Skill Up", "Seven
/// core skill areas", an 8-row list (7 categories + Browse All). Each row's
/// destination mirrors `core/navigation.py`'s `NAV_MAP` exactly: the 6
/// Activities-backed categories map onto `RoutePaths.activitiesWithCategory`
/// with the real category slug (`speaking`/`writing`/`negotiation`/
/// `communication`/`analysis`/`workshop`, confirmed directly against
/// `NAV_MAP`'s own `activity_list` destinations); "Vocabulary & Idioms" and
/// "Browse All" both resolve to the Skill Up hub's own "Sections in depth"
/// tab on the real site (`section=depth-english`/`section=section-depth`),
/// which this app already models as the single [onBrowseAll] destination
/// (`RoutePaths.skillUpSections`) rather than inventing 2 distinct screens
/// for what is one tab on the real hub.
class HomeSkillUpTeaser extends StatelessWidget {
  const HomeSkillUpTeaser({
    required this.onSpeaking,
    required this.onWriting,
    required this.onVocabulary,
    required this.onNegotiation,
    required this.onCommunication,
    required this.onAnalysis,
    required this.onWorkshops,
    required this.onBrowseAll,
    super.key,
  });

  final VoidCallback onSpeaking;
  final VoidCallback onWriting;
  final VoidCallback onVocabulary;
  final VoidCallback onNegotiation;
  final VoidCallback onCommunication;
  final VoidCallback onAnalysis;
  final VoidCallback onWorkshops;
  final VoidCallback onBrowseAll;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _SkillRow(Icons.mic_outlined, 'Speaking & Presentation', 'Pitches, interviews, meetings', onSpeaking),
      _SkillRow(Icons.edit_outlined, 'Writing & Correspondence', 'Emails, reports, proposals', onWriting),
      _SkillRow(Icons.extension_outlined, 'Vocabulary & Idioms', 'Industry terms, phrasal verbs', onVocabulary),
      _SkillRow(Icons.handshake_outlined, 'Negotiation & Meetings', 'Deal-making, chairing', onNegotiation),
      _SkillRow(Icons.public_outlined, 'Professional Communication', 'Cross-cultural, telephone', onCommunication),
      _SkillRow(Icons.pie_chart_outline, 'Analysis & Reporting', 'Data, finance, case studies', onAnalysis),
      _SkillRow(Icons.cast_for_education_outlined, 'Interactive Workshops', 'Live practice, roleplay', onWorkshops),
      _SkillRow(Icons.grid_view_outlined, 'Browse All', 'See every module', onBrowseAll),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(
          eyebrow: 'Skill Up',
          title: 'Seven core skill areas',
          description:
              'Covering the essential business communication skills employers actually look for.',
        ),
        const SizedBox(height: AppSpacing.md),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: InkWell(
              onTap: row.onTap,
              borderRadius: AppRadius.mdRadius,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.mdRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(row.icon, size: 20, color: AppColors.textMuted),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            row.subtitle,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
