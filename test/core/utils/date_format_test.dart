import 'package:career_buddy_lms/core/utils/date_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats as "M d, Y", matching the web\'s |date:"M d, Y" filter', () {
    expect(formatMonthDayYear(DateTime(2026, 1, 15)), 'Jan 15, 2026');
    expect(formatMonthDayYear(DateTime(2026, 12, 1)), 'Dec 1, 2026');
  });
}
