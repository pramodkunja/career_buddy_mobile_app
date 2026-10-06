const _monthAbbreviations = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _monthFullNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Matches the web app's `|date:"M d, Y"` filter (e.g. "Jan 15, 2026"),
/// used wherever the Dashboard shows a date. No `intl` dependency exists in
/// this project yet, so this stays a small local helper rather than adding
/// one for a single format.
String formatMonthDayYear(DateTime date) {
  return '${_monthAbbreviations[date.month - 1]} ${date.day}, ${date.year}';
}

/// The inverse of [formatMonthDayYear] — parses a Django `|date:"M d, Y"`
/// string (e.g. "Jan 5, 2026") back into a [DateTime], for screens that
/// scrape this exact format out of server-rendered HTML (the Dashboard has
/// no JSON sibling deployed in production, see `DashboardRemoteDataSource`'s
/// doc comment). Returns `null` for anything that doesn't match — callers
/// decide whether a missing date is fatal or just omitted.
DateTime? parseMonthDayYear(String text) {
  final match = RegExp(r'^([A-Za-z]{3})\s+(\d{1,2}),\s*(\d{4})$').firstMatch(text.trim());
  if (match == null) return null;
  final monthIndex = _monthAbbreviations.indexOf(match.group(1)!);
  if (monthIndex == -1) return null;
  final day = int.tryParse(match.group(2)!);
  final year = int.tryParse(match.group(3)!);
  if (day == null || year == null) return null;
  return DateTime(year, monthIndex + 1, day);
}

/// Matches the web sub-activity page's completed-banner `|date:"F d, Y"`
/// filter (e.g. "January 15, 2026") — full month name, unlike the other
/// date formats here.
String formatFullMonthDayYear(DateTime date) {
  return '${_monthFullNames[date.month - 1]} ${date.day}, ${date.year}';
}

/// Matches the web Activity/Sub-Activity Detail pages' `|date:"M d Y h:i A"`
/// filter (e.g. "Jan 15 2026 02:30 PM") — used for the "Started"/"Completed"
/// timestamps on a sub-activity, which (unlike the Dashboard's date-only
/// timestamps) include a 12-hour time.
String formatMonthDayYearTime(DateTime date) {
  final hour24 = date.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final period = hour24 < 12 ? 'AM' : 'PM';
  final minute = date.minute.toString().padLeft(2, '0');
  return '${_monthAbbreviations[date.month - 1]} ${date.day} ${date.year} '
      '${hour12.toString().padLeft(2, '0')}:$minute $period';
}
