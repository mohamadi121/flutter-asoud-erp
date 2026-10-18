import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/form_editor.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';

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
