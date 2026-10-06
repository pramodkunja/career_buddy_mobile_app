import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/mock_interview_remote_datasource.dart';
import '../../data/mock_interview_repository_impl.dart';
import '../../data/services/interview_camera_service_impl.dart';
import '../../domain/repositories/mock_interview_repository.dart';
import '../../domain/services/interview_camera_service.dart';
import '../controllers/mock_interview_controller.dart';

final mockInterviewRemoteDataSourceProvider = Provider<MockInterviewRemoteDataSource>((ref) {
  return MockInterviewRemoteDataSource(ref.watch(apiClientProvider));
});

final mockInterviewRepositoryProvider = Provider<MockInterviewRepository>((ref) {
  return MockInterviewRepositoryImpl(ref.watch(mockInterviewRemoteDataSourceProvider));
});

/// A *factory*, not a shared instance: `InterviewCameraService` holds a live
/// `CameraController` and must be created fresh (and disposed) per screen
/// visit, not shared/cached the way a stateless repository is. Overridden in
/// widget tests with a fake factory so no real camera hardware is touched.
final interviewCameraServiceFactoryProvider = Provider<InterviewCameraService Function()>((ref) {
  return InterviewCameraServiceImpl.new;
});

final mockInterviewControllerProvider = NotifierProvider<MockInterviewController, MockInterviewState>(
  MockInterviewController.new,
);
