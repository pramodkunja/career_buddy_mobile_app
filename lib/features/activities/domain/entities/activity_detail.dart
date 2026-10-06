import 'sub_activity_summary.dart';

class ActivityDetail {
  const ActivityDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.categoryDisplay,
    required this.level,
    required this.duration,
    required this.isWorkshop,
    required this.isModule,
    required this.completionRate,
    required this.subActivities,
  });

  final int id;
  final String title;
  final String description;
  final String category;
  final String categoryDisplay;
  final String level;
  final String duration;

  /// Workshop (GD/JAM/Roleplay) activities don't have an in-app
  /// exercise-taking flow — the web redirects them elsewhere; the mobile
  /// UI uses this flag to show that plainly instead of navigating to a
  /// screen that doesn't exist. AI-module activities (`isModule`) all now
  /// have real in-app screens as of W014/W015/W016/W017 (Speaking/
  /// Writing/Listening/Reading — `isSpeakingModuleActivity(title)` /
  /// `isWritingModuleActivity(title)` / `isListeningModuleActivity(title)` /
  /// `isReadingModuleActivity(title)`) — `ActivityDetailScreen`
  /// distinguishes these using `title`, not this flag alone.
  final bool isWorkshop;
  final bool isModule;

  /// Percentage, 0-100.
  final int completionRate;
  final List<SubActivitySummary> subActivities;
}
