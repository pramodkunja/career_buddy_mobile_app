import '../../../core/utils/date_format.dart';
import '../../../core/utils/html_unescape.dart';
import '../../ai_listening/domain/services/listening_module_detection.dart';
import '../../ai_reading/domain/services/reading_module_detection.dart';
import '../../ai_speaking/domain/services/speaking_module_detection.dart';
import '../../ai_writing/domain/services/writing_module_detection.dart';
import '../domain/entities/activity_category.dart';
import '../domain/entities/activity_detail.dart';
import '../domain/entities/activity_list_data.dart';
import '../domain/entities/activity_summary.dart';
import '../domain/entities/exercise_attempt.dart';
import '../domain/entities/exercise_summary.dart';
import '../domain/entities/sub_activity_detail.dart';
import '../domain/entities/sub_activity_status.dart';
import '../domain/entities/sub_activity_summary.dart';

/// Regex extraction against `activities.views.activity_list` /
/// `activity_detail` / `sub_activity_detail`'s server-rendered HTML
/// (`templates/activities/list.html` / `detail.html` / `sub_activity.html`)
/// — the same "scrape the real, live page instead of the documented but
/// undeployed JSON sibling" technique already used for the dashboard (see
/// `dashboard_html_parser.dart`'s top-level doc comment for the full
/// reasoning). Confirmed live this session: anonymous `GET`s to
/// `/activities/api/`, `/activities/api/<id>/`, and
/// `/activities/api/sub/<id>/` all 404 (undeployed), while `/activities/`,
/// `/activities/<id>/`, and `/activities/<id>/sub/<id>/` all 302 to the
/// login page (the expected `@login_required` behavior) — exactly the
/// pattern this session already confirmed for the dashboard.

bool isActivityListHtml(String html) => html.contains('class="activities-page"');

bool isActivityDetailHtml(String html) => html.contains('class="activity-detail-page"');

bool isSubActivityDetailHtml(String html) => html.contains('sub-activity-hero');

/// Splits a section of [html] into one slice per occurrence of a [marker]
/// regex, each running from just after the match to the next match (or
/// [maxLength] characters for the last one) — the same technique already
/// used by `employer_candidate_search_html_parser.dart` /
/// `job_openings_html_parser.dart`, needed because these cards' real
/// `class="..."` attributes span lines the naive `dashboard_html_parser`-
/// style literal-substring marker can't match (`<div\n  class="...">`, not
/// `<div class="...">` on one line).
List<String> _splitCards(String html, RegExp marker, {int maxLength = 4000}) {
  final starts = [for (final m in marker.allMatches(html)) m.end];
  return [
    for (var i = 0; i < starts.length; i++)
      html.substring(starts[i], i + 1 < starts.length ? starts[i + 1] : (starts[i] + maxLength).clamp(0, html.length)),
  ];
}

ActivityListData parseActivityListHtml(String html) {
  if (!isActivityListHtml(html)) {
    throw const FormatException('Not an activity list page');
  }

  final categories = [
    for (final m in RegExp(r'module-card mod-([\w-]+)[^"]*">\s*<div class="mod-icon">.*?<span class="mod-label">([^<]*)</span>', dotAll: true).allMatches(html))
      if (m.group(1) != 'all') ActivityCategory(value: m.group(1)!, label: _unescape(m.group(2)!.trim())),
  ];

  // `mod-active` on a chip other than the implicit "All" one — matches
  // `list.html`'s own `{% if selected_category == value %}mod-active{% endif %}`.
  final activeMatch = RegExp(r'module-card mod-([\w-]+)[^"]*mod-active').firstMatch(html);
  final selectedCategory = (activeMatch == null || activeMatch.group(1) == 'all') ? '' : activeMatch.group(1)!;

  final isFreePreview = html.contains('Free Plan — choose any one');

  final activities = <ActivitySummary>[];
  for (final card in _splitCards(html, RegExp(r'class="activity-card[^"]*">'))) {
    final hrefMatch = RegExp(r'<a href="(?:[^"]*?/activities/(\d+)/|([^"]+))"\s+class="btn btn-primary w-100">').firstMatch(card);
    final isLocked = card.contains('js-locked-activity');
    final idFromHref = hrefMatch?.group(1) != null ? int.tryParse(hrefMatch!.group(1)!) : null;

    final titleMatch = RegExp(r'class="activity-title">([^<]*)</h5>').firstMatch(card);
    if (titleMatch == null) continue;
    final title = _unescape(titleMatch.group(1)!.trim());
    final objectiveMatch = RegExp(r'class="activity-objective">([^<]*)</p>').firstMatch(card);
    final levelMatch = RegExp(r'class="badge-level">([^<]*)</span>').firstMatch(card);
    final categoryDisplayMatch = RegExp(r'class="badge-category" title="([^"]*)"').firstMatch(card);
    // The raw `category` slug isn't printed as text anywhere on this page
    // (only its icon class and display title are) — recovered from
    // whichever `fa-*` icon this card's badge actually rendered, same
    // fixed icon↔category mapping `list.html` itself uses.
    final category = _categorySlugFromIcon(card);
    final rateMatch = RegExp(r'<small class="fw-semibold[^"]*">\s*([\d.]+)%</small>').firstMatch(card);
    final rate = rateMatch != null ? (double.tryParse(rateMatch.group(1)!) ?? 0).round() : 0;

    activities.add(
      ActivitySummary(
        // A locked card's id is never used for navigation (the parent
        // screen shows an upgrade dialog instead of routing for any
        // `isLocked` card — confirmed in `ActivityListScreen`), so any
        // placeholder is safe there. A card with no real activity pk in
        // its href (`direct_url` set — real on the web for workshop/AI
        // module activities, whose `href` instead points straight at
        // their own dedicated page/exercise, bypassing `activity_detail`
        // entirely) gets a synthetic negative id instead of being dropped
        // — `ActivitiesRemoteDataSource.getActivityDetail` recognizes a
        // negative id and re-derives a minimal `ActivityDetail` from this
        // same list parse rather than requesting a real detail page that
        // doesn't exist for these activities.
        //
        // Derived from the title's hash, not the card's position in
        // *this* parse — confirmed live as a real, reproducible bug: a
        // position-based id (e.g. `-(activities.length + 1)`) is only
        // stable across repeated parses of the exact same page variant.
        // `ActivityListScreen`'s own category filter (e.g. "Interactive
        // Workshop") parses a *different* page than
        // `_activityDetailFallback`'s own unfiltered re-fetch
        // (`getActivityList()`, no category) — the same activity lands at
        // a different position in each, so the id computed while viewing
        // a filtered category never matches what the fallback looks up
        // afterward, and the detail screen 404s ("We couldn't find what
        // you were looking for") for every workshop/module activity
        // reached through a category filter. A title-derived id is the
        // same in both parses regardless of position, closing that gap.
        id: idFromHref ?? -(title.hashCode.abs() % 1000000 + 1),
        title: title,
        description: _unescape(objectiveMatch?.group(1)?.trim() ?? ''),
        category: category,
        categoryDisplay: _unescape(categoryDisplayMatch?.group(1)?.trim() ?? ''),
        level: _unescape(levelMatch?.group(1)?.trim() ?? ''),
        // Not rendered on this page (`list.html` has no duration badge per
        // card, unlike `detail.html`'s hero) — honest empty default, not
        // fabricated; not read by `ActivityCard` either (confirmed: it
        // renders `level`/`categoryDisplay` only).
        duration: '',
        isLocked: isLocked,
        completionRate: rate,
        isCompleted: rate == 100,
      ),
    );
  }

  return ActivityListData(
    activities: activities,
    categories: categories,
    selectedCategory: selectedCategory,
    isFreePreview: isFreePreview,
    // The real `total_activities` counter is only ever shown inside
    // free-text prose (`"{{ total_activities }} comprehensive
    // activities..."`), not a value this parser should regex out of a
    // sentence — the actual parsed list length is the same number in
    // every non-free-preview case and is what callers actually use.
    totalActivities: activities.length,
  );
}

const _categoryIcons = {
  'fa-microphone': 'speaking',
  'fa-pen': 'writing',
  'fa-puzzle-piece': 'vocabulary',
  'fa-handshake': 'negotiation',
  'fa-globe': 'communication',
  'fa-chart-pie': 'analysis',
  'fa-chalkboard-teacher': 'workshop',
};

String _categorySlugFromIcon(String card) {
  final badgeMatch = RegExp(r'class="badge-category"[^>]*>([\s\S]*?)</span>').firstMatch(card);
  final badge = badgeMatch?.group(1) ?? '';
  for (final entry in _categoryIcons.entries) {
    if (badge.contains(entry.key)) return entry.value;
  }
  return '';
}

/// Builds a minimal [ActivityDetail] for an activity whose real detail
/// page is genuinely unreachable this way — either a workshop/module
/// activity (its list card carries no activity pk at all, only a
/// `direct_url` straight to its own dedicated page/exercise — see
/// [parseActivityListHtml]'s `id` doc comment) or a positive id whose
/// `/activities/<id>/` request redirected somewhere other than the login
/// or locked-upgrade pages (same reasoning). [subActivities] is honestly
/// empty — this activity's sub-activity list, specifically, only exists
/// on the very page this function is a substitute for.
ActivityDetail activityDetailFromSummary(ActivitySummary summary) {
  return ActivityDetail(
    id: summary.id,
    title: summary.title,
    description: summary.description,
    category: summary.category,
    categoryDisplay: summary.categoryDisplay,
    level: summary.level,
    duration: summary.duration,
    isWorkshop: summary.category == 'workshop',
    isModule:
        isSpeakingModuleActivity(summary.title) ||
        isWritingModuleActivity(summary.title) ||
        isListeningModuleActivity(summary.title) ||
        isReadingModuleActivity(summary.title),
    completionRate: summary.completionRate,
    subActivities: const [],
  );
}

/// Parses `detail.html` itself — only ever reachable for a "normal"
/// (non-workshop, non-module) activity, since the real `activity_detail`
/// view redirects away *before* rendering this template for workshop/
/// module activities (confirmed by reading the view directly: it checks
/// `is_workshop_activity`/`is_module_activity` and `redirect()`s for both,
/// prior to building any template context) — so [isWorkshop]/[isModule]
/// are always `false` for any page this function successfully parses.
/// `ActivitiesRemoteDataSource.getActivityDetail` handles the redirect
/// case separately (falling back to the list page's own per-card data).
ActivityDetail parseActivityDetailHtml(String html, {required int id}) {
  if (!isActivityDetailHtml(html)) {
    throw const FormatException('Not an activity detail page');
  }

  final titleMatch = RegExp(r'class="activity-hero-title">([^<]*)</h1>').firstMatch(html);
  final objectiveMatch = RegExp(r'class="activity-hero-objective">([^<]*)</p>').firstMatch(html);
  final levelMatch = RegExp(r'fa-signal me-2"></i>([^<]*)</span>').firstMatch(html);
  final durationMatch = RegExp(r'fa-clock me-2"></i>([^<]*)</span>').firstMatch(html);
  final completionMatch = RegExp(r'class="ring-value">([\d.]+)%</div>').firstMatch(html);

  final subActivities = <SubActivitySummary>[];
  for (final card in _splitCards(html, RegExp(r'class="sub-activity-card[^"]*">'))) {
    final idMatch = RegExp(r'/activities/\d+/sub/(\d+)/"').firstMatch(card);
    final titleM = RegExp(r'class="sub-title">([^<]*)</h5>').firstMatch(card);
    if (idMatch == null || titleM == null) continue;

    final descMatch = RegExp(r'class="sub-description">([^<]*)</p>').firstMatch(card);
    final statusMatch = RegExp(r'class="sub-status-badge status-([\w]+)"').firstMatch(card);
    final exerciseCountMatch = RegExp(r'fa-gamepad me-1"></i>(\d+) Exercise').firstMatch(card);
    final startedMatch = RegExp(r'Started\s+([A-Za-z]{3}\s+\d{1,2}\s+\d{4})').firstMatch(card);
    final completedMatch = RegExp(r'Completed\s+([A-Za-z]{3}\s+\d{1,2}\s+\d{4})').firstMatch(card);

    subActivities.add(
      SubActivitySummary(
        id: int.parse(idMatch.group(1)!),
        title: _unescape(titleM.group(1)!.trim()),
        description: _unescape(descMatch?.group(1)?.trim() ?? ''),
        order: subActivities.length + 1,
        status: SubActivityStatus.fromWire(statusMatch?.group(1) ?? 'not_started'),
        exerciseCount: int.tryParse(exerciseCountMatch?.group(1) ?? '') ?? 0,
        startedAt: startedMatch != null ? _parseSpacedDate(startedMatch.group(1)!) : null,
        completedAt: completedMatch != null ? _parseSpacedDate(completedMatch.group(1)!) : null,
      ),
    );
  }

  final title = _unescape(titleMatch?.group(1)?.trim() ?? '');
  return ActivityDetail(
    id: id,
    title: title,
    description: _unescape(objectiveMatch?.group(1)?.trim() ?? ''),
    // Not rendered anywhere on this page (confirmed by reading the full
    // template) — `ActivityDetailScreen` doesn't read either field either
    // (only `isWorkshop`/`isModule`/`duration` matter functionally), so an
    // honest empty default costs nothing. `isWorkshop`/`isModule` are the
    // real signal this screen branches on.
    category: '',
    categoryDisplay: '',
    level: _unescape(levelMatch?.group(1)?.trim() ?? ''),
    duration: _unescape(durationMatch?.group(1)?.trim() ?? ''),
    isWorkshop: false,
    isModule:
        isSpeakingModuleActivity(title) ||
        isWritingModuleActivity(title) ||
        isListeningModuleActivity(title) ||
        isReadingModuleActivity(title),
    completionRate: completionMatch != null ? (double.tryParse(completionMatch.group(1)!) ?? 0).round() : 0,
    subActivities: subActivities,
  );
}

SubActivityDetail parseSubActivityDetailHtml(String html, {required int activityId}) {
  if (!isSubActivityDetailHtml(html)) {
    throw const FormatException('Not a sub-activity detail page');
  }

  final subIdMatch = RegExp(r'/activities/sub/(\d+)/complete/"').firstMatch(html);
  final titleMatch = RegExp(r'<h2 class="text-white mb-0">([^<]*)</h2>').firstMatch(html);
  final orderMatch = RegExp(r'Sub-Activity (\d+) of (\d+)').firstMatch(html);
  final activityTitleMatch = RegExp(r'<li class="breadcrumb-item"><a href="[^"]*">([^<]*)</a></li>\s*<li class="breadcrumb-item active">').firstMatch(html);
  final statusBadgeMatch = RegExp(r'<span class="badge (?:bg-success|bg-warning text-dark|bg-secondary) px-3 py-2">\s*(?:<i[^>]*></i>)?(Completed|In Progress|Not Started)').firstMatch(html);
  final descMatch = RegExp(r'<span id="descOverview">([\s\S]*?)</span>').firstMatch(html);
  final instructionsMatch = RegExp(r'id="instructionsBox">([\s\S]*?)</div>').firstMatch(html);
  final allDoneMatch = !html.contains('Please complete all interactive exercises first');
  final completedAtMatch = RegExp(r'Sub-activity completed on ([A-Za-z]+ \d{1,2}, \d{4})').firstMatch(html);

  final exercises = <ExerciseSummary>[];
  for (final card in _splitCards(html, RegExp(r'class="exercise-card">'))) {
    final exIdMatch = RegExp(r'/activities/exercise/(\d+)/"').firstMatch(card);
    final exTitleMatch = RegExp(r'class="exercise-title">([^<]*)</h6>').firstMatch(card);
    final typeMatch = RegExp(r'exercise-type-icon exercise-([\w]+)"').firstMatch(card);
    final typeLabelMatch = RegExp(r'class="exercise-type-label">([^<]*)</div>').firstMatch(card);
    if (exIdMatch == null || exTitleMatch == null || typeMatch == null) continue;

    final scoreMatch = RegExp(r'<strong>(\d+)/(\d+)</strong>').firstMatch(card);
    final pctMatch = RegExp(r'">\s*([\d.]+)%\s*</span>').firstMatch(card);

    exercises.add(
      ExerciseSummary(
        id: int.parse(exIdMatch.group(1)!),
        title: _unescape(exTitleMatch.group(1)!.trim()),
        exerciseType: typeMatch.group(1)!,
        exerciseTypeDisplay: _unescape(typeLabelMatch?.group(1)?.trim() ?? ''),
        order: exercises.length + 1,
        lastAttempt: scoreMatch == null
            ? null
            : ExerciseAttempt(
                score: int.parse(scoreMatch.group(1)!),
                maxScore: int.parse(scoreMatch.group(2)!),
                percentage: pctMatch != null ? (double.tryParse(pctMatch.group(1)!) ?? 0).round() : 0,
                // Neither is rendered on this page (only score/max_score/
                // percentage are — confirmed by reading the full template)
                // — honest placeholders, not fabricated; no widget reads
                // either field off a freshly-scraped `lastAttempt` today
                // (confirmed: `ExerciseTile` reads score/maxScore/
                // percentage only).
                attemptNumber: 1,
                completedAt: DateTime.now(),
              ),
      ),
    );
  }

  return SubActivityDetail(
    id: subIdMatch != null ? int.parse(subIdMatch.group(1)!) : -1,
    title: _unescape(titleMatch?.group(1)?.trim() ?? ''),
    description: _unescape(descMatch?.group(1)?.trim() ?? ''),
    instructions: _stripTags(instructionsMatch?.group(1) ?? ''),
    order: orderMatch != null ? int.parse(orderMatch.group(1)!) : 1,
    activityId: activityId,
    activityTitle: _unescape(activityTitleMatch?.group(1)?.trim() ?? ''),
    status: switch (statusBadgeMatch?.group(1)) {
      'Completed' => SubActivityStatus.completed,
      'In Progress' => SubActivityStatus.inProgress,
      _ => SubActivityStatus.notStarted,
    },
    allExercisesDone: allDoneMatch,
    exercises: exercises,
    // Neither is rendered as a separate field on this page — `started_at`
    // isn't shown at all here (only on `detail.html`'s sub-activity
    // cards), and `completed_at` is only shown as display text when
    // already completed, parsed above when present.
    startedAt: null,
    completedAt: completedAtMatch != null ? _parseLongDate(completedAtMatch.group(1)!) : null,
  );
}

DateTime? _parseSpacedDate(String text) {
  // `"M d Y h:i A"` with the year unseparated from the day by a comma
  // (`dashboard.html`'s dates use `"M d, Y"` — a comma — this page's
  // `item.started_at|date:"M d Y h:i A"` doesn't), so `parseMonthDayYear`
  // (which expects the comma) doesn't apply directly — reuses the same
  // month-abbreviation table via a small adapter instead of duplicating it.
  final parts = text.split(RegExp(r'\s+'));
  if (parts.length < 3) return null;
  return parseMonthDayYear('${parts[0]} ${parts[1]}, ${parts[2]}');
}

DateTime? _parseLongDate(String text) {
  // `"F d, Y"` (full month name) vs `parseMonthDayYear`'s abbreviated-month
  // table — truncate to the first 3 letters of the month before delegating.
  final match = RegExp(r'^([A-Za-z]+)\s+(\d{1,2}),\s*(\d{4})$').firstMatch(text.trim());
  if (match == null) return null;
  final month = match.group(1)!;
  final abbrev = month.length >= 3 ? month.substring(0, 3) : month;
  return parseMonthDayYear('$abbrev ${match.group(2)}, ${match.group(3)}');
}

String _stripTags(String html) => _unescape(html.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim());

String _unescape(String value) => unescapeHtmlEntities(value);
