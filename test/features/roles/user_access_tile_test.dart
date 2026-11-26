import 'package:asoud_erp/features/roles/presentation/office_users_page.dart';
import 'package:flutter_test/flutter_test.dart';

import 'user_access_fakes.dart';

void main() {
  testWidgets('Administrator sees the مدیریت کاربران tile and opens it',
      (tester) async {
    final client = UserAccessClient(roles: const ['Administrator']);
    await tester.pumpWidget(userAccessSettings(client));
    await tester.pumpAndSettle();

    expect(find.text('مدیریت کاربران'), findsOneWidget);

    await tester.ensureVisible(find.text('مدیریت کاربران'));
    await tester.tap(find.text('مدیریت کاربران'));
    await tester.pumpAndSettle();

    expect(find.text('مدیریت حساب'), findsOneWidget);
    expect(
        client.calls, contains('asoud_erp.api.v1.access_profiles.list_accounts'));
    expect(find.text('کاربر نمونه'), findsOneWidget);
  });

  testWidgets('hr-manager does not see the مدیریت کاربران tile', (tester) async {
    final client = UserAccessClient(roles: const ['HR Manager', 'Employee']);
    await tester.pumpWidget(userAccessSettings(client));
    await tester.pumpAndSettle();

    expect(find.text('مدیریت کاربران'), findsNothing);
  });

  testWidgets('office user page lists real personnel without accounts',
      (tester) async {
    final client = UserAccessClient(
      roles: const ['Administrator'],
      officePeople: [
        {
          'name': 'EMP-NEW',
          'employee_name': 'پرسنل بدون حساب',
          'designation': 'کارشناس',
          'department': 'مالی',
          'user_id': '',
          'account_status': 'no_account',
        },
      ],
    );
    await tester.pumpWidget(userAccessSettings(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مدیریت کاربران'));
    await tester.pumpAndSettle();

    expect(find.text('پرسنل بدون حساب'), findsOneWidget);
    expect(find.text('بدون حساب'), findsOneWidget);
    expect(find.text('هنوز حسابی به پرسنل این دفتر متصل نشده است.'),
        findsNothing);
    await tester.tap(find.text('ایجاد حساب').first);
    await tester.pumpAndSettle();
    expect(find.byType(OfficeAccountCreate), findsOneWidget);
    expect(find.text('پرسنل بدون حساب'), findsOneWidget);
  });
}
