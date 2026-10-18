import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/create_form_page.dart';
import 'package:asoud_erp/features/form_builder/form_editor.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/forms_page.dart';

class _GoldenMockClient extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => true;

  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
        userId: 'admin@asoud.local',
        fullName: 'مدیر سیستم',
        roles: ['System Manager', 'Administrator'],
        company: 'شرکت نمونه آسود',
      );

  @override
  Future<Map<String, dynamic>> callMethod(
    String method, {
    Map<String, dynamic>? data,
  }) async {
    if (method.endsWith('list_forms')) {
      return {
        'message': {
          'ok': true,
          'data': [
            {
              'name': 'FORM-001',
              'title': 'فرم درخواست مرخصی',
              'kind': 'Request',
              'module_key': 'HR',
              'status': 'Published',
              'version': 1,
              'draft_version': 1,
              'schema': {
                'title': 'فرم درخواست مرخصی',
                'module': 'HR',
              },
            },
            {
              'name': 'FORM-002',
              'title': 'فرم درخواست اضافه‌کاری',
              'kind': 'Request',
              'module_key': 'HR',
              'status': 'Draft',
              'version': 1,
              'draft_version': 1,
              'schema': {
                'title': 'فرم درخواست اضافه‌کاری',
                'module': 'HR',
              },
            },
            {
              'name': 'FORM-003',
              'title': 'فرم درخواست مأموریت',
              'kind': 'Request',
              'module_key': 'Purchase',
              'status': 'Published',
              'version': 1,
              'draft_version': 1,
              'schema': {
                'title': 'فرم درخواست مأموریت',
                'module': 'Purchase',
              },
            },
            {
              'name': 'FORM-004',
              'title': 'فرم درخواست خرید کالا',
              'kind': 'Request',
              'module_key': 'Purchase',
              'status': 'Published',
              'version': 1,
              'draft_version': 1,
              'schema': {
                'title': 'فرم درخواست خرید کالا',
                'module': 'Purchase',
              },
            },
          ],
        },
      };
    }
    if (method.endsWith('get_options')) {
      return {
        'message': {
          'ok': true,
          'data': {
            'roles': <String>[],
            'departments': <String>[],
            'workflows': <Map<String, dynamic>>[],
          },
        },
      };
    }
    return {
      'message': {
        'ok': true,
        'data': <Map<String, dynamic>>[],
      },
    };
  }
}

Widget _wrapGolden(Widget child, FrappeApiClient client) =>
    RepositoryProvider<FrappeApiClient>.value(
      value: client,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('fa'),
        theme: AsoudTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: child,
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final vazirmatn = FontLoader('Vazirmatn')
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'));
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([vazirmatn.load(), materialIcons.load()]);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('forms list page 360x800 golden', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _GoldenMockClient();

    await tester.pumpWidget(_wrapGolden(
      const VersionedFormsPage(company: 'شرکت نمونه آسود'),
      client,
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/forms_list_360x800.png'),
    );
  }, tags: 'golden');

  testWidgets('create form page 360x800 golden', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _GoldenMockClient();
    final repo = FormRepository(client, 'شرکت نمونه آسود');

    await tester.pumpWidget(_wrapGolden(
      CreateFormPage(
        repository: repo,
        selectedModule: 'HR',
        initialKind: 'Request',
      ),
      client,
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/create_form_360x800.png'),
    );
  }, tags: 'golden');

  testWidgets('create form page with template picker 360x800 golden',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _GoldenMockClient();
    final repo = FormRepository(client, 'شرکت نمونه آسود');

    await tester.pumpWidget(_wrapGolden(
      CreateFormPage(
        repository: repo,
        selectedModule: 'HR',
        initialKind: 'Request',
      ),
      client,
    ));
    await tester.pumpAndSettle();

    // Select template mode and open sheet
    await tester.tap(find.text('استفاده از الگوی آماده'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('برای انتخاب الگو لمس کنید...'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/create_form_template_picker_360x800.png'),
    );
  }, tags: 'golden');

  testWidgets('form designer page 360x800 golden', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _GoldenMockClient();
    final repo = FormRepository(client, 'شرکت نمونه آسود');

    final initialForm = {
      'name': 'FORM-001',
      'title': 'درخواست معرفی تأمین‌کننده',
      'status': 'Draft',
      'schema': {
        'title': 'درخواست معرفی تأمین‌کننده',
        'module': 'Purchase',
        'kind': 'Request',
        'sections': [
          {
            'id': 'sec_main',
            'title': 'اطلاعات اصلی',
            'color': '#EFF6FF',
            'fields': [
              {
                'key': 'f_subject',
                'label': 'موضوع درخواست',
                'type': 'Text',
                'required': true,
              },
              {
                'key': 'f_date',
                'label': 'تاریخ درخواست',
                'type': 'Date',
                'required': true,
              },
              {
                'key': 'f_desc',
                'label': 'شرح درخواست',
                'type': 'LongText',
                'required': false,
              },
            ],
          },
          {
            'id': 'sec_extra',
            'title': 'اطلاعات تکمیلی',
            'color': '#F0FDF4',
            'fields': [
              {
                'key': 'f_supplier',
                'label': 'نام تأمین‌کننده پیشنهادی',
                'type': 'Text',
                'required': false,
              },
            ],
          },
          {
            'id': 'sec_end',
            'title': 'پایان',
            'color': '#EEF2FF',
            'fields': [
              {
                'key': 'f_note',
                'label': 'یادداشت پایانی',
                'type': 'Text',
                'required': false,
              },
            ],
          },
        ],
        'rules': <FormMap>[],
      },
    };

    await tester.pumpWidget(_wrapGolden(
      FormEditorPage(
        repository: repo,
        initial: initialForm,
      ),
      client,
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/form_designer_360x800.png'),
    );
  }, tags: 'golden');
}
