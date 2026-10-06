import 'package:career_buddy_lms/app/theme/app_colors.dart';
import 'package:career_buddy_lms/features/dashboard/domain/entities/payment_record.dart';
import 'package:career_buddy_lms/features/dashboard/presentation/widgets/payment_history_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders nothing when there is no payment history', (tester) async {
    await tester.pumpWidget(wrap(const PaymentHistorySection(payments: [])));

    expect(find.text('Payment History'), findsNothing);
  });

  testWidgets('formats the amount to 2 decimal places, matching the web\'s |floatformat:2', (tester) async {
    await tester.pumpWidget(
      wrap(
        PaymentHistorySection(
          payments: [
            PaymentRecord(
              date: DateTime(2026, 1, 15),
              isPlanActive: true,
              amountRupees: 499,
              transactionId: 'pay_ABC123',
            ),
          ],
        ),
      ),
    );

    expect(find.text('₹499.00'), findsOneWidget);
    expect(find.text('Jan 15, 2026'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('shows "Non-Active" for a lapsed plan\'s payment', (tester) async {
    await tester.pumpWidget(
      wrap(
        PaymentHistorySection(
          payments: [
            PaymentRecord(
              date: DateTime(2025, 1, 15),
              isPlanActive: false,
              amountRupees: 499.5,
              transactionId: 'pay_OLD001',
            ),
          ],
        ),
      ),
    );

    expect(find.text('₹499.50'), findsOneWidget);
    expect(find.text('Non-Active'), findsOneWidget);
  });

  testWidgets('badges are solid-fill (Bootstrap .badge.bg-success/.bg-danger), not a tinted overlay', (tester) async {
    await tester.pumpWidget(
      wrap(
        PaymentHistorySection(
          payments: [
            PaymentRecord(date: DateTime(2026, 1, 15), isPlanActive: true, amountRupees: 1, transactionId: 'a'),
          ],
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.ancestor(of: find.text('Active'), matching: find.byType(Container)).first,
    );
    expect((container.decoration! as BoxDecoration).color, AppColors.success);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      wrap(
        PaymentHistorySection(
          payments: [
            PaymentRecord(date: DateTime(2026, 1, 15), isPlanActive: false, amountRupees: 1, transactionId: 'a'),
          ],
        ),
      ),
    );
    final nonActiveContainer = tester.widget<Container>(
      find.ancestor(of: find.text('Non-Active'), matching: find.byType(Container)).first,
    );
    // `.bg-danger` (`#ef4444`), not a muted gray — this badge is genuinely
    // red on the web, not touched by the site's gold/navy rebrand.
    expect((nonActiveContainer.decoration! as BoxDecoration).color, AppColors.danger);
  });
}
