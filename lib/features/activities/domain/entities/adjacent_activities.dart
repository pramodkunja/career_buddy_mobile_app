/// A lightweight pointer to a neighboring activity — just enough to render
/// a Previous/Next nav link (`templates/activities/detail.html:152-164`),
/// not a full [ActivityDetail].
class AdjacentActivityRef {
  const AdjacentActivityRef({required this.id, required this.title});

  final int id;
  final String title;
}

/// The activities immediately before/after the current one, in catalogue
/// order — derived client-side from the existing activity-list endpoint
/// (see `AdjacentActivitiesController`), since no API exposes this
/// directly. Either side is `null` at a boundary (first/last activity) or
/// when neither side is derivable at all.
class AdjacentActivities {
  const AdjacentActivities({this.previous, this.next});

  final AdjacentActivityRef? previous;
  final AdjacentActivityRef? next;
}
