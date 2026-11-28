import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/form_fields_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Client extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => false;
}

Widget _form(FormMap schema, FormMap values) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Form(
            child: FormFieldsView(
              schema: schema,
              values: values,
              enabled: false,
              snapshot: true,
              onChanged: (_) {},
              repository: FormRepository(_Client(), 'شرکت'),
            ),
          ),
        ),
      ),
    );

FormMap _fileSchema() => {
      'sections': [
        {
          'fields': [
            {
              'key': 'report',
              'type': 'File',
              'label': 'گزارش',
            },
          ],
        },
      ],
    };

void main() {
  testWidgets('پیوست ذخیره‌شده با نام فایل نشان داده می‌شود، نه مسیر خام',
      (tester) async {
    await tester.pumpWidget(_form(
        _fileSchema(),
        {'report': '/private/files/2026/11/28/report-final.pdf'}));
    await tester.pumpAndSettle();

    // The raw server path must never reach the screen.
    expect(find.textContaining('/private/files/'), findsNothing);
    // The file name is shown instead.
    expect(find.text('report-final.pdf'), findsOneWidget);
  });

  testWidgets('پیوست چندمقداری هر نام را جدا نشان می‌دهد', (tester) async {
    await tester.pumpWidget(_form(
        _fileSchema(),
        {'report': [
          '/private/files/a/اول.pdf',
          '/private/files/b/دوم.xlsx',
        ]}));
    await tester.pumpAndSettle();

    expect(find.textContaining('/private/files/'), findsNothing);
    expect(find.text('اول.pdf، دوم.xlsx'), findsOneWidget);
  });

  testWidgets('نام محلی بدون مسیر همان‌طور که هست نشان داده می‌شود',
      (tester) async {
    await tester.pumpWidget(
        _form(_fileSchema(), {'report': 'پیش‌نمایش محلی: قرارداد.pdf'}));
    await tester.pumpAndSettle();

    expect(find.text('پیش‌نمایش محلی: قرارداد.pdf'), findsOneWidget);
  });

  testWidgets('روی عرض ۳۲۰ نام فایل بدون سرریز جا می‌شود', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_form(
        _fileSchema(),
        {'report': '/private/files/2026/11/28/report-final.pdf'}));
    await tester.pumpAndSettle();

    expect(find.text('report-final.pdf'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
