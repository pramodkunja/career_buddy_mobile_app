enum SubActivityStatus {
  notStarted,
  inProgress,
  completed;

  static SubActivityStatus fromWire(String value) => switch (value) {
    'completed' => SubActivityStatus.completed,
    'in_progress' => SubActivityStatus.inProgress,
    _ => SubActivityStatus.notStarted,
  };
}
