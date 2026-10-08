import 'package:career_buddy_lms/core/media/media_url_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveMediaUrl', () {
    test('preserves an already-absolute http URL unchanged', () {
      expect(resolveMediaUrl('http://example.test/media/resumes/x.pdf'), 'http://example.test/media/resumes/x.pdf');
    });

    test('preserves an already-absolute https URL unchanged', () {
      expect(resolveMediaUrl('https://careerbuddy4u.com/media/resumes/x.pdf'), 'https://careerbuddy4u.com/media/resumes/x.pdf');
    });

    test('prefixes a root-relative URL with the configured base URL exactly once', () {
      final resolved = resolveMediaUrl('/media/resumes/x.pdf')!;
      expect(resolved, endsWith('/media/resumes/x.pdf'));
      expect(resolved.startsWith('http'), isTrue);
      // No duplicated base URL — the scheme/host appears exactly once.
      expect('https://'.allMatches(resolved).length + 'http://'.allMatches(resolved).length, 1);
    });

    test('resolves a bare relative URL (no leading slash) the same way, inserting exactly one separating slash', () {
      final resolved = resolveMediaUrl('media/resumes/x.pdf')!;
      expect(resolved, endsWith('/media/resumes/x.pdf'));
      expect(resolved.contains('//media'), isFalse);
    });

    test('returns null for a null URL', () {
      expect(resolveMediaUrl(null), isNull);
    });

    test('returns null for an empty or whitespace-only URL, rather than inventing a base-only URL', () {
      expect(resolveMediaUrl(''), isNull);
      expect(resolveMediaUrl('   '), isNull);
    });

    test('never duplicates the base URL when given a URL that already looks resolved', () {
      final once = resolveMediaUrl('/media/resumes/x.pdf')!;
      final twice = resolveMediaUrl(once);
      // Re-resolving an already-absolute URL must be a no-op.
      expect(twice, once);
    });
  });

  group('protectedMediaFilename', () {
    test('extracts the last path segment as the filename', () {
      expect(protectedMediaFilename('/media/resumes/xyz_123.pdf', 'fallback.pdf'), 'xyz_123.pdf');
    });

    test('extracts the last segment from an absolute URL too', () {
      expect(protectedMediaFilename('https://careerbuddy4u.com/media/interview_videos/abc.mp4', 'fallback.mp4'), 'abc.mp4');
    });

    test('falls back for an unparsable/empty URL', () {
      expect(protectedMediaFilename('', 'fallback.pdf'), 'fallback.pdf');
    });
  });
}
