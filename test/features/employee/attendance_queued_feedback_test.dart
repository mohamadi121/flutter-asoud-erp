import 'package:asoud_erp/features/employee/data/self_service_repository.dart';
import 'package:asoud_erp/features/employee/presentation/pages/my_attendance_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements SelfServiceRepository {}

void main() {
  late _Repository repository;

  setUp(() {
    repository = _Repository();
    when(() => repository.attendance(any(), any())).thenAnswer((_) async => []);
    when(() => repository.checkins()).thenAnswer((_) async => []);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyAttendancePage(
          repository: repository,
          today: DateTime(2026, 9, 25, 8),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('queued check-in shows the queued message and a pending entry',
      (tester) async {
    when(() => repository.checkin('IN'))
        .thenAnswer((_) async => CheckinResult.queued);
    await pump(tester);

    await tester.tap(find.text('ثبت ورود'));
    await tester.pumpAndSettle();

    expect(find.text('ذخیره شد؛ پس از اتصال ارسال می‌شود'), findsOneWidget);
    expect(find.text('ثبت شد'), findsNothing);
    // The pending entry is visible in today's list.
    expect(find.text('در انتظار ارسال'), findsOneWidget);
  });

  testWidgets('accepted check-in still says ثبت شد', (tester) async {
    when(() => repository.checkin('IN'))
        .thenAnswer((_) async => CheckinResult.accepted);
    await pump(tester);

    await tester.tap(find.text('ثبت ورود'));
    await tester.pumpAndSettle();

    expect(find.text('ورود ثبت شد.'), findsOneWidget);
    expect(find.text('ذخیره شد؛ پس از اتصال ارسال می‌شود'), findsNothing);
    expect(find.text('در انتظار ارسال'), findsNothing);
  });
}
