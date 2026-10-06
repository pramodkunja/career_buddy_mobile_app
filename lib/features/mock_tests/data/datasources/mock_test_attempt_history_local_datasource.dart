import 'dart:convert';

import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/entities/mock_test_attempt_record.dart';

/// Device-local attempt log, mirroring the web's own `localStorage`
/// scoreboard exactly (`005 oop-mastery.html:2505-2536`, `LS_KEY='oopScores'`,
/// newest-first, capped at 50 entries via `.slice(0,50)`) — this app has no
/// equivalent of the browser's `localStorage`, so [SecureStorageService] (the
/// existing wrapper already used for session data) stands in for it. This is
/// substituting Flutter's own local-storage primitive for the web's, not
/// adding a new feature — and like the web page, it is never read from or
/// reconciled with the real server-side `skillup_assessment.QuizAttempt` row
/// that `oop_quiz_submit` also writes on every authenticated submission.
class MockTestAttemptHistoryLocalDataSource {
  MockTestAttemptHistoryLocalDataSource(this._storage, {required this.storageKey});

  final SecureStorageService _storage;
  final String storageKey;

  static const int _maxEntries = 50;

  Future<List<MockTestAttemptRecord>> getAttempts() async {
    final raw = await _storage.read(storageKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_recordFromJson)
          .whereType<MockTestAttemptRecord>()
          .toList();
    } on FormatException {
      // Corrupt/unreadable local data must never crash the result screen —
      // this log is a convenience readout, not a source of truth.
      return const [];
    }
  }

  MockTestAttemptRecord? _recordFromJson(Map<String, dynamic> json) {
    final score = json['score'];
    final total = json['total'];
    final completedAt = json['completedAt'];
    if (score is! int || total is! int || completedAt is! String) return null;
    final parsed = DateTime.tryParse(completedAt);
    if (parsed == null) return null;
    return MockTestAttemptRecord(score: score, total: total, completedAt: parsed);
  }

  Future<void> recordAttempt(MockTestAttemptRecord attempt) async {
    final existing = await getAttempts();
    final updated = [attempt, ...existing].take(_maxEntries).toList();
    final encoded = jsonEncode(
      updated
          .map((a) => {'score': a.score, 'total': a.total, 'completedAt': a.completedAt.toIso8601String()})
          .toList(),
    );
    await _storage.write(storageKey, encoded);
  }
}
