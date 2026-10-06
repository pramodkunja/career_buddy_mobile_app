import 'package:career_buddy_lms/features/ai_listening/domain/entities/listening_issue.dart';
import 'package:career_buddy_lms/features/ai_listening/domain/services/listening_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildListeningFeedback', () {
    test('100% match: excellent listening', () {
      final result = buildListeningFeedback(matchPercent: 100, issues: const [], fallbackFeedback: '');
      expect(result, contains('Excellent listening'));
    });

    test('90-99% match: very strong listening, mentions issue count when present', () {
      final result = buildListeningFeedback(
        matchPercent: 92,
        issues: const [ListeningIssue(phrase: 'a', type: 'Grammar', message: 'm', suggestion: 's')],
        fallbackFeedback: '',
      );
      expect(result, contains('Very strong listening'));
      expect(result, contains('1 highlighted spot'));
    });

    test('80-89% match: good listening', () {
      final result = buildListeningFeedback(matchPercent: 85, issues: const [], fallbackFeedback: '');
      expect(result, contains('Good listening'));
    });

    test('60-79% match: decent listening', () {
      final result = buildListeningFeedback(matchPercent: 65, issues: const [], fallbackFeedback: '');
      expect(result, contains('Decent listening'));
    });

    test('50-59% match: partial understanding', () {
      final result = buildListeningFeedback(matchPercent: 55, issues: const [], fallbackFeedback: '');
      expect(result, contains('Partial understanding'));
    });

    test('20-49% match: limited match', () {
      final result = buildListeningFeedback(matchPercent: 30, issues: const [], fallbackFeedback: '');
      expect(result, contains('Limited match'));
    });

    test('below 20% match: falls back to the server\'s feedback string when provided', () {
      final result = buildListeningFeedback(matchPercent: 5, issues: const [], fallbackFeedback: 'Server-provided fallback.');
      expect(result, 'Server-provided fallback.');
    });

    test('below 20% match with no server fallback: uses the default message', () {
      final result = buildListeningFeedback(matchPercent: 5, issues: const [], fallbackFeedback: '');
      expect(result, contains('not closely related to the story'));
    });
  });

  group('buildListeningQuickTip', () {
    test('uses the top issue\'s suggestion when present', () {
      final result = buildListeningQuickTip(
        matchPercent: 50,
        issues: const [ListeningIssue(phrase: 'a', type: 'Grammar', message: 'm', suggestion: 'Fix your verb tense.')],
      );
      expect(result, 'Fix this first: Fix your verb tense.');
    });

    test('90%+ match with no issues: polish tip', () {
      final result = buildListeningQuickTip(matchPercent: 95, issues: const []);
      expect(result, contains('tighten grammar'));
    });

    test('60-89% match with no issues: story-order tip', () {
      final result = buildListeningQuickTip(matchPercent: 70, issues: const []);
      expect(result, contains('Keep the same story order'));
    });

    test('below 60% match with no issues: listen-again tip', () {
      final result = buildListeningQuickTip(matchPercent: 30, issues: const []);
      expect(result, contains('Listen for the main person'));
    });
  });
}
