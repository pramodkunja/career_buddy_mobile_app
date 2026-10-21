import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../dashboard/domain/entities/recommended_job.dart';
import '../../domain/entities/interview_analytics.dart';

/// Mirrors `resume_analytics.html`'s summary + per-question breakdown —
/// every number here is exactly what `resume_analytics` returned (see
/// `mock_interview_html_parser.dart`), never locally computed.
class MockInterviewResultsView extends StatelessWidget {
  const MockInterviewResultsView({required this.analytics, super.key});

  final InterviewAnalyticsResult analytics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passColor = analytics.isPassed ? Colors.green.shade700 : Colors.red.shade700;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: analytics.isPassed ? Colors.green.shade50 : Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  // Phase 46 — `resume_analytics.html:207,237`, confirmed
                  // directly: both the pass and fail badges name the exact
                  // threshold, not just a plain "Qualified"/"Action
                  // Required" label.
                  analytics.isPassed
                      ? 'Qualified Candidate (Score ≥ $kInterviewPassingScore/100)'
                      : 'Action Required (Score < $kInterviewPassingScore/100)',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(color: passColor, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${analytics.totalScore}',
                  key: const Key('total-score-value'),
                  style: theme.textTheme.displayMedium?.copyWith(color: passColor, fontWeight: FontWeight.w800),
                ),
                Text('TOTAL SCORE / 100', style: theme.textTheme.labelMedium),
                if (!analytics.isPassed) ...[
                  const SizedBox(height: 12),
                  Text(
                    'You should upgrade your skill.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Refer to the skill upgradation courses on our website to boost your technical '
                    'competence and re-interview.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  // `resume_analytics.html:241-245` — always shown when
                  // `!is_passed` (`skillup_url` is only ever `None` on the
                  // `is_passed` branch, confirmed directly,
                  // `career_app/views.py:1871`).
                  ElevatedButton.icon(
                    key: const Key('interview-skill-up-button'),
                    onPressed: () => context.push(RoutePaths.skillUpSections),
                    icon: const Icon(Icons.school_outlined, size: 16),
                    label: const Text('Skill up yourself'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _StatTile(label: 'Answered', value: '${analytics.answeredCount}/${analytics.totalQuestions}')),
            Expanded(child: _StatTile(label: 'Avg Score', value: '${analytics.avgScore.toStringAsFixed(1)}/5')),
          ],
        ),
        const SizedBox(height: 20),
        Text('Question Breakdown', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final q in analytics.questionResults) _QuestionResultTile(result: q),
        if (!analytics.isPassed) ...[
          const SizedBox(height: 20),
          const _SkillUpgradationCoursesCard(),
        ],
        if (analytics.suitableJobs.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SuitableJobsSection(jobs: analytics.suitableJobs, yearsExperience: analytics.yearsExperience),
        ],
      ],
    );
  }
}

/// Mirrors `resume_analytics.html:350-409`'s "Recommended Job Opportunities"
/// card. The web only renders this at all when `is_passed and suitable_jobs`
/// (`resume_analytics.html:350`) — this widget is only ever built from the
/// results view above when [InterviewAnalyticsResult.suitableJobs] is
/// non-empty, which (per [parseInterviewAnalyticsHtml]) can only be true
/// when the web itself rendered the section, so "not passed" and "passed
/// with zero matches" both correctly fall through to no section at all,
/// same as the web.
///
/// A small, Mock-Interview-scoped widget rather than a reuse of
/// `recommended_jobs_section.dart`'s card — that file's `_JobCard` etc. are
/// private to Dashboard, and this codebase's own convention (e.g. the GD/JAM
/// language pickers) is to duplicate a small per-feature widget rather than
/// make another feature's private widgets public.
/// Phase 46 — `resume_analytics.html:309-358`'s "Recommended Skill
/// Upgradation Courses" card, confirmed directly: static markup, not
/// server-templated data (the 3 category links and the final "View All"
/// link, including its literal "23", are hardcoded in the real template —
/// nothing here is invented). Shown whenever `not is_passed`, same gate as
/// the results view's own top-banner "Skill up yourself" button, reusing
/// the exact same existing Activities list + category-filter mechanism the
/// landing page's own Skill Up teaser already uses
/// (`RoutePaths.activitiesWithCategory`).
class _SkillUpgradationCoursesCard extends StatelessWidget {
  const _SkillUpgradationCoursesCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recommended Skill Upgradation Courses', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Master these core activities to raise your score to $kInterviewPassingScore/100 and unlock '
              'top employer job offers.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _CourseTile(
              icon: Icons.forum_outlined,
              title: 'Business Communication & Speaking',
              body: 'Practice oral fluency, interview articulation, and presentation skills.',
              onTap: () => context.push(RoutePaths.activitiesWithCategory('speaking')),
            ),
            const SizedBox(height: 8),
            _CourseTile(
              icon: Icons.edit_note_outlined,
              title: 'Professional Email & Report Writing',
              body: 'Master corporate correspondence, technical writing, and grammar.',
              onTap: () => context.push(RoutePaths.activitiesWithCategory('writing')),
            ),
            const SizedBox(height: 8),
            _CourseTile(
              icon: Icons.handshake_outlined,
              title: 'Negotiation & Technical Discussion',
              body: 'Learn interview negotiation tactics, team collaboration, and debate.',
              onTap: () => context.push(RoutePaths.activitiesWithCategory('negotiation')),
            ),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => context.push(RoutePaths.activities),
                icon: const Icon(Icons.grid_view_outlined, size: 16),
                label: const Text('View All 23 Skill Learning Activities'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  const _CourseTile({required this.icon, required this.title, required this.body, required this.onTap});

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 6),
          Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(body, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Start Course'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuitableJobsSection extends StatelessWidget {
  const _SuitableJobsSection({required this.jobs, required this.yearsExperience});

  final List<RecommendedJob> jobs;
  final double yearsExperience;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recommended Job Opportunities', style: theme.textTheme.titleMedium),
                      Text(
                        'Matched for candidate experience (${yearsExperience.toStringAsFixed(1)} years) '
                        '& verified skills.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${jobs.length} Matched Job${jobs.length == 1 ? '' : 's'}',
                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.green.shade800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final job in jobs) ...[_SuitableJobCard(job: job), const SizedBox(height: 10)],
          ],
        ),
      ),
    );
  }
}

class _SuitableJobCard extends StatelessWidget {
  const _SuitableJobCard({required this.job});

  final RecommendedJob job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // `resume_analytics.html:357`: only shows the first 3 skills
    // (`{{ job.get_skills_list|slice:":3" }}`), same as the dashboard card.
    final visibleSkills = job.skills.take(3);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.apartment_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.title, style: theme.textTheme.titleSmall),
                    Text(job.companyName, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final skill in visibleSkills)
                Chip(
                  label: Text(skill, style: theme.textTheme.labelSmall),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: theme.hintColor),
              const SizedBox(width: 2),
              Expanded(child: Text(job.location, style: theme.textTheme.bodySmall)),
              Text(job.jobType, style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.timeline_outlined, size: 14, color: theme.hintColor),
              const SizedBox(width: 2),
              Text(job.experienceLevel, style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            job.salaryDisplay,
            style: theme.textTheme.titleSmall?.copyWith(color: Colors.green.shade800, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              // `job.id` is the real `job.pk` scraped from this exact card's
              // own link (see `RecommendedJob.id`'s doc comment), reusing
              // the same public job-detail screen Phase 4 already wired for
              // Dashboard's recommended jobs — never a fabricated or
              // guessed destination. `null` only disables the button,
              // it never navigates anywhere.
              onPressed: job.id == null ? null : () => context.push(RoutePaths.publicJobDetail(job.id!)),
              icon: const Icon(Icons.send_outlined, size: 16),
              label: const Text('View & Apply'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _QuestionResultTile extends StatelessWidget {
  const _QuestionResultTile({required this.result});
  final InterviewQuestionResult result;

  @override
  Widget build(BuildContext context) {
    final scoreColor = result.score >= 4
        ? Colors.green.shade700
        : result.score >= 2
            ? Colors.orange.shade800
            : Colors.red.shade700;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(result.topic, style: Theme.of(context).textTheme.labelLarge)),
                Chip(
                  label: Text('${result.score}/5'),
                  backgroundColor: scoreColor.withValues(alpha: 0.12),
                  labelStyle: TextStyle(color: scoreColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(result.question, style: Theme.of(context).textTheme.bodyMedium),
            if (result.feedback.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                result.feedback,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
