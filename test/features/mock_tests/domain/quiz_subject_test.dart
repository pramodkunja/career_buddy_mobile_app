import 'package:career_buddy_lms/features/mock_tests/domain/entities/quiz_subject.dart';
import 'package:flutter_test/flutter_test.dart';

/// `_QUIZ_SUBJECTS` (`activities/views.py:2201-2206`), minus `'oop'` (W020
/// already covers it via its own dedicated endpoint).
const _expectedSlugs = {
  'python', 'dsa', 'devops', 'claude', 'uiux', 'design', 'vector', 'nltk',
  'dbms', 'prompt', 'genai', 'crewai', 'english', 'aptitude', 'quantum',
  'vr', 'robotics', 'nodejs', 'mlops', 'ethical', 'tensorflow', 'cyber',
  'blockchain', 'crypto',
};

void main() {
  test('kQuizSubjects has exactly one entry per backend subject, oop excluded', () {
    final slugs = kQuizSubjects.map((s) => s.slug).toSet();
    expect(slugs, _expectedSlugs);
    expect(kQuizSubjects, hasLength(_expectedSlugs.length));
    expect(slugs.contains('oop'), isFalse);
  });

  test('every slug is unique (no accidental duplicate entries)', () {
    final slugs = kQuizSubjects.map((s) => s.slug).toList();
    expect(slugs.toSet().length, slugs.length);
  });

  test('every title is non-empty', () {
    for (final subject in kQuizSubjects) {
      expect(subject.title, isNotEmpty, reason: 'subject "${subject.slug}" has an empty title');
    }
  });
}
