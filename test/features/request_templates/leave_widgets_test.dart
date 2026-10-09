import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/request_templates/presentation/widgets/leave_widgets.dart';
import 'package:asoud_erp/features/workflows/data/offline_preview_data.dart';
import 'package:asoud_erp/features/workflows/domain/entities/request_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
    theme: AsoudTheme.light,
    home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            body: Padding(padding: const EdgeInsets.all(16), child: child))));

final _balance = LeaveBalance.fromMap(offlineLeaveBalance());

void main() {
  testWidgets('balance panel shows annual, sick and other in days',
      (tester) async {
    await tester.pumpWidget(_wrap(LeaveBalancePanel(balance: _balance)));
    expect(find.text('اطلاعات باقی‌مانده مرخصی'), findsOneWidget);
    expect(find.text('ماندهٔ سالانه'), findsOneWidget);
    expect(find.text('استعلاجی'), findsOneWidget);
    expect(find.text('سایر'), findsOneWidget);
    expect(find.text('۱۲٫۵ روز'), findsOneWidget);
    expect(find.text('۸ روز'), findsOneWidget);
    expect(find.text('۲ روز'), findsOneWidget);
    expect(find.byKey(const ValueKey('leave-balance-after')), findsNothing);
  });

  testWidgets('balance panel shows the remaining days after the request',
      (tester) async {
    await tester.pumpWidget(_wrap(LeaveBalancePanel(
        balance: _balance, highlightCategory: 'annual', remainingAfter: 9.5)));
    expect(find.text('پس از این درخواست: ۹٫۵ روز'), findsOneWidget);
    // Only the highlighted tile carries it.
    expect(find.byKey(const ValueKey('leave-balance-after')), findsOneWidget);
  });

  testWidgets('balance panel states', (tester) async {
    await tester.pumpWidget(_wrap(const LeaveBalancePanel(balance: null)));
    expect(find.text('مانده مرخصی در دسترس نیست.'), findsOneWidget);
    await tester.pumpWidget(
        _wrap(const LeaveBalancePanel(balance: null, loading: true)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('duration badge shows days, hours and fractions', (tester) async {
    await tester.pumpWidget(_wrap(LeaveDurationBadge(
        duration: LeaveDuration.fromMap(
            {'unit': 'day', 'days': 3.0, 'hours': null}))));
    expect(find.text('۳ روز'), findsOneWidget);
    await tester.pumpWidget(_wrap(LeaveDurationBadge(
        duration: LeaveDuration.fromMap(
            {'unit': 'hour', 'days': null, 'hours': 4.0}))));
    expect(find.text('۴ ساعت'), findsOneWidget);
    await tester.pumpWidget(_wrap(LeaveDurationBadge(
        duration: LeaveDuration.fromMap(
            {'unit': 'hour', 'days': null, 'hours': 1.5}))));
    expect(find.text('۱٫۵ ساعت'), findsOneWidget);
    await tester.pumpWidget(_wrap(const LeaveDurationBadge(duration: null)));
    expect(find.text('—'), findsOneWidget);
  });
}
