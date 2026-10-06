import 'package:career_buddy_lms/features/bingo/data/models/bingo_exercise_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractEmbeddedJsonList', () {
    test('extracts and decodes a JSON array from the bingo-data script tag', () {
      const html = '''
<html><body>
<script type="application/json" id="bingo-data">[{"word": "ASAP", "definition": "As soon as possible"}]</script>
</body></html>
''';
      final result = extractEmbeddedJsonList(html, 'bingo-data');
      expect(result, isNotNull);
      expect(result, hasLength(1));
    });

    test('returns null when the tag is absent (e.g. a locked-activity redirect page)', () {
      final result = extractEmbeddedJsonList('<html><body>Activities</body></html>', 'bingo-data');
      expect(result, isNull);
    });

    test('returns null when the tag content is not valid JSON', () {
      const html = '<script type="application/json" id="bingo-data">not json</script>';
      expect(extractEmbeddedJsonList(html, 'bingo-data'), isNull);
    });
  });

  group('BingoExerciseParsing.fromBingoJson', () {
    test('parses word/definition pairs, in original order, unsliced', () {
      final exercise = BingoExerciseParsing.fromBingoJson(
        exerciseId: 7,
        title: 'Vocab Bingo',
        order: 1,
        bingoJson: [
          {'word': 'ASAP', 'definition': 'As soon as possible'},
          {'word': 'FYI', 'definition': 'For your information'},
        ],
      );

      expect(exercise.id, 7);
      expect(exercise.title, 'Vocab Bingo');
      expect(exercise.cards, hasLength(2));
      expect(exercise.cards[0].word, 'ASAP');
      expect(exercise.cards[0].definition, 'As soon as possible');
      expect(exercise.cards[1].word, 'FYI');
    });

    test('board is the first 25 cards when there are more than 25', () {
      final bingoJson = List.generate(30, (i) => {'word': 'W$i', 'definition': 'D$i'});
      final exercise = BingoExerciseParsing.fromBingoJson(exerciseId: 1, title: 'T', order: 1, bingoJson: bingoJson);

      expect(exercise.cards, hasLength(30));
      expect(exercise.board, hasLength(25));
      expect(exercise.board.first.word, 'W0');
      expect(exercise.board.last.word, 'W24');
    });

    test('board equals cards when there are 25 or fewer', () {
      final bingoJson = List.generate(10, (i) => {'word': 'W$i', 'definition': 'D$i'});
      final exercise = BingoExerciseParsing.fromBingoJson(exerciseId: 1, title: 'T', order: 1, bingoJson: bingoJson);

      expect(exercise.board, hasLength(10));
    });

    test('skips entries with a missing/blank word, and defaults a missing definition to empty', () {
      final exercise = BingoExerciseParsing.fromBingoJson(
        exerciseId: 1,
        title: 'T',
        order: 1,
        bingoJson: [
          {'word': '', 'definition': 'no word'},
          {'definition': 'no word key at all'},
          {'word': 'OK'},
        ],
      );

      expect(exercise.cards, hasLength(1));
      expect(exercise.cards.single.word, 'OK');
      expect(exercise.cards.single.definition, '');
    });
  });
}
