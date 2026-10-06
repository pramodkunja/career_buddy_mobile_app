import '../../../../core/utils/result.dart';
import '../entities/resume_analysis.dart';
import '../entities/resume_history_item.dart';

abstract class ResumeRepository {
  Future<Result<ResumeAnalysisResult>> uploadAndAnalyze({
    required String filePath,
    required String fileName,
  });

  Future<Result<ResumeAnalysisResult>> reanalyze(int resumeId);

  Future<Result<List<ResumeHistoryItem>>> getHistory();
}
