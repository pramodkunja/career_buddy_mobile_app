import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/config/environment.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_footer.dart';
import '../../../../shared/widgets/app_nav_drawer.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../domain/entities/resume_analysis.dart';
import '../controllers/resume_builder_controller.dart';
import '../providers/resume_providers.dart';
import '../widgets/resume_score_ring.dart';

/// `career_app.views.resume_builder_home`/`resume_job_match` —
/// `templates/resume_builder.html`/`resume_match_result.html`. Both the
/// upload form and its result live at the same web URL/page, so this
/// screen owns both bodies itself (see `ResumeBuilderController`'s doc
/// comment) rather than navigating to a second route for the result.
///
/// `_can_access_resume` (`career_app/views.py:147-151`) is just
/// `user.is_authenticated` — Resume Parsing is free-tier accessible, so
/// `resume_locked.html`'s branch never actually renders for a real logged-in
/// user and isn't reproduced here (a confirmed-dead branch, not an
/// oversight).
class ResumeBuilderScreen extends ConsumerWidget {
  const ResumeBuilderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(resumeBuilderControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(),
      drawer: const AppNavDrawer(),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                switch (state) {
                  ResumeResultState(result: final result) => _ResultView(result: result),
                  ResumeIdle(errorMessage: final errorMessage) => _UploadForm(
                    errorMessage: errorMessage,
                    enabled: true,
                  ),
                  ResumeUploading() => const _UploadForm(errorMessage: null, enabled: false),
                },
                const AppFooter(),
              ],
            ),
          ),
          if (state is ResumeUploading) const _LoadingOverlay(),
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

/// `.resume-hero` + the upload card + the 3 feature cards
/// (`resume_builder.html:160-251`). The 2 desktop-only stat tiles
/// (`d-none d-lg-flex`, line 171) are never shown on the web at any width
/// this app targets — omitted here too, not dropped by oversight.
class _UploadForm extends ConsumerStatefulWidget {
  const _UploadForm({required this.errorMessage, required this.enabled});

  final String? errorMessage;
  final bool enabled;

  @override
  ConsumerState<_UploadForm> createState() => _UploadFormState();
}

class _UploadFormState extends ConsumerState<_UploadForm> {
  PlatformFile? _picked;

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      // `accept=".pdf,.docx"` (`resume_builder.html:209`) — the web's own
      // restriction, reproduced exactly, not expanded.
      allowedExtensions: ['pdf', 'docx'],
    );
    if (files.isNotEmpty) {
      setState(() => _picked = files.single);
    }
  }

  void _submit() {
    final file = _picked;
    if (file?.path == null) return;
    ref
        .read(resumeBuilderControllerProvider.notifier)
        .uploadAndAnalyze(filePath: file!.path!, fileName: file.name);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ResumeHero(),
          if (widget.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            _ErrorBox(message: widget.errorMessage!),
          ],
          const SizedBox(height: AppSpacing.lg),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    const Expanded(
                      child: Text('Upload Resume', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                    Flexible(
                      child: OutlinedButton.icon(
                        onPressed: widget.enabled ? () => context.push(RoutePaths.resumeHistory) : null,
                        icon: const Icon(Icons.history, size: 16),
                        label: const Text('Resume History'),
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                InkWell(
                  onTap: widget.enabled ? _pickFile : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _picked != null ? const Color(0xFF0EA5E9) : const Color(0xFFCBD5E1),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)]),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text('Drag & Drop your resume here', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        const Text('or click to browse files', style: TextStyle(color: AppColors.textMuted)),
                        const SizedBox(height: 2),
                        const Text(
                          'Supports PDF and DOCX',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                        if (_picked != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, color: Color(0xFF0EA5E9), size: 16),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _picked!.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: widget.enabled && _picked != null ? _submit : null,
                    icon: const Icon(Icons.smart_toy_outlined),
                    label: const Text('Analyze Resume with AI'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF0EA5E9).withValues(alpha: 0.6),
                      disabledForegroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _FeatureCard(
            iconBg: Color(0xFFDBEAFE),
            iconColor: Color(0xFF1D4ED8),
            icon: Icons.bar_chart,
            title: 'ATS Score',
            body: 'Get a percentage score showing how well your resume performs against Applicant Tracking Systems.',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _FeatureCard(
            iconBg: Color(0xFFDCFCE7),
            iconColor: Color(0xFF15803D),
            icon: Icons.done_all,
            title: 'Skills Matched',
            body: 'See exactly which of your skills align with the job requirements or your target profile.',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _FeatureCard(
            iconBg: Color(0xFFFEF9C3),
            iconColor: Color(0xFFA16207),
            icon: Icons.work_outline,
            title: 'Job Recommendations',
            body: 'Discover active job openings from our employer portal that match your profile and skills.',
          ),
        ],
      ),
    );
  }
}

/// `.resume-hero` (`resume_builder.html:160-169`) — dark navy→sky gradient
/// card, "AI-Powered" badge, H1, subtitle.
class _ResumeHero extends StatelessWidget {
  const _ResumeHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A5F), Color(0xFF0EA5E9)],
          stops: [0.0, 0.6, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x26FFFFFF),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: const Color(0x40FFFFFF)),
            ),
            child: const Text(
              'AI-Powered',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Resume Analysis & ATS Score',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Upload your resume to get an AI-powered evaluation of your skills, gaps, and relevant job opportunities.',
            style: TextStyle(color: Color(0xD9FFFFFF)),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.iconBg,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.body,
  });

  final Color iconBg;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

/// `.error-box` (`resume_builder.html:113-121,185-190`).
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: const TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
  }
}

/// `.loading-overlay`/`.loading-spinner` (`resume_builder.html:122-141,
/// 288-291`).
class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: const Color(0x990F172A),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(strokeWidth: 4, color: Color(0xFF0EA5E9)),
              ),
              SizedBox(height: AppSpacing.lg),
              Text(
                'Analyzing Your Resume...',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
              ),
              SizedBox(height: 6),
              Text('Our AI is reviewing your skills and experience', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

/// `templates/resume_match_result.html` — the ATS result body.
class _ResultView extends ConsumerWidget {
  const _ResultView({required this.result});

  final ResumeAnalysisResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = result.analysis;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Score header card (`resume_match_result.html:182-237`).
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 20)],
            ),
            child: Column(
              children: [
                ResumeScoreRing(
                  percentage: analysis.matchPercentage,
                  label: result.isAtsOnly ? 'ATS Score' : 'Match',
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  result.isAtsOnly ? 'Resume Analysis Complete' : 'Match Analysis Complete',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  analysis.summary,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                if (result.resumeValid == false && result.validationMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _ErrorBox(message: result.validationMessage!),
                ],
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      children: [
                        const WidgetSpan(
                          child: Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.work_outline, size: 14, color: AppColors.textMuted),
                          ),
                          alignment: PlaceholderAlignment.middle,
                        ),
                        const TextSpan(text: 'Detected Experience: '),
                        TextSpan(
                          text: result.yearsExperience >= 1
                              ? '${_formatYears(result.yearsExperience)} year${result.yearsExperience == 1 ? '' : 's'}'
                              : 'Fresher',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    if (result.canInterview)
                      _ActionButton(
                        label: 'Try Interview',
                        icon: Icons.play_circle_outline,
                        color: const Color(0xFF198754),
                        onTap: result.resumeValid == false
                            ? null
                            : () => context.push(RoutePaths.resumeInterviewPlaceholder),
                      )
                    else
                      _ActionButton(
                        label: 'Upgrade for AI Interview',
                        icon: Icons.workspace_premium_outlined,
                        color: const Color(0xFFFFC107),
                        textColor: Colors.black,
                        onTap: () => context.push(RoutePaths.pro),
                      ),
                    _ActionButton(
                      label: 'Analyze Another Resume',
                      icon: Icons.refresh,
                      color: Colors.transparent,
                      textColor: AppColors.textPrimary,
                      outlined: true,
                      onTap: () => ref.read(resumeBuilderControllerProvider.notifier).reset(),
                    ),
                    _ActionButton(
                      label: 'Resume History',
                      icon: Icons.history,
                      color: Colors.transparent,
                      textColor: AppColors.textPrimary,
                      outlined: true,
                      onTap: () => context.push(RoutePaths.resumeHistory),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Skills grid (`resume_match_result.html:239-277`).
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SkillsCard(
                  iconBg: const Color(0xFFDBEAFE),
                  iconColor: const Color(0xFF1D4ED8),
                  icon: Icons.check,
                  title: 'Matching Skills',
                  skills: analysis.matchingSkills,
                  emptyText: 'No exact matches found.',
                  chipBg: const Color(0xFFDBEAFE),
                  chipText: const Color(0xFF1D4ED8),
                  chipBorder: const Color(0xFFBFDBFE),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SkillsCard(
                  iconBg: const Color(0xFFFEE2E2),
                  iconColor: const Color(0xFFDC2626),
                  icon: Icons.close,
                  title: 'Missing Skills',
                  skills: analysis.missingSkills,
                  emptyText: 'No significant gaps found!',
                  chipBg: const Color(0xFFFEE2E2),
                  chipText: const Color(0xFFDC2626),
                  chipBorder: const Color(0xFFFECACA),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Complete Interview / Upgrade banner
          // (`resume_match_result.html:280-310`).
          if (result.canInterview)
            _Banner(
              gradient: const [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
              border: const Color(0xFF86EFAC),
              iconBg: const Color(0xFF22C55E),
              icon: Icons.lock_open,
              heading: '🎯 Complete the Interview to Unlock Job Recommendations',
              headingColor: const Color(0xFF15803D),
              body:
                  'Score 70 or above out of 100 in the AI-powered mock interview to get personalised, '
                  'experience-matched job opportunities.',
              ctaLabel: 'Take Interview',
              ctaIcon: Icons.play_arrow,
              ctaColor: const Color(0xFF198754),
              onTap: () => context.push(RoutePaths.resumeInterviewPlaceholder),
            )
          else
            _Banner(
              gradient: const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
              border: const Color(0xFFFCD34D),
              iconBg: const Color(0xFFF59E0B),
              icon: Icons.workspace_premium,
              heading: '🚀 Upgrade to Unlock the AI Interview & Job Recommendations',
              headingColor: const Color(0xFFB45309),
              body:
                  'Your Free plan includes Resume Parsing & ATS analysis. Upgrade to Normal (₹499/yr) for the '
                  '20-question AI mock interview — score 70 or above to unlock 5 experience-matched job opportunities.',
              ctaLabel: 'View Plans',
              ctaIcon: Icons.workspace_premium_outlined,
              ctaColor: const Color(0xFFFFC107),
              ctaTextColor: Colors.black,
              onTap: () => context.push(RoutePaths.pro),
            ),
          const SizedBox(height: AppSpacing.lg),
          const _ResumeTemplatesSection(),
          if (analysis.careerAdvice.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _AdviceCard(advice: analysis.careerAdvice),
          ],
        ],
      ),
    );
  }

  static String _formatYears(double years) {
    return years == years.roundToDouble() ? years.toInt().toString() : years.toStringAsFixed(1);
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.textColor = Colors.white,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        disabledBackgroundColor: color.withValues(alpha: 0.5),
        elevation: outlined ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: outlined ? const BorderSide(color: AppColors.border) : BorderSide.none,
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

class _SkillsCard extends StatelessWidget {
  const _SkillsCard({
    required this.iconBg,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.skills,
    required this.emptyText,
    required this.chipBg,
    required this.chipText,
    required this.chipBorder,
  });

  final Color iconBg;
  final Color iconColor;
  final IconData icon;
  final String title;
  final List<String> skills;
  final String emptyText;
  final Color chipBg;
  final Color chipText;
  final Color chipBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (skills.isEmpty)
            Text(emptyText, style: const TextStyle(color: AppColors.textMuted, fontStyle: FontStyle.italic, fontSize: 13))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final skill in skills)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: chipBg,
                      border: Border.all(color: chipBorder),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(skill, style: TextStyle(color: chipText, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.gradient,
    required this.border,
    required this.iconBg,
    required this.icon,
    required this.heading,
    required this.headingColor,
    required this.body,
    required this.ctaLabel,
    required this.ctaIcon,
    required this.ctaColor,
    required this.onTap,
    this.ctaTextColor = Colors.white,
  });

  final List<Color> gradient;
  final Color border;
  final Color iconBg;
  final IconData icon;
  final String heading;
  final Color headingColor;
  final String body;
  final String ctaLabel;
  final IconData ctaIcon;
  final Color ctaColor;
  final Color ctaTextColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        border: Border.all(color: border, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(heading, style: TextStyle(fontWeight: FontWeight.w700, color: headingColor)),
                    const SizedBox(height: 4),
                    Text(body, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(ctaIcon, size: 16),
              label: Text(ctaLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: ctaColor,
                foregroundColor: ctaTextColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.advice});

  final List<String> advice;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFFD97706)),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text('AI Suggestions', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          for (final item in advice)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Color(0xFFFEF3C7), shape: BoxShape.circle),
                    child: const Icon(Icons.star, size: 12, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(item, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "Recommended ATS Resume Templates" (`resume_match_result.html:312-455`)
/// — 3 static, publicly-downloadable `.docx` templates. Reproduces the
/// preview image + copy + download action; the web's own hover-zoom/
/// click-to-open lightbox modal is simplified to a plain full-screen image
/// viewer on tap (same preview image, no zoom microinteraction) — a
/// deliberate mobile simplification of a decorative interaction, not a
/// dropped feature (the image, copy, and download link are all preserved).
class _ResumeTemplatesSection extends StatelessWidget {
  const _ResumeTemplatesSection();

  static const _templates = [
    (
      asset: 'assets/images/template_modern_professional.png',
      badge: 'ATS Optimised',
      badgeColor: Color(0xFF0EA5E9),
      title: 'Modern Professional',
      description: 'Single-column, high-density keyword layout. Best for IT & corporate roles.',
      buttonColor: Color(0xFF14213D),
      downloadPath: '/static/templates/Modern_Professional_Resume.docx',
    ),
    (
      asset: 'assets/images/template_executive_tech.png',
      badge: 'Tech Focused',
      badgeColor: Color(0xFF059669),
      title: 'Executive Tech',
      description: 'Skills sidebar + project highlights. Ideal for tech & service desk roles.',
      buttonColor: Color(0xFF198754),
      downloadPath: '/static/templates/Executive_Tech_Resume.docx',
    ),
    (
      asset: 'assets/images/template_minimalist_career.png',
      badge: 'Fresher Friendly',
      badgeColor: Color(0xFF7C3AED),
      title: 'Minimalist Career',
      description: 'Sleek, minimal typography. Optimised for freshers & entry-level applicants.',
      buttonColor: Color(0xFF7C3AED),
      downloadPath: '/static/templates/Minimalist_Career_Resume.docx',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.description_outlined, size: 16, color: Color(0xFF0284C7)),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text('Recommended ATS Resume Templates', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Preview each template, then download the one you like to boost your ATS score:',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final template in _templates) ...[
            _TemplateCard(
              asset: template.asset,
              badge: template.badge,
              badgeColor: template.badgeColor,
              title: template.title,
              description: template.description,
              buttonColor: template.buttonColor,
              downloadPath: template.downloadPath,
            ),
            if (template != _templates.last) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.asset,
    required this.badge,
    required this.badgeColor,
    required this.title,
    required this.description,
    required this.buttonColor,
    required this.downloadPath,
  });

  final String asset;
  final String badge;
  final Color badgeColor;
  final String title;
  final String description;
  final Color buttonColor;
  final String downloadPath;

  void _openPreview(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(child: Image.asset(asset)),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _download() async {
    final uri = Uri.parse('${EnvironmentConfig.baseUrl}$downloadPath');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => _openPreview(context),
            child: Stack(
              children: [
                Image.asset(asset, height: 160, width: double.infinity, fit: BoxFit.cover, alignment: Alignment.topCenter),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(50)),
                    child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: const Color(0x8C0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Click to Preview', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _download,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download Template'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
