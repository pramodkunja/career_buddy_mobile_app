import 'package:career_buddy_lms/features/ai_writing/domain/services/writing_text_formatting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatImprovedPassage', () {
    test('collapses internal whitespace runs to a single space and trims', () {
      expect(formatImprovedPassage('hello   \n\t world.'), 'Hello world.');
    });

    test('adds a trailing period when the text has no terminal punctuation', () {
      expect(formatImprovedPassage('this has no ending'), 'This has no ending.');
    });

    test('keeps existing terminal punctuation (!/?/.) as-is', () {
      expect(formatImprovedPassage('is this fine?'), 'Is this fine?');
      expect(formatImprovedPassage('wow!'), 'Wow!');
    });

    test('capitalizes only the first letter, not the rest', () {
      expect(formatImprovedPassage('hello World.'), 'Hello World.');
    });

    test('falls back to fallbackText when text is null/empty', () {
      expect(formatImprovedPassage(null, fallbackText: 'backup text'), 'Backup text.');
      expect(formatImprovedPassage('', fallbackText: 'backup text'), 'Backup text.');
    });

    test('returns emptyText when both text and fallbackText are empty', () {
      expect(formatImprovedPassage(null, emptyText: 'Nothing yet.'), 'Nothing yet.');
    });
  });
}
