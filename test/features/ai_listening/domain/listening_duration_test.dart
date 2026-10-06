import 'package:career_buddy_lms/features/ai_listening/domain/services/listening_duration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('estimateListeningDuration', () {
    test('never returns less than 8 seconds even for very short text', () {
      expect(estimateListeningDuration('one two', 1.0), 8);
    });

    test('scales down as speed increases', () {
      final text = List.generate(100, (_) => 'word').join(' ');
      final atNormalSpeed = estimateListeningDuration(text, 1.0);
      final atFastSpeed = estimateListeningDuration(text, 1.2);
      expect(atFastSpeed, lessThan(atNormalSpeed));
    });

    test('scales up as speed decreases', () {
      final text = List.generate(100, (_) => 'word').join(' ');
      final atNormalSpeed = estimateListeningDuration(text, 1.0);
      final atSlowSpeed = estimateListeningDuration(text, 0.8);
      expect(atSlowSpeed, greaterThan(atNormalSpeed));
    });

    test('matches the JS formula: words / max(1.8, 2.6*speed), rounded, floored at 8', () {
      final text = List.generate(52, (_) => 'word').join(' '); // 52 words
      // wordsPerSecond = max(1.8, 2.6*1.0) = 2.6; 52/2.6 = 20
      expect(estimateListeningDuration(text, 1.0), 20);
    });
  });
}
