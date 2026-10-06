import '../../../../core/utils/result.dart';
import '../entities/roleplay_analysis_result.dart';
import '../entities/roleplay_generated_content.dart';

abstract class RoleplayRepository {
  /// `POST /roleplay/practice/` (`roleplay_practice`).
  Future<Result<RoleplayGeneratedContent>> generatePractice({
    required String topicSlug,
    required String prompt,
    required String language,
  });

  /// `POST /roleplay/analyze/` (`analyze_roleplay`). [topicLabel] mirrors
  /// the web's own `topic` field for this specific call — see
  /// `RoleplayRemoteDataSource.analyze`'s doc comment for why it is *not*
  /// simply [topicSlug] again.
  Future<Result<RoleplayAnalysisResult>> analyze({
    required String topicLabel,
    required String audioFilePath,
    required double durationSeconds,
    required int pauseCount,
    required String language,
    required String referenceText,
  });
}
