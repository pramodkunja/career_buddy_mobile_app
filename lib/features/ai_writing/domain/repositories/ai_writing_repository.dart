import '../../../../core/utils/result.dart';
import '../entities/writing_analysis_result.dart';

abstract class AiWritingRepository {
  /// Mirrors `analyzeWriting()`'s exact request fields
  /// (`static/activities/js/writing.js:369-376`): `text`, `language`,
  /// `reference_text` (the topic prompt), and `previousImprovedPassage`
  /// (sent as `previous_improved_passage` only when non-null/non-empty —
  /// mirrors `window.lastImprovedPassage`, only ever set after a prior
  /// successful analysis in the same session).
  Future<Result<WritingAnalysisResult>> analyze({
    required int exerciseId,
    required String text,
    required String language,
    required String referenceText,
    String? previousImprovedPassage,
  });
}
