import 'package:career_buddy_lms/core/demo/demo_ai_listening_repository.dart';
import 'package:career_buddy_lms/core/demo/demo_ai_reading_repository.dart';
import 'package:career_buddy_lms/core/demo/demo_ai_speaking_repository.dart';
import 'package:career_buddy_lms/core/demo/demo_ai_writing_repository.dart';
import 'package:career_buddy_lms/core/demo/demo_progress_store.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/ai_listening/domain/entities/listening_analysis_result.dart';
import 'package:career_buddy_lms/features/ai_reading/domain/entities/reading_analysis_result.dart';
import 'package:career_buddy_lms/features/ai_speaking/domain/entities/speaking_analysis_result.dart';
import 'package:career_buddy_lms/features/ai_writing/domain/entities/writing_analysis_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(DemoProgressStore.instance.reset);

  group('DemoAiSpeakingRepository', () {
    test('analyze returns a realistic Success result and echoes the caller\'s duration/pause values', () async {
      final result = await DemoAiSpeakingRepository().analyze(
        exerciseId: 9201,
        audioFilePath: '/tmp/rec.m4a',
        durationSeconds: 27,
        pauseCount: 1,
        language: 'english',
        referenceText: 'Some topic',
      );

      final analysis = (result as Success<SpeakingAnalysisResult>).value;
      expect(analysis.score25, inInclusiveRange(0, 25));
      expect(analysis.issues, isNotEmpty);
      expect(analysis.durationSeconds, 27);
      expect(analysis.pauseCount, 1);
    });

    test('records the score25 as a demo attempt for the given exercise id', () async {
      await DemoAiSpeakingRepository().analyze(
        exerciseId: 9201,
        audioFilePath: '/tmp/rec.m4a',
        durationSeconds: 10,
        pauseCount: 0,
        language: 'english',
        referenceText: 'x',
      );

      final attempt = DemoProgressStore.instance.lastAttemptFor(9201);
      expect(attempt, isNotNull);
      expect(attempt!.maxScore, 25);
    });
  });

  group('DemoAiWritingRepository', () {
    test('analyze returns a realistic Success result with non-empty feedback/quickTip', () async {
      final result = await DemoAiWritingRepository().analyze(
        exerciseId: 9202,
        text: 'A demo written response.',
        language: 'english',
        referenceText: 'Some topic',
      );

      final analysis = (result as Success<WritingAnalysisResult>).value;
      expect(analysis.score25, inInclusiveRange(0, 25));
      expect(analysis.feedback, isNotEmpty);
      expect(analysis.quickTip, isNotEmpty);
    });

    test('records a demo attempt for the given exercise id', () async {
      await DemoAiWritingRepository().analyze(exerciseId: 9202, text: 'x', language: 'english', referenceText: 'y');
      expect(DemoProgressStore.instance.lastAttemptFor(9202), isNotNull);
    });
  });

  group('DemoAiListeningRepository', () {
    test('fetchAttemptToken returns a non-empty Success token', () async {
      final result = await DemoAiListeningRepository().fetchAttemptToken(9203);
      final token = (result as Success<String>).value;
      expect(token, isNotEmpty);
    });

    test('analyze returns a realistic Success result including contentMatchPercent', () async {
      final result = await DemoAiListeningRepository().analyze(
        exerciseId: 9203,
        text: 'A demo summary.',
        referenceText: 'The story',
        durationSeconds: 12,
        pauseCount: 0,
        attemptToken: 'demo-token',
        language: 'english',
      );

      final analysis = (result as Success<ListeningAnalysisResult>).value;
      expect(analysis.score25, inInclusiveRange(0, 25));
      expect(analysis.contentMatchPercent, inInclusiveRange(0, 100));
    });

    test('records a demo attempt for the given exercise id', () async {
      await DemoAiListeningRepository().analyze(
        exerciseId: 9203,
        text: 'x',
        referenceText: 'y',
        durationSeconds: 1,
        pauseCount: 0,
        attemptToken: 't',
        language: 'english',
      );
      expect(DemoProgressStore.instance.lastAttemptFor(9203), isNotNull);
    });
  });

  group('DemoAiReadingRepository', () {
    test('analyze echoes referenceText as text when non-empty', () async {
      final result = await DemoAiReadingRepository().analyze(
        exerciseId: 9204,
        audioFilePath: '/tmp/rec.m4a',
        durationSeconds: 15,
        pauseCount: 0,
        language: 'english',
        referenceText: 'The quick brown fox jumps over the lazy dog.',
      );

      final analysis = (result as Success<ReadingAnalysisResult>).value;
      expect(analysis.text, 'The quick brown fox jumps over the lazy dog.');
      expect(analysis.score25, inInclusiveRange(0, 25));
      expect(analysis.feedback, isNotEmpty);
      expect(analysis.quickTip, isNotEmpty);
    });

    test('records a demo attempt for the given exercise id', () async {
      await DemoAiReadingRepository().analyze(
        exerciseId: 9204,
        audioFilePath: '/tmp/rec.m4a',
        durationSeconds: 1,
        pauseCount: 0,
        language: 'english',
        referenceText: '',
      );
      expect(DemoProgressStore.instance.lastAttemptFor(9204), isNotNull);
    });
  });
}
