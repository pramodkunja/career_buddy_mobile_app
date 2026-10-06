class RecommendedJob {
  const RecommendedJob({
    required this.title,
    required this.companyName,
    required this.skills,
    required this.location,
    required this.jobType,
    required this.experienceLevel,
    required this.salaryDisplay,
  });

  final String title;
  final String companyName;
  final List<String> skills;
  final String location;
  final String jobType;
  final String experienceLevel;
  final String salaryDisplay;
}
