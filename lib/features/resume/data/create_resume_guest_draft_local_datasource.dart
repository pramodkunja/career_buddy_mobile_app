import 'dart:convert';

import '../../../core/storage/secure_storage_service.dart';
import '../domain/entities/create_resume_state.dart';

const int kCreateResumeGuestDraftSchemaVersion = 1;

/// Phase 42. Local-only persistence for a Create Resume draft started
/// before signing in — mirrors the real web's own guest-save branch exactly
/// (`static/js/create_resume.js:656-660`, confirmed directly): when the
/// page's own `AUTH` flag is false, "Save" never reaches the server at
/// all, it writes to `localStorage` on that device only. There is no
/// per-account key the way [ManualResumeDraftLocalDataSource] has one per
/// username — a guest has no account yet, so there is only ever one such
/// draft per device, matching the web's own single `'...guest'`
/// `localStorage` key (neither platform has a concept of multiple
/// simultaneous guest identities on one device).
///
/// Deliberately separate from `CreateResumeRemoteDataSource`/
/// `CreateResumeRepository`: that repository's own doc comment states
/// "there is no local-only persistence" for the real, server-backed Create
/// Resume contract, and a guest draft must never be confused with, or
/// silently promoted into, a real saved server draft.
class CreateResumeGuestDraftLocalDataSource {
  CreateResumeGuestDraftLocalDataSource(this._storage);

  final SecureStorageService _storage;

  static const String _key =
      'create_resume_guest_draft.v$kCreateResumeGuestDraftSchemaVersion';

  /// `null` for "no saved draft" **and** for corrupt/unsupported data, same
  /// posture as [ManualResumeDraftLocalDataSource.getDraft] — both are
  /// safe-to-ignore cases from this layer's perspective; a genuine storage
  /// exception is left to propagate so the repository can tell the two
  /// apart. The returned state's `draftId` is always `null` — a locally
  /// saved guest draft was never assigned a server id.
  Future<CreateResumeFormState?> getDraft() async {
    final raw = await _storage.read(_key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['schemaVersion'] != kCreateResumeGuestDraftSchemaVersion) {
        // An older/newer/missing version marker — never force-parse data
        // shaped for a different schema; treat exactly like "no draft".
        return null;
      }
      final body = decoded['draft'];
      if (body is! Map<String, dynamic>) return null;
      return CreateResumeFormState.fromDraftData(body);
    } on FormatException {
      return null;
    }
  }

  /// Overwrites whatever guest draft this device already had, if any — one
  /// in-progress guest draft at a time, matching the web's own single
  /// `localStorage` key (there is nothing like "My Resumes" for a guest to
  /// choose among several).
  Future<void> saveDraft(CreateResumeFormState form) async {
    final encoded = jsonEncode({
      'schemaVersion': kCreateResumeGuestDraftSchemaVersion,
      'draft': form.toRequestJson(),
    });
    await _storage.write(_key, encoded);
  }

  Future<void> clearDraft() async {
    await _storage.delete(_key);
  }
}
