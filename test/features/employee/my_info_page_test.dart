import 'package:asoud_erp/features/employee/presentation/pages/my_info_page.dart';
import 'package:asoud_erp/features/hr/data/personnel_file_repository.dart';
import 'package:asoud_erp/features/hr/domain/personnel_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/features/workflows/data/generic_request_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/generic_request_page.dart';

class Files extends Fake implements PersonnelFileRepository {
  Files({this.sparse = false});
  final bool sparse;
  @override
  Future<PersonnelFile> myFile() async => PersonnelFile.fromJson(sparse
      ? {
          'header': {'name': 'امیر موفق', 'employee_code': 'LOCAL-42'},
        }
      : {
          'header': {
            'name': 'امیر موفق',
            'employee_code': 'EMP-42',
            'designation': 'کارشناس',
            'department_name': 'فروش',
            'status': 'Active'
          },
          'personal': {
            'national_id': '0012345678',
            'birth_date': '1990-03-21',
            'marital_status': 'Married',
            'mobile': '09123456789',
            'email': 'amir@example.com',
            'address_line': 'تهران، خیابان آزادی'
          },
          'organization': {
            'department_name': 'فروش',
            'designation': 'کارشناس',
            'reports_to': {'name': 'سارا احمدی'},
            'branch': 'تهران'
          },
          'employment': {
            'employment_type': 'Full-time',
            'date_of_joining': '2025-03-21',
            'service_length': {'years': 1, 'months': 6}
          },
          'contracts': [
            {
              'state': 'active',
              'start_date': '2026-03-21',
              'end_date': '2027-03-20',
              'days_remaining': 166
            }
          ],
          'salary': {
            'visible': true,
            'current': {'base': 765432109},
            'legacy': {
              'iban': 'IR123456',
              'bank_account': '998877',
              'bank_name': 'بانک خصوصی'
            }
          },
          'documents': [
            {
              'id': 'DOC-1',
              'title': 'کارت ملی',
              'category': 'Identity',
              'document_number': '12345'
            },
            {
              'id': 'BANK-1',
              'title': 'شماره حساب',
              'category': 'Financial',
              'document_number': '998877'
            }
          ],
        });
}

Widget app(Widget page) => MaterialApp(
    builder: (_, child) =>
        Directionality(textDirection: TextDirection.rtl, child: child!),
    home: page);

class Requests extends Fake implements GenericRequestRepository {
  Requests(this.suitable);
  final bool suitable;
  @override
  Future<List<Map<String, dynamic>>> options() async => [
        {
          'name': 'TYPE-1',
          'workflow_title': suitable ? 'اصلاح اطلاعات پرسنلی' : 'درخواست خرید',
          'fields': []
        }
      ];
}

void main() {
  for (final suitable in [true, false]) {
    testWidgets('edit request suitability $suitable', (tester) async {
      await tester.pumpWidget(
          app(MyInfoPage(repository: Files(), requests: Requests(suitable))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ویرایش'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('بررسی امکان ثبت درخواست'));
      await tester.pumpAndSettle();
      if (suitable) {
        expect(find.byType(GenericRequestPage), findsOneWidget);
        expect(
            tester
                .widget<GenericRequestPage>(find.byType(GenericRequestPage))
                .definition?['name'],
            'TYPE-1');
      } else {
        expect(find.byType(GenericRequestPage), findsNothing);
        expect(
            find.text('برای ویرایش اطلاعات با واحد منابع انسانی هماهنگ کنید'),
            findsOneWidget);
      }
    });
  }

  for (final width in [320.0, 390.0]) {
    testWidgets('MyInfo full fixture tabs and privacy at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app(MyInfoPage(repository: Files())));
      await tester.pumpAndSettle();
      for (final label in ['اطلاعات کلی', 'سازمانی', 'استخدامی', 'تماس']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('EMP-42'), findsOneWidget);
      await tester.tap(find.text('اطلاعات کلی'));
      await tester.pumpAndSettle();
      expect(find.text('وضعیت خدمت'), findsOneWidget);
      final values = {
        'اطلاعات کلی': {
          'نام و نام خانوادگی': 'امیر موفق',
          'کد ملی': '0012345678',
          'تاریخ تولد': '۱۳۶۹/۰۱/۰۱',
          'وضعیت تأهل': 'متأهل',
          'وضعیت': 'فعال',
          'نوع خدمت': 'تمام وقت'
        },
        'سازمانی': {
          'واحد': 'فروش',
          'سمت': 'کارشناس',
          'مدیر مستقیم': 'سارا احمدی',
          'محل کار/شعبه': 'تهران'
        },
        'استخدامی': {
          'نوع همکاری': 'تمام وقت',
          'تاریخ شروع': '۱۴۰۴/۰۱/۰۱',
          'سابقه خدمت': '۱ سال و ۶ ماه',
          'تاریخ شروع قرارداد': '۱۴۰۵/۰۱/۰۱',
          'تاریخ پایان قرارداد': '۱۴۰۵/۱۲/۲۹',
          'زمان باقی‌مانده': '۱۶۶ روز'
        },
        'تماس': {
          'شماره موبایل': '09123456789',
          'ایمیل': 'amir@example.com',
          'نشانی': 'تهران، خیابان آزادی'
        },
      };
      for (final entry in values.entries) {
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        for (final pair in entry.value.entries) {
          final row = find.ancestor(
              of: find.text(pair.key), matching: find.byType(Row));
          expect(find.descendant(of: row, matching: find.text(pair.value)),
              findsOneWidget,
              reason: '${pair.key}: ${pair.value}');
        }
        for (final forbidden in [
          'حقوق',
          'حقوق پایه',
          'حقوق و مزایا',
          'شماره شبا',
          'شماره حساب',
          'بانک',
          '765432109',
          'IR123456',
          '998877'
        ]) {
          expect(find.textContaining(forbidden), findsNothing);
        }
        expect(tester.takeException(), isNull);
      }
      expect(tester.widget<Text>(find.text('amir@example.com')).textDirection,
          TextDirection.ltr);
      await tester.tap(find.text('ویرایش'));
      await tester.pumpAndSettle();
      expect(find.textContaining('واحد منابع انسانی'), findsOneWidget);
      expect(find.textContaining('درخواست'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
    testWidgets('MyInfo sparse fixture hides local code at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app(MyInfoPage(repository: Files(sparse: true))));
      await tester.pumpAndSettle();
      expect(find.text('در انتظار ثبت'), findsOneWidget);
      for (final tab in ['اطلاعات کلی', 'سازمانی', 'استخدامی', 'تماس']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(find.text('ثبت نشده'), findsWidgets);
        expect(find.textContaining('LOCAL-'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets('documents entry opens MyInfo documents section', (tester) async {
    await tester
        .pumpWidget(app(MyInfoPage(repository: Files(), showDocuments: true)));
    await tester.pumpAndSettle();
    expect(find.text('کارت ملی'), findsOneWidget);
    expect(find.text('12345'), findsOneWidget);
    expect(find.text('شماره حساب'), findsNothing);
    expect(find.text('998877'), findsNothing);
    expect(find.text('مشاهده/دانلود فایل'), findsOneWidget);
  });
}
