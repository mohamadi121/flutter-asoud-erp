import 'package:asoud_erp/features/roles/presentation/roles_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'user_access_fakes.dart';

/// The editor already returns the real advanced catalog (see the fake); the
/// subclass additionally holds `submit` as an inherited advanced operation.
class _RichClient extends UserAccessClient {
  @override
  Future<Map<String, dynamic>> callMethod(String method,
      {Map<String, dynamic>? data}) async {
    final base = await super.callMethod(method, data: data);
    if (method != 'asoud_erp.api.v1.user_access.editor') return base;
    final payload = base['message']['data'] as Map;
    (payload['inherited_advanced'] as Map)['Journal Entry'] = ['print'];
    return base;
  }
}

Future<void> _openEditor(WidgetTester tester, UserAccessClient client) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(userAccessApp(UserAccessPage(
      role: userAccessRole, repository: UserAccessRepository(client))));
  await tester.pumpAndSettle();
  await tester.tap(find.text('کاربر نمونه'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('advanced mode lists every operation, medium only the four',
      (tester) async {
    await _openEditor(tester, _RichClient());
    // medium
    await tester.tap(find.text('متوسط'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حسابداری'));
    await tester.pumpAndSettle();
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('ثبت قطعی'), findsNothing);
    expect(find.text('لغو سند'), findsNothing);
    expect(find.byKey(const Key('advanced-Journal Entry')), findsNothing);

    // advanced: a different view with the complete operation list
    await tester.tap(find.text('پیشرفته'));
    await tester.pumpAndSettle();
    expect(find.byType(DataTable), findsNothing);
    expect(find.byKey(const Key('advanced-Journal Entry')), findsOneWidget);
    for (final label in [
      'مشاهده', 'ایجاد', 'ویرایش', 'حذف', 'ثبت قطعی', 'لغو سند', 'چاپ',
      'برون‌بری', 'اشتراک‌گذاری',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
  });

  testWidgets('an advanced-only operation can be added and removed',
      (tester) async {
    await _openEditor(tester, _RichClient());
    await tester.tap(find.text('پیشرفته'));
    await tester.pumpAndSettle();
    final submit = find.byKey(const Key('op-Journal Entry-submit'));
    expect(tester.widget<CheckboxListTile>(submit).value, isFalse);
    await tester.tap(submit);
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(submit).value, isTrue);
    // adding an operation also grants viewing, as the server requires
    expect(
        tester
            .widget<CheckboxListTile>(
                find.byKey(const Key('op-Journal Entry-read')))
            .value,
        isTrue);
    await tester.tap(submit);
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(submit).value, isFalse);
  });

  testWidgets('locked inherited operations are shown but not editable',
      (tester) async {
    await _openEditor(tester, UserAccessClient());
    await tester.tap(find.text('پیشرفته'));
    await tester.pumpAndSettle();
    final read = tester
        .widget<CheckboxListTile>(find.byKey(const Key('op-User-read')));
    expect(read.value, isTrue);
    expect(read.onChanged, isNull);
  });

  testWidgets('apply sends the medium and the advanced operations separately',
      (tester) async {
    final client = UserAccessClient();
    await _openEditor(tester, client);
    await tester.tap(find.text('پیشرفته'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('op-Journal Entry-submit')));
    await tester.tap(find.byKey(const Key('op-Journal Entry-print')));
    await tester.pump();
    await tester.tap(find.text('مرحله بعد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ارسال دسترسی‌ها'));
    await tester.pumpAndSettle();
    final payload = client.lastApply!;
    expect(payload['token'], 'token-1');
    final grants = payload['grants'] as Map;
    final advanced = payload['advanced_grants'] as Map;
    expect(grants['Journal Entry'], ['read']);
    expect((advanced['Journal Entry'] as List).toSet(), {'submit', 'print'});
    // every catalog row is present in both maps (the server requires it)
    expect(grants.keys.toSet(), {'Journal Entry', 'User'});
    expect(advanced.keys.toSet(), {'Journal Entry', 'User'});
    expect(advanced['User'], isEmpty);
  });

  testWidgets('a read-only resource offers only viewing in every mode',
      (tester) async {
    await _openEditor(tester, UserAccessClient());
    await tester.tap(find.text('پیشرفته'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('op-User-read')), findsOneWidget);
    expect(find.byKey(const Key('op-User-create')), findsNothing);
    expect(find.byKey(const Key('op-User-submit')), findsNothing);
  });

  test('inherited advanced operations are merged and locked', () {
    final merged = mergeAccessMaps({
      'Journal Entry': ['read']
    }, {
      'Journal Entry': ['print']
    });
    expect(merged['Journal Entry'], {'read', 'print'});
  });
}
