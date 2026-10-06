import 'package:career_buddy_lms/app/theme/activity_hero_colors.dart';
import 'package:career_buddy_lms/shared/widgets/exercise_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _pageHtml = '''
<div class="exercise-hero bg-success" style="position: relative;">
  <div class="container py-4">
    <nav aria-label="breadcrumb" class="mb-2">
      <ol class="breadcrumb breadcrumb-light mb-0">
        <li class="breadcrumb-item"><a href="/activities/1/">Business Negotiation Simulation</a></li>
        <li class="breadcrumb-item"><a href="/activities/sub/2/">Live Negotiation and Debrief</a></li>
        <li class="breadcrumb-item active">Exercise</li>
      </ol>
    </nav>
  </div>
</div>
''';

void main() {
  group('extractExerciseHeroMeta', () {
    test('extracts the color slug and both breadcrumb titles', () {
      final meta = extractExerciseHeroMeta(_pageHtml);
      expect(meta.colorSlug, 'success');
      expect(meta.activityTitle, 'Business Negotiation Simulation');
      expect(meta.subActivityTitle, 'Live Negotiation and Debrief');
    });

    test('unescapes HTML entities in breadcrumb titles', () {
      const html = '''
        <div class="exercise-hero bg-info">
          <li class="breadcrumb-item"><a href="#">Listen &amp; Write</a></li>
          <li class="breadcrumb-item"><a href="#">R&amp;D Sub-Activity</a></li>
        </div>
      ''';
      final meta = extractExerciseHeroMeta(html);
      expect(meta.activityTitle, 'Listen & Write');
      expect(meta.subActivityTitle, 'R&D Sub-Activity');
    });

    test('returns all-null fields when the markup is absent (e.g. a locked-activity redirect page)', () {
      final meta = extractExerciseHeroMeta('<html><body>Redirecting…</body></html>');
      expect(meta.colorSlug, isNull);
      expect(meta.activityTitle, isNull);
      expect(meta.subActivityTitle, isNull);
    });
  });

  group('resolveActivityHeroGradient', () {
    test('resolves every known color_class slug', () {
      for (final slug in [
        'primary',
        'success',
        'danger',
        'warning',
        'info',
        'purple',
        'pink',
        'teal',
        'orange',
        'indigo',
        'rose',
        'emerald',
      ]) {
        expect(resolveActivityHeroGradient(slug), isNotNull, reason: 'slug: $slug');
      }
    });

    test('returns null for an unrecognized or missing slug', () {
      expect(resolveActivityHeroGradient('not-a-real-slug'), isNull);
      expect(resolveActivityHeroGradient(null), isNull);
    });

    test('primary resolves to navy — the final, cascade-winning override, not the first blue declaration', () {
      final (start, end) = resolveActivityHeroGradient('primary')!;
      expect(start, const Color(0xFF14213D));
      expect(end, const Color(0xFF0B1526));
    });
  });
}
