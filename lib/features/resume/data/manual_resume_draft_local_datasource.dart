import 'dart:convert';

import '../../../core/storage/secure_storage_service.dart';
import '../domain/entities/manual_resume_draft.dart';

/// Persists the Manual Resume Builder's draft via [SecureStorageService] —
/// the same app-private, encrypted-at-rest mechanism already used for the
/// cached auth session (`AuthSessionKeys`) and the Mock Test attempt log
/// (`MockTestAttemptHistoryLocalDataSource`) — chosen specifically because
/// a draft contains real personal information (name, phone, email,
/// employment history), the exact kind of data this service already exists
/// to protect, rather than a new, unencrypted mechanism.
///
/// **Account isolation**: each account's draft lives under its own key,
/// `$_baseKey.<username>` — confirmed via the Django source
/// (`users/forms.py`, `users/views.py`) that `username` is the real,
/// DB-unique, effectively-immutable Django account identifier (never
/// reassigned anywhere in the backend, not exposed as an editable profile
/// field), not a freely-editable display name. This means isolation is
/// structural (two accounts simply never share a key) rather than relying
/// on any active "delete on logout" step — which matters because a
/// *temporary* session expiry must never be mistaken for "switch accounts
/// and wipe the old draft" (see the repository's own doc comment).
class ManualResumeDraftLocalDataSource {
  ManualResumeDraftLocalDataSource(this._storage);

  final SecureStorageService _storage;

  static const String _baseKey = 'manual_resume_draft.v$kManualResumeDraftSchemaVersion';

  String _keyFor(String username) => '$_baseKey.$username';

  /// `null` for "no saved draft" **and** for corrupt/unsupported data —
  /// both are safe-to-ignore cases from this layer's perspective (the
  /// repository is the one that distinguishes "no draft" from a genuine
  /// storage-read failure, by letting an actual exception propagate here
  /// instead of being swallowed).
  Future<ManualResumeDraft?> getDraft(String username) async {
    final raw = await _storage.read(_keyFor(username));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['schemaVersion'] != kManualResumeDraftSchemaVersion) {
        // An older/newer/missing version marker — never force-parse data
        // shaped for a different schema; treat exactly like "no draft".
        return null;
      }
      final body = decoded['draft'];
      if (body is! Map<String, dynamic>) return null;
      return ManualResumeDraft.fromJson(body);
    } on FormatException {
      return null;
    }
  }

  Future<void> saveDraft(String username, ManualResumeDraft draft) async {
    final encoded = jsonEncode({'schemaVersion': kManualResumeDraftSchemaVersion, 'draft': draft.toJson()});
    await _storage.write(_keyFor(username), encoded);
  }

  Future<void> clearDraft(String username) async {
    await _storage.delete(_keyFor(username));
  }
}
