import 'dart:convert';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/widgets/asoud_form.dart';
import 'package:asoud_erp/features/hr/data/personnel_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const _png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aV2kAAAAASUVORK5CYII=';
const _kinds = {'attendance': 'کارکرد و سوابق حضور', 'evaluation': 'ارزیابی عملکرد',
  'document': 'مدارک و مستندات', 'photo': 'تصویر پرسنل', 'history': 'تاریخچه'};

class _Repository extends Mock implements PersonnelRepository {
  @override
  bool get localDemo => false;
  @override
  Future<Map<String, dynamic>> recordOptions(String id) async => {
    'appraisal_cycles': [{'name': 'دوره سالانه'}]
  };
  @override
  Future<Map<String, dynamic>> profileOptions(String id) async => {
    'department': ['منابع انسانی'], 'job_title': ['کارشناس منابع انسانی'],
    'employment_type': ['تمام وقت']
  };
  final values = <String, Map<String, dynamic>>{};
  final profile = <String, dynamic>{'id': 'LOCAL-person', 'display_name': 'علی رضایی',
    'job_title': 'کارشناس منابع انسانی', 'department': 'منابع انسانی',
    'mobile': '09121234567', 'employee_gender': 'Male', 'birth_date': '1992-05-11',
    'date_of_joining': '2024-04-21', 'employment_type': 'تمام وقت', 'city': 'تهران'};
  int creates = 0, edits = 0;
  bool failSave = false;
  @override
  Future<Map<String, dynamic>> detail(String id) async => {'profile': profile,
    'revision': 'profile-1', 'can_edit': true, 'records': [for (final e in values.entries)
      {'name': e.key, 'title': e.value['title'], 'kind': e.value['kind'], 'record_date': e.value['date']}]};
  @override
  Future<Map<String, dynamic>> record(String id) async => Map.from(values[id]!);
  @override
  Future<void> add(String id, Map<String, dynamic> payload, String requestId) async {
    creates++;
    values['new'] = {...payload, '_revision': '1', '_can_edit': true};
  }
  @override
  Future<void> updateRecord(String personId, String recordId, Map<String, dynamic> payload, String revision, String requestId) async {
    if (failSave) throw StateError('ذخیره ناموفق');
    edits++;
    values[recordId] = {...payload, '_revision': '2', '_can_edit': true};
  }
  @override
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> values, String revision) async {
    edits++; profile.addAll(values); return detail(id);
  }
}

class _Files extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({String? dialogTitle, String? initialDirectory,
    FileType type = FileType.any, List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading, bool allowCompression = false,
    int compressionQuality = 0, bool allowMultiple = false, bool withData = false,
    bool withReadStream = false, bool lockParentWindow = false, bool readSequential = false}) async {
    final bytes = base64Decode(_png);
    return FilePickerResult([PlatformFile(name: 'document.png', size: bytes.length, bytes: bytes)]);
  }
}

Future<void> _start(WidgetTester tester, _Repository repo, {double width = 390}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: AsoudTheme.light,
    home: PersonnelDetailPage(id: 'LOCAL-person', repository: repo)));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> _section(WidgetTester tester, String title) async {
  await tester.scrollUntilVisible(find.widgetWithText(ExpansionTile, title), 150,
    scrollable: find.byType(Scrollable).first);
  await tester.tap(find.widgetWithText(ExpansionTile, title));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('salary editor renders values and refreshes after save', (tester) async {
    final repo = _Repository();
    repo.profile['base_salary'] = '12345';
    await _start(tester, repo);
    await _tap(tester, 'اطلاعات پرسنلی');
    await _tap(tester, 'حقوق و مزایا');
    await _tap(tester, 'ثبت و ویرایش حقوق و مزایا');
    await _section(tester, 'حقوق و مزایا');
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(6));
    expect(tester.widget<TextFormField>(fields.first).controller!.text, '12345');
    await tester.enterText(fields.first, '45678');
    await _tap(tester, 'ذخیره');
    expect(repo.profile['base_salary'].toString(), '45678');
    expect(find.text('45678'), findsOneWidget);
  });

  setUpAll(() async {
    await (FontLoader('Vazirmatn')..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'))).load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final e in _kinds.entries) {
    testWidgets('${e.key}: list, accordion create, detail and edit persist', (tester) async {
      FilePicker.platform = _Files();
      final repo = _Repository();
      await _start(tester, repo, width: e.key == 'attendance' ? 320 : 390);
      await _tap(tester, ['document', 'photo'].contains(e.key) ? 'مدارک' : 'سوابق');
      await _tap(tester, e.value);
      expect(find.text('هنوز موردی ثبت نشده است.'), findsOneWidget);
      await _tap(tester, 'ثبت مورد جدید');
      expect(find.byType(AsoudFormPage), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      if (e.key == 'evaluation') {
        await expectLater(find.byType(Scaffold).last, matchesGoldenFile('goldens/personnel_form_closed_390.png'));
      }
      await _section(tester, 'اطلاعات اصلی');
      await tester.enterText(find.widgetWithText(TextFormField, 'عنوان *'), 'سابقه نمونه');
      if (e.key == 'attendance') {
        await _section(tester, 'ساعات حضور');
        await tester.enterText(find.widgetWithText(TextFormField, 'ساعت ورود'), '08:00');
        await tester.enterText(find.widgetWithText(TextFormField, 'ساعت خروج'), '16:00');
      }
      if (e.key == 'evaluation') {
        await _section(tester, 'نتیجه ارزیابی');
        await _tap(tester, 'دوره ارزیابی *');
        await _tap(tester, 'دوره سالانه');
        await tester.enterText(find.widgetWithText(TextFormField, 'امتیاز هدف از ۱۰۰ *'), '85');
        await tester.pumpAndSettle();
        await expectLater(find.byType(Scaffold).last, matchesGoldenFile('goldens/personnel_form_open_390.png'));
      }
      if (['document', 'photo'].contains(e.key)) {
        await _section(tester, 'فایل پیوست');
        await _tap(tester, 'انتخاب فایل');
      }
      await _tap(tester, 'ذخیره');
      expect(repo.creates, 1);
      if (e.key == 'evaluation') {
        expect(repo.values['new']!['appraisal_cycle'], 'دوره سالانه');
      }
      expect(find.text('سابقه نمونه'), findsOneWidget);
      if (e.key == 'evaluation') {
        await expectLater(find.byType(Scaffold).last, matchesGoldenFile('goldens/personnel_records_390.png'));
      }
      await _tap(tester, 'سابقه نمونه');
      expect(find.text('جزئیات سابقه'), findsOneWidget);
      if (e.key == 'evaluation') {
        await expectLater(find.byType(Scaffold).last, matchesGoldenFile('goldens/personnel_record_detail_390.png'));
      }
      await _tap(tester, 'ویرایش سابقه');
      await _section(tester, 'اطلاعات اصلی');
      expect(find.widgetWithText(TextFormField, 'سابقه نمونه'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'عنوان *'), 'سابقه ویرایش‌شده');
      if (e.key == 'evaluation') {
        repo.failSave = true;
        await _tap(tester, 'ذخیره');
        expect(repo.edits, 0);
        expect(find.widgetWithText(TextFormField, 'سابقه ویرایش‌شده'), findsOneWidget);
        repo.failSave = false;
      }
      await _tap(tester, 'ذخیره');
      expect(repo.edits, 1);
      expect(find.text('سابقه ویرایش‌شده'), findsOneWidget);
      if (['document', 'photo'].contains(e.key)) expect(repo.values['new']!['file'], _png);
      await tester.tap(find.byTooltip('بازگشت').last);
      await tester.pumpAndSettle();
      expect(find.text('سابقه ویرایش‌شده'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, tags: 'golden');
  }

  testWidgets('profile details open a separate locked-style editor and refresh after save', (tester) async {
    final repo = _Repository();
    await _start(tester, repo);
    await _tap(tester, 'اطلاعات فردی');
    expect(find.byType(TextFormField), findsNothing);
    await expectLater(find.byType(Scaffold).last, matchesGoldenFile('goldens/personnel_personal_390.png'));
    await _tap(tester, 'ویرایش اطلاعات');
    await _section(tester, 'اطلاعات اصلی');
    await tester.enterText(find.widgetWithText(TextFormField, 'نام و نام خانوادگی'), 'علی جدید');
    await _section(tester, 'اطلاعات اصلی');
    await _section(tester, 'اطلاعات اصلی');
    expect(find.widgetWithText(TextFormField, 'علی جدید'), findsOneWidget);
    await _tap(tester, 'ذخیره');
    expect(repo.profile['display_name'], 'علی جدید');
    expect(find.byType(TextFormField), findsNothing);
    expect(tester.takeException(), isNull);
  }, tags: 'golden');

  testWidgets('recent activity opens its own record and system audit has no edit action', (tester) async {
    final repo = _Repository();
    repo.values['audit'] = {'title': 'تغییر اطلاعات', 'kind': 'history', 'date': '2026-09-12', '_can_edit': false};
    await _start(tester, repo);
    await _tap(tester, 'تغییر اطلاعات');
    expect(find.text('جزئیات سابقه'), findsOneWidget);
    expect(find.text('ویرایش سابقه'), findsNothing);
    await tester.tap(find.byTooltip('بازگشت').last);
    await tester.pumpAndSettle();
    await _tap(tester, 'مشاهده همه');
    expect(find.text('سوابق و فعالیت‌ها'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
