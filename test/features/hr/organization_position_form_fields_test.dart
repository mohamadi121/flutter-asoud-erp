import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/widgets/app_fields.dart';
import 'package:asoud_erp/features/hr/data/organization_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/organization_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

/// Administrator client with the real backend envelope shapes; the write goes
/// through [callAsoudMethod], exactly as [OrganizationRepository.save] calls it.
class _OrgClient extends Fake implements FrappeApiClient {
  _OrgClient({List<Map<String, dynamic>> units = const [], this.positions}) : units = List.of(units);
  final List<Map<String, dynamic>> units;
  final List<Map<String, dynamic>>? positions;
  bool failUnits = false;
  bool rejectSave = false;
  bool rejectReset = false;
  bool manage = true;
  bool deleteBlocked = false;
  int deleteCalls = 0;
  List<Map<String, dynamic>> employeeRows = [];
  int resetCalls = 0;
  Map<String, dynamic>? lastUnitPayload;
  final writes = <String>[];
  Map<String, dynamic>? lastSavePayload;

  @override
  bool get isAuthenticated => true;

  @override
  Stream<bool> get authenticationChanges => const Stream.empty();

  @override
  Future<FrappeUserContext> getCurrentUser() async => FrappeUserContext(
        userId: 'Administrator',
        fullName: 'Administrator',
        roles: manage ? const ['Administrator'] : const ['HR User'],
      );

  Map<String, dynamic> _envelope(Map<String, dynamic> data) => {
        'message': {
          'ok': true,
          'meta': {'api_version': 'v1'},
          'data': data,
        },
      };

  @override
  Future<Map<String, dynamic>> callMethod(String method,
      {Map<String, dynamic>? data}) async {
    if (method == 'asoud_erp.api.v1.organization.reset_chart') {
      resetCalls++;
      if (rejectReset) throw const ApiException(kind: ApiFailureKind.network, message: 'offline');
      lastSavePayload = {'rows': <dynamic>[], 'revision': data!['revision']};
      return _envelope({'rows': <dynamic>[], 'revision': (data['revision'] as int) + 1, 'reset': true});
    }
    if (method == 'asoud_erp.api.v1.organization.get_chart') {
      return _envelope({
        'rows': lastSavePayload?['rows'] ?? positions ?? [
          {
            'code': 'CEO',
            'title': 'مدیرعامل',
            'parent': '',
            'department': 'مدیریت',
            'employee': 'EMP-001',
          }
        ],
        'revision': lastSavePayload == null ? 1 : (lastSavePayload!['revision'] as int) + 1,
        'warnings': <dynamic>[],
      });
    }
    if (method == 'asoud_erp.api.v1.organization.list_employees') {
      return _envelope({'employees': employeeRows});
    }
    if (method == 'asoud_erp.api.v1.organization.list_units') {
      if (failUnits) {
        throw const ApiException(
            kind: ApiFailureKind.network, message: 'offline');
      }
      return _envelope({'units': units, 'can_manage': manage});
    }
    if (method == 'asoud_erp.api.v1.organization.save_unit') {
      lastUnitPayload = Map<String, dynamic>.from(data!['payload'] as Map);
      final id = lastUnitPayload!['name'] ?? 'NEW-UNIT';
      final previous = units.where((u) => u['name'] == id).firstOrNull;
      units.removeWhere((u) => u['name'] == id);
      units.add({'name': id, 'department_name': lastUnitPayload!['title'],
        'parent_department': lastUnitPayload!['parent'], 'is_group': 1,
        'disabled': 0, 'description': lastUnitPayload!['description'] ?? previous?['description'] ?? '', 'modified': '2026-10-25 10:00:00'});
      return _envelope({'name': id, 'modified': '2026-10-25 10:00:00'});
    }
    if (method == 'asoud_erp.api.v1.organization.preview_delete_unit') {
      return _envelope({'can_delete': !deleteBlocked,
        'blockers': deleteBlocked ? ['این واحد دارای زیرواحد است؛ حذف مجاز نیست.'] : <String>[],
        'modified': data!['modified']});
    }
    if (method == 'asoud_erp.api.v1.organization.delete_unit') {
      deleteCalls++;
      units.removeWhere((u) => u['name'] == data!['name']);
      return _envelope({'deleted': data!['name']});
    }
    if (method == 'asoud_erp.api.v1.organization.employee_photo') return _envelope({'content': null});
    throw StateError('Unexpected organization read: $method');
  }

  @override
  Future<dynamic> callAsoudMethod(String method,
      {Map<String, dynamic>? data}) async {
    if (method == 'asoud_erp.api.v1.organization.save_chart') {
      if (rejectSave) throw const ApiException(kind: ApiFailureKind.validation, message: 'ذخیره توسط سرور رد شد.');
      writes.add(method);
      final payload = Map<String, dynamic>.from(data!['payload'] as Map);
      lastSavePayload = payload;
      return {
        'rows': payload['rows'],
        'revision': (payload['revision'] as int) + 1,
        'warnings': <dynamic>[],
      };
    }
    throw StateError('Unexpected organization write: $method');
  }
}

Future<void> _openCreateForm(WidgetTester tester, _OrgClient client,
    {bool openForm = true, bool focusFirst = true}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository =
      OrganizationRepository(client, local: FakeLocalRecordStore());
  addTearDown(repository.dispose);
  await tester.pumpWidget(RepositoryProvider<FrappeApiClient>.value(
    value: client,
    child: MaterialApp(
      theme: AsoudTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: OrganizationPage(
          company: 'شرکت نمونه آسود',
          repository: repository,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();

  if (!openForm) {
    if (focusFirst && client.units.isNotEmpty) {
      final ids = client.units.map((u) => u['name']).toSet();
      final roots = client.units.where((u) => !ids.contains(u['parent_department'])).toList();
      if (roots.length == 1) {
        await tester.tap(find.byKey(ValueKey('focus-unit-${roots.single['name']}')));
        await tester.pumpAndSettle();
      }
    }
    return;
  }
  await _openStructureTool(tester, 'جایگاه‌ها');
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('عملیات جایگاه'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ویرایش جایگاه'));
  await tester.pumpAndSettle();
}


Future<void> _openStructureTool(WidgetTester tester, String label) async {
  final scroll = find.byKey(const PageStorageKey('organization-focused-scroll'));
  if (scroll.evaluate().isNotEmpty) {
    final state = tester.state<ScrollableState>(find.descendant(of: scroll, matching: find.byType(Scrollable)).first);
    state.position.jumpTo(state.position.minScrollExtent);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byTooltip('ابزارهای ساختار'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  if (const bool.fromEnvironment('ORG_VISUAL')) {
    setUpAll(() async {
      await (FontLoader('Vazirmatn')
        ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'))).load();
      await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
  }
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('full unit management opens from selected chart and edits description at $width', (tester) async {
      final client = _OrgClient(units: [{
        'name': 'QUALITY', 'department_name': 'مدیریت کیفیت',
        'parent_department': '', 'is_group': 1, 'disabled': 0,
        'description': 'شرح ثبت‌شده', 'modified': '2026-10-25 10:00:00',
      }]);
      await _openCreateForm(tester, client, openForm: false);
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
      final details = find.byKey(const ValueKey('organization-full-unit-details'));
      await tester.scrollUntilVisible(details, 250,
          scrollable: find.descendant(of: find.byKey(const PageStorageKey('organization-focused-scroll')),
              matching: find.byType(Scrollable)).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(details);
      await tester.pumpAndSettle();
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('unit-details-QUALITY')), findsOneWidget);
      expect(find.text('شرح ثبت‌شده'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('organization-unit-edit')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('focus-editor-title')), 'تضمین کیفیت');
      await tester.enterText(find.byKey(const ValueKey('focus-editor-description')), 'شرح تازه');
      FocusManager.instance.primaryFocus?.unfocus();
      final detailsScroll = tester.state<ScrollableState>(find.descendant(
        of: find.byKey(const PageStorageKey('unit-details-scroll')),
        matching: find.byType(Scrollable)).first);
      detailsScroll.position.jumpTo(detailsScroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      detailsScroll.position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.widget<AppTextField>(find.byKey(const ValueKey('focus-editor-description'))).controller!.text,
          'شرح تازه', reason: 'Scrolling must not discard the inline draft.');
      final save = find.byKey(const ValueKey('focus-editor-save'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(client.lastUnitPayload!['name'], 'QUALITY');
      expect(client.lastUnitPayload!['description'], 'شرح تازه');
      expect(client.lastUnitPayload!['parent'], '');
      await tester.tap(find.byTooltip('بازگشت'));
      await tester.pumpAndSettle();
      tester.state<ScrollableState>(find.descendant(
        of: find.byKey(const PageStorageKey('organization-focused-scroll')),
        matching: find.byType(Scrollable)).first).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('focus-unit-QUALITY')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('focus-unit-QUALITY')), findsOneWidget);
      expect(find.text('تضمین کیفیت'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('root entry, path selection and branch toggle at $width', (tester) async {
      final client = _OrgClient(units: [
        {'name': 'A', 'department_name': 'فروش', 'parent_department': null, 'is_group': 1, 'disabled': 0},
        {'name': 'B', 'department_name': 'مالی', 'parent_department': null, 'is_group': 1, 'disabled': 0},
        {'name': 'A1', 'department_name': 'بازاریابی', 'parent_department': 'A', 'is_group': 1, 'disabled': 0},
        {'name': 'A2', 'department_name': 'توزیع', 'parent_department': 'A', 'is_group': 1, 'disabled': 0},
        {'name': 'A11', 'department_name': 'دیجیتال', 'parent_department': 'A1', 'is_group': 1, 'disabled': 0},
      ], positions: [
        {'code': 'CEO', 'title': 'مدیرعامل', 'parent': '', 'occupants': <String>[], 'capacity': 1},
        {'code': 'P1', 'title': 'مدیر بازاریابی', 'parent': 'CEO', 'department_id': 'A1',
          'department': 'بازاریابی', 'occupants': <String>[], 'capacity': 2},
      ]);
      await _openCreateForm(tester, client, openForm: false, focusFirst: false);
      tester.view.physicalSize = Size(width, 1400);
      await tester.pumpAndSettle();
      Finder card(String id) => find.byKey(ValueKey('focus-unit-$id'));
      Future<void> choose(String id) async {
        await Scrollable.ensureVisible(tester.element(card(id)), alignment: .5);
        await tester.pumpAndSettle();
        expect(card(id).hitTestable(), findsOneWidget);
        await tester.tap(card(id).hitTestable());
        await tester.pumpAndSettle();
      }
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('انتخاب ریشه'), findsNothing);
      expect(card('A'), findsOneWidget);
      expect(card('B'), findsOneWidget);
      expect(card('A1'), findsNothing);
      await choose('A');
      expect(card('B'), findsNothing);
      expect(card('A1'), findsOneWidget);
      expect(card('A2'), findsOneWidget);
      await choose('A1');
      expect(card('A'), findsOneWidget);
      expect(card('A2'), findsNothing);
      expect(card('A11'), findsOneWidget);
      final add = find.byKey(const ValueKey('focus-add-unit'));
      expect(tester.getTopLeft(add).dy, greaterThan(tester.getBottomLeft(card('A11')).dy));
      await choose('A1');
      expect(card('A11'), findsNothing);
      expect(find.textContaining('شاخه بسته است'), findsOneWidget);
      await choose('A1');
      expect(card('A11'), findsOneWidget);
      await choose('A');
      expect(card('A2'), findsOneWidget);
      expect(card('A11'), findsNothing);
      await Scrollable.ensureVisible(tester.element(find.byKey(const ValueKey('focus-root-CEO'))), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('focus-root-CEO')));
      await tester.pumpAndSettle();
      expect(card('B'), findsOneWidget);
      expect(card('A1'), findsNothing);
      expect(client.lastSavePayload, isNull);
      expect(client.lastUnitPayload, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  const unit = {
    'name': 'HR-CO',
    'department_name': 'منابع انسانی',
    'parent_department': 'All Departments',
    'is_group': 1,
    'disabled': 0,
    'modified': '2026-10-22 10:00:00'
  };

  Future<void> openDetails(WidgetTester tester, _OrgClient client) async {
    await _openCreateForm(tester, client, openForm: false);
    await _openStructureTool(tester, 'واحدها');
    await tester.tap(find.text('منابع انسانی').first);
    await tester.pumpAndSettle();
  }

  testWidgets('full details transfer excludes descendants and preserves native identity and positions', (tester) async {
    final client = _OrgClient(units: [
      {...unit, 'description': 'شرح محفوظ'},
      {...unit, 'name': 'CHILD', 'department_name': 'آموزش', 'parent_department': 'HR-CO'},
      {...unit, 'name': 'OTHER', 'department_name': 'فروش'},
    ], positions: [
      {'code': 'CEO', 'title': 'مدیرعامل', 'parent': '', 'occupants': <String>[]},
      {'code': 'HR', 'title': 'مدیر منابع انسانی', 'department_id': 'HR-CO', 'parent': 'CEO',
        'occupants': <String>[], 'capacity': 2, 'assignment_history': <dynamic>[]},
    ]);
    await openDetails(tester, client);
    final move = find.byKey(const ValueKey('organization-unit-move-action'));
    await tester.ensureVisible(move);
    await tester.pumpAndSettle();
    await tester.tap(move);
    await tester.pumpAndSettle();
    final parent = find.widgetWithText(AppSelectField, 'واحد بالادستی جدید');
    await tester.ensureVisible(parent);
    await tester.pumpAndSettle();
    await tester.tap(parent);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('option-HR-CO')), findsNothing);
    expect(find.byKey(const ValueKey('option-CHILD')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('option-OTHER')));
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('focus-editor-save'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(client.lastUnitPayload!['name'], 'HR-CO');
    expect(client.lastUnitPayload!['parent'], 'OTHER');
    expect(client.units.singleWhere((u) => u['name'] == 'CHILD')['parent_department'], 'HR-CO');
    expect(client.units.singleWhere((u) => u['name'] == 'HR-CO')['description'], 'شرح محفوظ');
    expect(client.lastSavePayload, isNull, reason: 'Moving a unit must not rewrite positions or history.');
    expect(tester.takeException(), isNull);
  });

  for (final blocked in [true, false]) {
    testWidgets('full details safe delete respects server blockers ($blocked)', (tester) async {
      final client = _OrgClient(units: [unit])..deleteBlocked = blocked;
      await openDetails(tester, client);
      final delete = find.byKey(const ValueKey('organization-unit-delete-action'));
      await tester.ensureVisible(delete);
      await tester.pumpAndSettle();
      await tester.tap(delete);
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, 'حذف با تأیید نهایی');
      if (blocked) {
        expect(find.text('این واحد دارای زیرواحد است؛ حذف مجاز نیست.'), findsOneWidget);
        expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      } else {
        await tester.ensureVisible(confirm);
        await tester.pumpAndSettle();
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(client.deleteCalls, 0);
        await tester.tap(find.text('تأیید حذف').last);
        await tester.pumpAndSettle();
        expect(client.deleteCalls, 1);
        expect(client.units, isEmpty);
      }
      expect(client.deleteCalls, blocked ? 0 : 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('full details hides all write actions for read-only HR', (tester) async {
    final client = _OrgClient(units: [unit])..manage = false;
    await openDetails(tester, client);
    expect(find.byKey(const ValueKey('unit-details-HR-CO')), findsOneWidget);
    expect(find.byKey(const ValueKey('organization-unit-edit')), findsNothing);
    expect(find.byKey(const ValueKey('organization-unit-delete-action')), findsNothing);
    expect(find.byKey(const ValueKey('organization-subunit-add')), findsNothing);
    expect(find.byKey(const ValueKey('organization-inline-position-open')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('full details edits position and opens HR history inline at $width', (tester) async {
      final client = _OrgClient(units: [unit], positions: [
        {'code': 'CEO', 'title': 'مدیرعامل', 'parent': '', 'occupants': <String>[]},
        {'code': 'HR', 'title': 'مدیر منابع انسانی', 'department_id': 'HR-CO', 'parent': 'CEO',
          'occupants': ['employee:ONE'], 'capacity': 2, 'assignment_history': [
            {'employee': 'employee:ONE', 'started_at': '2026-01-01 00:00:00', 'ended_at': null},
          ]},
      ])..employeeRows = [{'id': 'employee:ONE', 'display_name': 'پرسنل ثبت‌شده', 'personnel_code': '۱'}];
      await openDetails(tester, client);
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
      final edit = find.byKey(const ValueKey('unit-position-edit-HR'));
      final pageScroll = tester.state<ScrollableState>(find.descendant(
        of: find.byKey(const PageStorageKey('unit-details-scroll')),
        matching: find.byType(Scrollable)).first);
      pageScroll.position.jumpTo(pageScroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.ensureVisible(edit);
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('focus-editor-title')), 'مدیر امور کارکنان');
      await tester.enterText(find.byKey(const ValueKey('focus-editor-capacity')), '۳');
      final save = find.byKey(const ValueKey('focus-editor-save'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      final saved = (client.lastSavePayload!['rows'] as List).cast<Map>().singleWhere((r) => r['code'] == 'HR');
      expect(saved['department_id'], 'HR-CO');
      expect(saved['parent'], 'CEO');
      expect(saved['occupants'], ['employee:ONE']);
      expect(saved['assignment_history'], hasLength(1));
      expect(saved['capacity'], 3);
      final history = find.byKey(const ValueKey('unit-position-history-HR'));
      await tester.ensureVisible(history);
      await tester.pumpAndSettle();
      await tester.tap(history);
      await tester.pumpAndSettle();
      final panel = find.byKey(const ValueKey('unit-assignment-HR-true'));
      expect(panel, findsOneWidget);
      await tester.ensureVisible(panel);
      await tester.pumpAndSettle();
      expect(find.text('پرسنل ثبت‌شده'), findsOneWidget);
      expect(find.textContaining('شروع:'), findsOneWidget);
      expect(find.text('پایان: فعال'), findsOneWidget);
      expect(find.byKey(const ValueKey('focus-editor-save')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('full unit details reference render', (tester) async {
    final client = _OrgClient(units: [unit,
      {...unit, 'name': 'TRAINING', 'department_name': 'آموزش', 'parent_department': 'HR-CO'},
      {...unit, 'name': 'STAFFING', 'department_name': 'جذب و استخدام', 'parent_department': 'HR-CO'},
    ], positions: [
      {'code': 'CEO', 'title': 'مدیرعامل', 'parent': '', 'occupants': <String>[]},
      {'code': 'HR', 'title': 'مدیر منابع انسانی', 'department_id': 'HR-CO', 'parent': 'CEO',
        'occupants': <String>[], 'capacity': 2},
    ]);
    await openDetails(tester, client);
    tester.view.physicalSize = const Size(390, 1600);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(const ValueKey('unit-details-HR-CO')),
        matchesGoldenFile('../../../build/full-unit-details.png'));
  }, tags: 'golden', skip: !const bool.fromEnvironment('ORG_VISUAL'));

  testWidgets('root creates a real top-level unit inline, without a fabricated parent', (tester) async {
    final client = _OrgClient(units: [unit]);
    await _openCreateForm(tester, client, openForm: false, focusFirst: false);
    final add = find.byKey(const ValueKey('focus-add-unit'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
    final title = find.byType(TextFormField).first;
    await tester.enterText(title, 'واحد مستقل جدید');
    final save = find.byKey(const ValueKey('organization-compact-create-submit'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(client.lastUnitPayload!['title'], 'واحد مستقل جدید');
    expect(client.lastUnitPayload!['parent'], '');
    expect(client.lastUnitPayload!.containsKey('name'), isFalse);
    expect(find.byKey(const ValueKey('focus-unit-NEW-UNIT')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('assignment opens inline for the selected position and preserves history', (tester) async {
    final client = _OrgClient(units: [unit], positions: [
      {'code': 'CEO', 'title': 'مدیرعامل', 'parent': '', 'capacity': 1, 'occupants': <String>[]},
      {'code': 'P1', 'title': 'کارشناس منابع انسانی', 'parent': 'CEO', 'department_id': 'HR-CO',
        'department': 'منابع انسانی', 'capacity': 2, 'occupants': <String>[],
        'assignment_history': [{'employee': 'employee:OLD', 'started_at': null, 'ended_at': '2026-01-01'}]},
    ]);
    await _openCreateForm(tester, client, openForm: false);
    final assign = find.byTooltip('عملیات کارشناس منابع انسانی');
    await tester.ensureVisible(assign);
    await tester.tap(assign);
    await tester.pumpAndSettle();
    await tester.tap(find.text('مدیریت انتصاب پرسنل'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inline-assignment-P1')), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('ظرفیت کل'), findsOneWidget);
    expect(find.text('سوابق انتساب'), findsOneWidget);
    expect(client.writes, isEmpty);
    expect(client.positions!.last['assignment_history'], hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('focused organization reference render', (tester) async {
    await (FontLoader('Vazirmatn')
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'))).load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final client = _OrgClient(units: [
      {...unit, 'name': 'SALES', 'department_name': 'فروش و بازاریابی'},
      {...unit, 'name': 'MARKETING', 'department_name': 'بازاریابی', 'parent_department': 'SALES'},
      for (final entry in {'DIGITAL': 'بازاریابی دیجیتال', 'PR': 'روابط عمومی', 'RESEARCH': 'تحقیقات بازار', 'ADS': 'تبلیغات'}.entries)
        {...unit, 'name': entry.key, 'department_name': entry.value, 'parent_department': 'MARKETING'},
    ], positions: [
      {'code': 'CEO', 'title': 'مدیرعامل', 'parent': '', 'occupants': <String>[], 'capacity': 1},
      {'code': 'MARKETER', 'title': 'مدیر بازاریابی', 'parent': 'CEO', 'department_id': 'MARKETING',
        'department': 'بازاریابی', 'occupants': <String>[], 'capacity': 1, 'duties': 'برنامه‌ریزی و هماهنگی فعالیت‌های بازاریابی'},
    ]);
    await _openCreateForm(tester, client, openForm: false);
    tester.view.physicalSize = const Size(390, 2400);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('focus-unit-MARKETING')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('عملیات مدیر بازاریابی'));
    await tester.tap(find.byTooltip('عملیات مدیر بازاریابی'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ویرایش جایگاه'));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const PageStorageKey('organization-focused-scroll')), const Offset(0, 2400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(OrganizationPage), matchesGoldenFile('../../../build/organization-focus-reference.png'));
  }, tags: 'golden', skip: !const bool.fromEnvironment('ORG_VISUAL'));

  testWidgets('approved management layout reference render', (tester) async {
    await (FontLoader('Vazirmatn')
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'))).load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final client = _OrgClient(units: [
      {...unit, 'name': 'SALES', 'department_name': 'فروش و بازاریابی'},
      {...unit, 'name': 'MARKETING', 'department_name': 'بازاریابی', 'parent_department': 'SALES'},
      {...unit, 'name': 'DIRECT', 'department_name': 'فروش مستقیم', 'parent_department': 'SALES'},
    ], positions: [
      {'code': 'CEO', 'title': 'مدیرعامل', 'parent': '', 'occupants': <String>[], 'capacity': 1},
      {'code': 'SALES-MANAGER', 'title': 'مدیر فروش', 'parent': 'CEO', 'department_id': 'SALES',
        'department': 'فروش و بازاریابی', 'occupants': <String>[], 'capacity': 1},
    ]);
    await _openCreateForm(tester, client, openForm: false, focusFirst: false);
    tester.view.physicalSize = const Size(390, 1200);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('focus-unit-SALES')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(OrganizationPage), matchesGoldenFile('../../../build/organization-management-reference.png'));
  }, tags: 'golden', skip: !const bool.fromEnvironment('ORG_VISUAL'));

  for (final variant in ['unit', 'position', 'edit']) {
    testWidgets('inline $variant form visual reference', (tester) async {
      await (FontLoader('Vazirmatn')
        ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'))).load();
      await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final client = _OrgClient(units: [
        {...unit, 'name': 'SALES', 'department_name': 'فروش و بازاریابی'},
        {...unit, 'name': 'MARKETING', 'department_name': 'بازاریابی', 'parent_department': 'SALES'},
        {...unit, 'name': 'DIRECT', 'department_name': 'فروش مستقیم', 'parent_department': 'SALES'},
      ], positions: [
        {'code': 'CEO', 'title': 'مدیرعامل', 'parent': '', 'occupants': <String>[], 'capacity': 1},
        {'code': 'SALES-MANAGER', 'title': 'مدیر فروش', 'parent': 'CEO', 'department_id': 'SALES',
          'department': 'فروش و بازاریابی', 'occupants': <String>[], 'capacity': 1},
      ]);
      await _openCreateForm(tester, client, openForm: false);
      tester.view.physicalSize = const Size(390, 2000);
      await tester.pumpAndSettle();
      final control = variant == 'edit' ? find.byTooltip('ویرایش مدیر فروش')
        : find.byKey(ValueKey(variant == 'unit' ? 'focus-add-unit' : 'focus-add-position'));
      await tester.ensureVisible(control);
      await tester.tap(control);
      await tester.pumpAndSettle();
      final scroll = find.byKey(const PageStorageKey('organization-focused-scroll'));
      final state = tester.state<ScrollableState>(find.descendant(of: scroll, matching: find.byType(Scrollable)).first);
      state.position.jumpTo(state.position.minScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(OrganizationPage), matchesGoldenFile('../../../build/organization-$variant-form.png'));
    }, tags: 'golden', skip: !const bool.fromEnvironment('ORG_VISUAL'));
  }

  testWidgets('all direct children scroll in equal two-column cards and back restores selection', (tester) async {
    final client = _OrgClient(units: [unit, for (var i = 0; i < 9; i++) {
      ...unit, 'name': 'CHILD-$i', 'department_name': 'واحد $i', 'parent_department': 'HR-CO',
    }]);
    await _openCreateForm(tester, client, openForm: false);
    expect(find.byKey(const ValueKey('focus-unit-CHILD-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-unit-CHILD-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-unit-CHILD-8')), findsOneWidget);
    final first = tester.getRect(find.byKey(const ValueKey('focus-unit-CHILD-0')));
    final second = tester.getRect(find.byKey(const ValueKey('focus-unit-CHILD-1')));
    final third = tester.getRect(find.byKey(const ValueKey('focus-unit-CHILD-2')));
    expect(first.top, second.top);
    expect(third.top, greaterThan(first.bottom));
    expect(first.size, second.size);
    expect(first.size, third.size);
    expect(find.byTooltip('صفحه بعد'), findsNothing);
    expect(find.byTooltip('صفحه قبل'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('focus-unit-CHILD-8')));
    await tester.tap(find.byKey(const ValueKey('focus-unit-CHILD-8')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('focus-unit-HR-CO')), findsOneWidget);
    expect(find.text('هنوز زیرواحدی تعریف نشده است.'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('focus-unit-CHILD-8')), findsOneWidget);
    expect(find.byType(OrganizationPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('جزئیات واحد انتخاب‌شده'), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-position-CEO')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('native reference units alone do not create a structure on first entry', (tester) async {
    final client = _OrgClient(units: [unit], positions: []);
    await _openCreateForm(tester, client, openForm: false, focusFirst: false);
    expect(find.text('ایجاد ساختار سازمانی'), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-root-CEO')), findsNothing);
    expect(client.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final reject in [false, true]) {
    testWidgets('whole chart reset confirms and preserves native records (rejected=$reject)', (tester) async {
      final client = _OrgClient(units: [unit])..rejectReset = reject;
      await _openCreateForm(tester, client, openForm: false, focusFirst: false);
      expect(find.byKey(const ValueKey('focus-position-CEO')), findsOneWidget);
      await _openStructureTool(tester, 'حذف ساختار سازمانی');
      expect(client.resetCalls, 0);
      await tester.tap(find.text('حذف ساختار'));
      await tester.pumpAndSettle();
      expect(client.resetCalls, 1);
      expect(client.units, hasLength(1));
      expect(client.writes, isEmpty);
      expect(find.text('ایجاد ساختار سازمانی'), reject ? findsNothing : findsOneWidget);
      expect(find.byKey(const ValueKey('focus-root-CEO')), reject ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('rejected inline save retains input and never announces success', (tester) async {
    final client = _OrgClient(units: [unit])..rejectSave = true;
    await _openCreateForm(tester, client, openForm: false);
    await tester.tap(find.text('جایگاه جدید'));
    await tester.pumpAndSettle();
    final title = find.byKey(const ValueKey('focus-editor-title'));
    await tester.enterText(title, 'کارشناس بررسی');
    await tester.ensureVisible(find.text('ثبت جدید').last);
    await tester.tap(find.text('ثبت جدید').last);
    await tester.pumpAndSettle();
    expect(tester.widget<AppTextField>(title).controller!.text, 'کارشناس بررسی');
    expect(find.text('ذخیره توسط سرور رد شد.'), findsOneWidget);
    expect(find.text('تغییرات ذخیره شد.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('position selection and inline editing preserve occupants and unit path', (tester) async {
    final client = _OrgClient(units: [unit], positions: [
      {'code': 'CEO', 'title': 'مدیرعامل', 'parent': '', 'occupants': <String>[], 'capacity': 1},
      {'code': 'P1', 'title': 'مدیر آموزش', 'parent': 'CEO', 'department_id': 'HR-CO',
        'department': 'منابع انسانی', 'occupants': ['employee:A', 'employee:B'], 'capacity': 2,
        'assignment_history': [{'employee': 'employee:A', 'started_at': null, 'ended_at': null}]},
    ]);
    await _openCreateForm(tester, client, openForm: false);
    final card = find.byKey(const ValueKey('focus-position-P1'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('focus-unit-HR-CO')), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-unit-P1')), findsNothing);
    await tester.tap(find.byTooltip('عملیات مدیر آموزش'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ویرایش جایگاه'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('focus-editor-title')), 'مدیر یادگیری');
    await tester.enterText(find.byKey(const ValueKey('focus-editor-capacity')), '۱');
    await tester.ensureVisible(find.text('ذخیره تغییرات'));
    await tester.tap(find.text('ذخیره تغییرات'));
    await tester.pumpAndSettle();
    expect(find.text('ظرفیت کمتر از تعداد متصدیان فعال مجاز نیست.'), findsOneWidget);
    expect(client.lastSavePayload, isNull);
    await tester.enterText(find.byKey(const ValueKey('focus-editor-capacity')), '۳');
    await tester.tap(find.text('ذخیره تغییرات'));
    await tester.pumpAndSettle();
    final saved = (client.lastSavePayload!['rows'] as List).last as Map;
    expect(saved['code'], 'P1');
    expect(saved['department_id'], 'HR-CO');
    expect(saved['occupants'], ['employee:A', 'employee:B']);
    expect(saved['assignment_history'], hasLength(1));
    expect(saved['title'], 'مدیر یادگیری');
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('focused inline position form saves native context at $width', (tester) async {
      final client = _OrgClient(units: [unit]);
      await _openCreateForm(tester, client, openForm: false);
      tester.view.physicalSize = Size(width, 1800);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('جایگاه جدید'));
      await tester.tap(find.text('جایگاه جدید'));
      await tester.pumpAndSettle();
      final title = find.byKey(const ValueKey('focus-editor-title'));
      expect(tester.widget<AppTextField>(title).controller!.text, isEmpty);
      await tester.enterText(title, 'کارشناس توسعه');
      await tester.enterText(find.byKey(const ValueKey('focus-editor-capacity')), '۲');
      await tester.ensureVisible(find.text('ثبت جدید').last);
      await tester.tap(find.text('ثبت جدید').last);
      await tester.pumpAndSettle();
      final saved = (client.lastSavePayload!['rows'] as List).last as Map;
      expect(saved['department_id'], 'HR-CO');
      expect(saved['occupants'], isEmpty);
      expect(saved['capacity'], 2);
      expect(find.byKey(const ValueKey('focus-unit-HR-CO')), findsOneWidget);
      expect(find.byKey(const ValueKey('focus-editor-title')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unsaved inline subunit prompts before changing context and persists fixed parent', (tester) async {
    final client = _OrgClient(units: [unit, {...unit, 'name': 'CHILD', 'department_name': 'آموزش', 'parent_department': 'HR-CO'}]);
    await _openCreateForm(tester, client, openForm: false);
    await tester.tap(find.text('زیرواحد جدید'));
    await tester.pumpAndSettle();
    final title = find.byKey(const ValueKey('focus-editor-title'));
    await tester.enterText(title, 'پشتیبانی');
    final description = find.byKey(const ValueKey('focus-editor-description'));
    expect(tester.widget<AppTextField>(description).controller!.text, isEmpty);
    await tester.enterText(description, 'پاسخ‌گویی به مشتریان و هماهنگی خدمات');
    await tester.ensureVisible(find.byKey(const ValueKey('focus-unit-CHILD')));
    await tester.tap(find.byKey(const ValueKey('focus-unit-CHILD')));
    await tester.pumpAndSettle();
    expect(find.text('تغییرات ذخیره‌نشده'), findsOneWidget);
    await tester.tap(find.text('ادامه ویرایش'));
    await tester.pumpAndSettle();
    expect(tester.widget<AppTextField>(title).controller!.text, 'پشتیبانی');
    expect(client.lastUnitPayload, isNull);
    await tester.ensureVisible(find.text('ذخیره').last);
    await tester.tap(find.text('ذخیره').last);
    await tester.pumpAndSettle();
    expect(client.lastUnitPayload!['parent'], 'HR-CO');
    expect(client.lastUnitPayload!['description'], 'پاسخ‌گویی به مشتریان و هماهنگی خدمات');
    expect(client.lastUnitPayload!.containsKey('name'), isFalse);
    await tester.pump(const Duration(seconds: 4));
    await tester.ensureVisible(find.byKey(const ValueKey('focus-unit-NEW-UNIT')));
    expect(find.text('زیرواحدهای مستقیم منابع انسانی'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('pencil opens one editor below position list at $width', (tester) async {
      final client = _OrgClient(units: [unit], positions: [
        {'code': 'CEO', 'title': 'مدیرعامل', 'parent': '', 'capacity': 1, 'occupants': <String>[]},
        {'code': 'P1', 'title': 'مدیر فروش', 'parent': 'CEO', 'department_id': 'HR-CO',
          'department': 'منابع انسانی', 'capacity': 2, 'occupants': <String>[]},
      ]);
      await _openCreateForm(tester, client, openForm: false);
      tester.view.physicalSize = Size(width, 2000);
      await tester.pumpAndSettle();
      final pencil = find.byTooltip('ویرایش مدیر فروش');
      await tester.ensureVisible(pencil);
      await tester.tap(pencil);
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);
      final field = find.byKey(const ValueKey('focus-editor-title'));
      expect(tester.widget<AppTextField>(field).controller!.text, 'مدیر فروش');
      expect(tester.getTopLeft(field).dy, greaterThan(tester.getBottomLeft(find.byKey(const ValueKey('focus-position-P1'))).dy));
      expect(tester.getTopLeft(find.text('جزئیات واحد انتخاب‌شده')).dy,
        greaterThan(tester.getBottomLeft(find.byKey(const ValueKey('focus-editor-save'))).dy));
      expect(find.byKey(const ValueKey('focus-editor-title')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('unit management keeps root and all direct children at $width', (tester) async {
      final client = _OrgClient(units: [unit, {
        ...unit, 'name': 'CHILD-A', 'department_name': 'آموزش', 'parent_department': 'HR-CO',
      }, {
        ...unit, 'name': 'CHILD-B', 'department_name': 'جذب', 'parent_department': 'HR-CO',
      }]);
      await _openCreateForm(tester, client, openForm: false, focusFirst: false);
      tester.view.physicalSize = Size(width, 1600);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('focus-root-CEO')), findsOneWidget);
      await tester.ensureVisible(find.text('منابع انسانی').first);
      await tester.tap(find.text('منابع انسانی').first);
      await tester.pumpAndSettle();
      // Selection now expands in place, without the old management route.
      expect(find.byKey(const ValueKey('focus-unit-HR-CO')), findsOneWidget);
      expect(find.byKey(const ValueKey('focus-root-CEO')), findsOneWidget);
      expect(find.text('آموزش'), findsOneWidget);
      expect(find.text('جذب'), findsOneWidget);
      expect(find.text('زیرواحدهای مستقیم منابع انسانی'), findsOneWidget);
      expect(client.lastUnitPayload, isNull);
      await tester.tap(find.text('آموزش'));
      await tester.pumpAndSettle();
      expect(find.text('هنوز زیرواحدی تعریف نشده است.'), findsOneWidget);
      expect(find.text('جذب'), findsNothing);
      expect(find.byKey(const ValueKey('focus-unit-HR-CO')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('focus-unit-HR-CO')));
      await tester.pumpAndSettle();
      expect(find.text('جذب'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unit details opens as a page with inline editing and management',
      (tester) async {
    final client = _OrgClient(units: [unit]);
    await _openCreateForm(tester, client, openForm: false);
    await _openStructureTool(tester, 'واحدها');
    await tester.pumpAndSettle();
    await tester.tap(find.text('منابع انسانی'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('organization-unit-edit')), findsOneWidget);
    expect(find.text('ویرایش مشخصات واحد'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('جزئیات واحد سازمانی'), findsOneWidget);
    expect(find.text('انتقال واحد'), findsOneWidget);
    expect(find.text('حذف ایمن واحد'), findsOneWidget);
    expect(find.textContaining('All Departments'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('organization-unit-edit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('focus-editor-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-editor-description')), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-editor-save')), findsOneWidget);
    expect(client.lastUnitPayload, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adding a subunit starts blank and does not edit its parent',
      (tester) async {
    final client = _OrgClient(units: [unit]);
    await _openCreateForm(tester, client, openForm: false);
    await _openStructureTool(tester, 'واحدها');
    await tester.pumpAndSettle();
    await tester.tap(find.text('منابع انسانی'));
    await tester.pumpAndSettle();
    final add = find.byKey(const ValueKey('organization-subunit-add'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    final title = find.byKey(const ValueKey('focus-editor-title'));
    expect(tester.widget<AppTextField>(title).controller!.text, isEmpty);
    await tester.enterText(title, 'آموزش');
    final submit = find.byKey(const ValueKey('focus-editor-save'));
    expect(submit, findsOneWidget);
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(client.lastUnitPayload!.containsKey('name'), isFalse);
    expect(client.lastUnitPayload!['parent'], 'HR-CO');
    expect(client.lastUnitPayload!['title'], 'آموزش');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'inline position creation preserves the native unit and creates no assignment',
      (tester) async {
    final client = _OrgClient(units: [unit]);
    await _openCreateForm(tester, client, openForm: false);
    await _openStructureTool(tester, 'واحدها');
    await tester.pumpAndSettle();
    await tester.tap(find.text('منابع انسانی'));
    await tester.pumpAndSettle();
    final add = find.byKey(const ValueKey('organization-inline-position-open'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('focus-editor-save'));
    await tester.enterText(
        find.byKey(const ValueKey('focus-editor-title')),
        'کارشناس آموزش');
    // onChanged schedules the rebuild that enables the save button.
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(client.lastSavePayload, isNotNull,
        reason: 'Saving the inline position must reach the repository.');
    final rows = (client.lastSavePayload!['rows'] as List).cast<Map>();
    final added = rows.singleWhere((r) => r['title'] == 'کارشناس آموزش');
    expect(added['department_id'], 'HR-CO');
    expect(added['occupants'], isEmpty);
    expect(added['capacity'], 1);
    expect(rows.any((r) => r['code'] == 'CEO'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'assignment page shows real capacity and retains assignment history tab',
      (tester) async {
    await _openCreateForm(tester, _OrgClient(), openForm: false);
    await _openStructureTool(tester, 'جایگاه‌ها');
    await tester.pumpAndSettle();
    await tester.tap(find.text('مدیرعامل'));
    await tester.pumpAndSettle();
    final assignments = find.text('انتساب پرسنل و سوابق');
    await tester.ensureVisible(assignments);
    await tester.tap(assignments);
    await tester.pumpAndSettle();
    expect(find.text('ظرفیت کل'), findsOneWidget);
    expect(find.text('ظرفیت خالی'), findsOneWidget);
    expect(find.text('ظرفیت جایگاه تکمیل است.'), findsOneWidget);
    await tester.tap(find.text('سوابق انتساب').last);
    await tester.pumpAndSettle();
    expect(find.text('سابقه‌ای ثبت نشده است.'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('organization management and visual report fit at $width',
        (tester) async {
      final client = _OrgClient();
      await _openCreateForm(tester, client);
      await tester.tap(find.text('انصراف'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('بازگشت').first);
      await tester.pumpAndSettle();
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsNothing);
      await _openStructureTool(tester, 'واحدها');
      expect(find.text('هنوز واحدی تعریف نشده است.'), findsOneWidget);
      await tester.tap(find.byTooltip('بازگشت').first);
      await tester.pumpAndSettle();
      await _openStructureTool(tester, 'جایگاه‌ها');
      expect(find.text('جایگاه‌های سازمانی'), findsWidgets);
      await tester.tap(find.byTooltip('بازگشت').first);
      await tester.pumpAndSettle();
      final report = find.text('گزارش تصویری چارت');
      // A cached child can exist below the viewport in NestedScrollView.
      // Real gestures scroll both coordinated viewports; wait for a hit target,
      // not merely for the lazy child to have been built.
      for (var attempt = 0;
          attempt < 20 && report.hitTestable().evaluate().isEmpty;
          attempt++) {
        await tester.drag(find.byKey(const PageStorageKey('organization-focused-scroll')), const Offset(0, -200));
        await tester.pumpAndSettle();
      }
      expect(report.hitTestable(), findsOneWidget);
      await tester.tap(report.hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('نمای فهرستی'), findsOneWidget);
      expect(find.text('ورود از اکسل'), findsOneWidget);
      expect(find.text('ایجاد دستی'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the visual report still renders when the units list fails',
      (tester) async {
    final client = _OrgClient()..failUnits = true;
    await _openCreateForm(tester, client, openForm: false, focusFirst: false);
    tester.view.physicalSize = const Size(390, 800);
    await tester.pumpAndSettle();
    final report = find.text('گزارش تصویری چارت');
    for (var attempt = 0;
        attempt < 20 && report.hitTestable().evaluate().isEmpty;
        attempt++) {
      await tester.drag(find.byKey(const PageStorageKey('organization-focused-scroll')), const Offset(0, -200));
      await tester.pumpAndSettle();
    }
    await tester.tap(report.hitTestable());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('visual-units-unavailable')),
        findsOneWidget);
    expect(find.text('مدیرعامل'), findsWidgets);
    expect(find.text('دریافت اطلاعات ناموفق بود؛ تلاش دوباره'), findsNothing);
  });

  testWidgets('the position form uses AppTextField and AppSelectField',
      (tester) async {
    await _openCreateForm(tester, _OrgClient());

    expect(find.text('عنوان جایگاه *'), findsOneWidget);
    expect(find.text('کد جایگاه *'), findsNothing);
    expect(find.widgetWithText(AppSelectField, 'واحد سازمانی'), findsOneWidget);
    expect(find.byType(AppTextField), findsNWidgets(3));
    expect(find.byType(AppSelectField), findsNWidgets(2));
    expect(find.text('ظرفیت *'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('position edit keeps its code and occupants', (tester) async {
    final client = _OrgClient();
    await _openCreateForm(tester, client);
    final title = find.widgetWithText(TextFormField, 'عنوان جایگاه *');
    await tester.enterText(title, '');
    await tester.tap(find.text('ثبت تغییرات'));
    await tester.pumpAndSettle();
    expect(find.text('عنوان جایگاه را وارد کنید.'), findsOneWidget);
    await tester.enterText(title, 'مدیر ارشد');
    await tester.tap(find.text('ثبت تغییرات'));
    await tester.pumpAndSettle();
    final rows = (client.lastSavePayload!['rows'] as List).cast<Map>();
    final edited = rows.singleWhere((r) => r['code'] == 'CEO');
    expect(edited['title'], 'مدیر ارشد');
    expect(edited['occupants'], ['EMP-001']);
    expect(rows.length, 1);
    expect(tester.takeException(), isNull);
  });
}
