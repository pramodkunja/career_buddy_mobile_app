import 'package:career_buddy_lms/app/config/environment.dart';
import 'package:career_buddy_lms/features/skill_up/domain/skill_up_lesson_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildSkillUpLessonUrl', () {
    test('encodes a simple nested path under the real static directory', () {
      final url = buildSkillUpLessonUrl('001 CEFR/cefr_a1_english.html');

      expect(url, '${EnvironmentConfig.baseUrl}/static/001%20Career%20Buddy/001%20CEFR/cefr_a1_english.html');
      expect(Uri.tryParse(url), isNotNull);
      expect(Uri.parse(url).isAbsolute, isTrue);
    });

    test('encodes spaces and parentheses in a filename', () {
      final url = buildSkillUpLessonUrl('GrammerActivities/grammar-activities (1).html');

      final uri = Uri.parse(url);
      expect(uri.isAbsolute, isTrue);
      // The path segment itself is percent-encoded; decoding it back
      // recovers the original literal filename with its space and
      // parentheses intact.
      final lastSegment = uri.pathSegments.last;
      expect(Uri.decodeComponent(lastSegment), 'grammar-activities (1).html');
      expect(url, contains('GrammerActivities/grammar-activities%20'));
      expect(url, isNot(contains(' ')));
    });

    test('never leaves a raw space in the built URL for any real lesson path', () {
      const paths = [
        'TechCenter/008 UI_UX_Design_Principles_Study_Guide.html',
        'AptitudeReasoning/Questions/001 Quant Aptitude Coach.html',
        '001 CEFR/003 CEFR Guide.html',
      ];
      for (final path in paths) {
        final url = buildSkillUpLessonUrl(path);
        expect(url, isNot(contains(' ')), reason: 'built URL for "$path" still has a raw space: $url');
        expect(Uri.tryParse(url), isNotNull, reason: 'built URL for "$path" is not a valid Uri: $url');
      }
    });

    test('the whole absolute static prefix is present', () {
      final url = buildSkillUpLessonUrl('TechCenter/000 claude-code-guide.html');
      expect(url, startsWith('${EnvironmentConfig.baseUrl}/static/001%20Career%20Buddy/'));
    });
  });
}
