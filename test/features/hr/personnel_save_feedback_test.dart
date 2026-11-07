import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/utils/failure_message.dart';
import 'package:asoud_erp/features/hr/data/personnel_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Same detail contract as personnel_shared_fields_test; offline/pending_sync
// are the local result flags set by PersonnelRepository for queued writes.
class _Repository extends Mock implements PersonnelRepository {
  Object? failure;
  int updates = 0;
  Map<String, dynamic>? submitted;
  @override
  bool get localDemo => false;
  @override
  Future<Map<String, dynamic>> profileOptions(String id) async => {};
  @override
  Future<Map<String, dynamic>> detail(String id) async => {
        'profile': {'id': id, 'display_name': 'علی رضایی'},
        'revision': 'profile-1',
        'can_edit': true,
        'records': [],
      };
  @override
  Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> values, String revision) async {
    updates++;
    submitted = values;
    if (failure != null) throw failure!;
    return {...await detail(id), 'offline': true};
  }
}

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _open(
    WidgetTester tester, _Repository repository, double width) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AsoudTheme.light,
    builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl, child: child!),
    home: PersonnelDetailPage(id: 'P-1', repository: repository),
  ));
  await tester.pumpAndSettle();
  await _tap(tester, 'اطلاعات فردی');
  await _tap(tester, 'ویرایش اطلاعات');
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('profile offline update waits for notice then closes at $width',
        (tester) async {
      final repository = _Repository();
      await _open(tester, repository, width);
      await tester.tap(find.text('ذخیره'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(repository.updates, 1);
      expect(find.text('ذخیره روی گوشی انجام شد و هنوز به سرور ارسال نشده است'),
          findsOneWidget);
      expect(find.text('ویرایش اطلاعات فردی'), findsOneWidget);
      await _tap(tester, 'باشه');
      expect(find.text('ویرایش اطلاعات فردی'), findsNothing);
      expect(tester.takeException(), isNull);
    });
    for (final kind in [ApiFailureKind.forbidden, ApiFailureKind.validation]) {
      testWidgets('profile $kind preserves form at $width', (tester) async {
        final failure = ApiException(
            kind: kind,
            statusCode: kind == ApiFailureKind.forbidden ? 403 : 417,
            message: 'اطلاعات واردشده معتبر نیست.');
        final repository = _Repository()..failure = failure;
        await _open(tester, repository, width);
        await _tap(tester, 'اطلاعات اصلی');
        await tester.enterText(
            find.widgetWithText(TextFormField, 'نام و نام خانوادگی'), 'علی جدید');
        await _tap(tester, 'ذخیره');
        expect(repository.updates, 1);
        expect(repository.submitted!['display_name'], 'علی جدید');
        expect(find.text('ویرایش اطلاعات فردی'), findsOneWidget);
        expect(find.widgetWithText(TextFormField, 'علی جدید'), findsOneWidget);
        expect(find.text(failureMessage(failure)), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
