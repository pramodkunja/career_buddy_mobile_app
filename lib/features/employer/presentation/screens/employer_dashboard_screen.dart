import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_footer.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/app_nav_drawer.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/employer_dashboard_summary.dart';
import '../providers/employer_dashboard_providers.dart';

/// `jobs_app.views.employer_dashboard` (`templates/employer/dashboard.html`,
/// `templates/employer_base.html`) — parsed from the server-rendered HTML
/// (no JSON API exists, see `EmployerDashboardRemoteDataSource`'s doc
/// comment). Read-only display: per-job Delete (real confirm dialog + real
/// delete call, see [_deleteJob]) and the per-job Applications link (pushes
/// the real [EmployerJobApplicationsScreen]) are both fully built. The
/// "Post New Job Listing" CTA now opens the real `PostNewJobScreen`
/// (built against the live production form, not the committed, much
/// smaller `JobPostingForm` — see `ApiEndpoints.employerJobCreate`'s doc
/// comment). Only per-job Edit still routes to `ComingSoonScreen` — editing
/// an existing job was not re-verified against production this task and
/// remains deliberately deferred.
///
/// **Known limitation, not fabricated**: most self-registered employers
/// hit `_employer_profile_complete`'s GST+PAN gate
/// (`jobs_app/views.py:482-493`) and get redirected server-side to
/// `employer_profile_create` — a distinct screen this batch doesn't build
/// (out of its own explicit scope). That case renders
/// [_ProfileIncompleteView] instead of a generic error.
class EmployerDashboardScreen extends ConsumerWidget {
  const EmployerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(employerDashboardControllerProvider);

    ref.listen<AsyncValue<EmployerDashboardSummary>>(employerDashboardControllerProvider, (previous, next) {
      if (next.error is UnauthorizedFailure) {
        ref.read(authControllerProvider.notifier).logout();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(),
      drawer: const AppNavDrawer(),
      body: Stack(
        children: [
          switch (state) {
            AsyncData(value: final summary) => RefreshIndicator(
              onRefresh: () => ref.read(employerDashboardControllerProvider.notifier).retry(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _DashboardContent(summary: summary),
                    const AppFooter(showActivityStats: false, showBrandIcon: false),
                  ],
                ),
              ),
            ),
            AsyncError(:final error) when error is EmployerProfileIncompleteFailure => _ProfileIncompleteView(
              message: error.message,
            ),
            AsyncError(:final error) when error is! UnauthorizedFailure => AppErrorView(
              message: error is Failure ? error.message : 'Something went wrong. Please try again.',
              onRetry: () => ref.read(employerDashboardControllerProvider.notifier).retry(),
            ),
            _ => const AppLoader(message: 'Loading your dashboard...'),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.summary});

  final EmployerDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroBand(greetingName: summary.greetingName),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.work_outline,
                  iconBg: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF185ADB),
                  number: '${summary.totalJobsCount}',
                  label: 'Total Jobs',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_outline,
                  iconBg: const Color(0xFFECFDF5),
                  iconColor: const Color(0xFF10B981),
                  number: '${summary.activeJobs}',
                  numberColor: const Color(0xFF10B981),
                  label: 'Active Listings',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  icon: Icons.people_outline,
                  iconBg: const Color(0xFFFFFBEB),
                  iconColor: const Color(0xFFF59E0B),
                  number: '${summary.totalApps}',
                  numberColor: const Color(0xFFF59E0B),
                  label: 'Applications',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: const [
              Icon(Icons.list_alt, size: 16, color: Color(0xFF185ADB)),
              SizedBox(width: 6),
              Text(
                'MY JOB POSTINGS',
                style: TextStyle(color: Color(0xFF185ADB), fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (summary.jobs.isEmpty)
            const _EmptyJobsCard()
          else
            for (final job in summary.jobs) ...[
              _JobCard(job: job),
              const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }
}

/// `.employer-hero-band` (`dashboard.html:134-171`) — greeting + "Post New
/// Job Listing" CTA (routes to a `ComingSoonScreen`, out of scope).
class _HeroBand extends StatelessWidget {
  const _HeroBand({required this.greetingName});

  final String greetingName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)]),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x1A185ADB),
              border: Border.all(color: const Color(0x33185ADB)),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Text(
              'RECRUITER PORTAL',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 11),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Welcome back, $greetingName!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
          ),
          const SizedBox(height: 6),
          Text(
            'Manage job listings, review candidates, and hire top talent from Career Buddy.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Post New Job Listing',
            icon: Icons.add_circle_outline,
            fullWidth: false,
            backgroundColor: const Color(0xFF185ADB),
            foregroundColor: Colors.white,
            onPressed: () => context.push(RoutePaths.employerJobCreate),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.number,
    required this.label,
    this.numberColor,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String number;
  final String label;
  final Color? numberColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: numberColor ?? AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JobCard extends ConsumerWidget {
  const _JobCard({required this.job});

  final EmployerJobListItem job;

  Color get _statusColor => switch (job.status) {
    'active' => const Color(0xFF10B981),
    'closed' => const Color(0xFFF43F5E),
    _ => AppColors.textMuted,
  };

  String get _statusLabel => switch (job.status) {
    'active' => 'Active',
    'closed' => 'Closed',
    _ => 'Draft',
  };

  Future<void> _editJob(BuildContext context) {
    // `job_edit` has no safe Flutter destination yet — the live production
    // form diverges from this repo's `JobPostingForm` (see
    // `ApiEndpoints.employerJobCreate`'s doc comment), so this stays an
    // honest "not available" notice rather than a route to a form that
    // could submit the wrong contract.
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Job'),
        content: const Text('Editing a job isn\'t available in the app yet. Please visit the Career Buddy website for now.'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _deleteJob(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        // Verbatim web wording (`dashboard.html:251`'s
        // `confirm('Delete this job?')`), not invented copy.
        content: const Text('Delete this job?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await ref.read(employerDashboardControllerProvider.notifier).deleteJob(job.jobId);
    if (!context.mounted) return;
    switch (result) {
      case Success():
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job deleted.')));
      case Failed(failure: final failure):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(job.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(color: _statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (job.jobType.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(50)),
                  child: Text(job.jobType, style: const TextStyle(color: Color(0xFF185ADB), fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              InkWell(
                onTap: () => context.push(RoutePaths.employerJobApplications(job.jobId)),
                borderRadius: BorderRadius.circular(50),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_outline, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('${job.applicationsCount} applications', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              if (job.postedDate.isNotEmpty)
                Text(job.postedDate, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textMuted),
                onPressed: () => _editJob(context),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFF43F5E)),
                onPressed: () => _deleteJob(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// `{% empty %}` branch (`dashboard.html:257-263`) — verbatim copy.
class _EmptyJobsCard extends StatefulWidget {
  const _EmptyJobsCard();

  @override
  State<_EmptyJobsCard> createState() => _EmptyJobsCardState();
}

class _EmptyJobsCardState extends State<_EmptyJobsCard> {
  late final TapGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = TapGestureRecognizer()..onTap = () => context.push(RoutePaths.employerJobCreate);
  }

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Icon(Icons.work_outline, size: 40, color: Color(0xFFCBD5E1)),
          const SizedBox(height: AppSpacing.sm),
          Text.rich(
            TextSpan(
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
              children: [
                const TextSpan(text: 'No jobs posted yet. '),
                TextSpan(
                  text: 'Post your first job!',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                  recognizer: _recognizer,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProfileIncompleteView extends StatelessWidget {
  const _ProfileIncompleteView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.business_center_outlined, size: 40, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Complete Company Profile',
              icon: Icons.edit_outlined,
              onPressed: () => context.push(RoutePaths.employerCompanyProfileCreate),
            ),
          ],
        ),
      ),
    );
  }
}
