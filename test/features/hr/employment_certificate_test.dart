import 'package:asoud_erp/features/hr/data/employment_certificate_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/employment_certificate_form_page.dart';
import 'package:asoud_erp/features/hr/presentation/pages/employment_certificate_preview_page.dart';
import 'package:asoud_erp/features/hr/presentation/pages/employment_certificate_template_builder_page.dart';
import 'package:asoud_erp/features/hr/presentation/pages/employment_certificates_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeEmploymentCertificateRepository implements EmploymentCertificateRepository {
  EmploymentCertificateTemplate template = const EmploymentCertificateTemplate(
    name: 'tmpl-1',
    revision: 1,
    status: 'Published',
    salaryEnabled: true,
    clauses: [
      CertificateClause(id: 'recipient', title: 'مخاطب', body: 'به: {{certificate.addressee_name}}', enabled: true),
      CertificateClause(id: 'main_body', title: 'متن', body: 'گواهی اشتغال {{employee.employee_name}}', enabled: true),
    ],
    salaryRows: [
      SalaryRowDefinition(id: 'base', title: 'حقوق پایه', fieldRef: 'payroll.base', period: 'monthly'),
    ],
  );

  final List<EmploymentCertificate> certificates = [
    const EmploymentCertificate(
      name: 'CERT-DRAFT-1',
      employeeName: 'علی محمدی',
      employeeNumber: 'EMP-001',
      number: '—',
      addresseeName: 'بانک ملت',
      status: 'Draft',
      purpose: 'تسهیلات',
    ),
    const EmploymentCertificate(
      name: 'CERT-1405-001',
      employeeName: 'سارا احمدی',
      employeeNumber: 'EMP-002',
      number: '۱۴۰۵-۰۰۱',
      addresseeName: 'سفارت',
      status: 'Final',
      purpose: 'ویزا',
    ),
  ];

  @override
  Future<EmploymentCertificateTemplate> getTemplate({required String company}) async => template;

  @override
  Future<EmploymentCertificateTemplate> saveTemplateDraft({
    required String company,
    required int revision,
    required List<CertificateClause> clauses,
    required bool salaryEnabled,
    required List<SalaryRowDefinition> salaryRows,
  }) async {
    template = EmploymentCertificateTemplate(
      name: template.name,
      revision: revision + 1,
      status: 'Draft',
      salaryEnabled: salaryEnabled,
      clauses: clauses,
      salaryRows: salaryRows,
    );
    return template;
  }

  @override
  Future<EmploymentCertificateTemplate> publishTemplate({
    required String company,
    required int revision,
  }) async {
    template = EmploymentCertificateTemplate(
      name: template.name,
      revision: revision,
      status: 'Published',
      salaryEnabled: template.salaryEnabled,
      clauses: template.clauses,
      salaryRows: template.salaryRows,
    );
    return template;
  }

  @override
  Future<({List<EmploymentCertificate> items, int total})> list({
    required String company,
    String query = '',
    String status = '',
    int start = 0,
    int pageLength = 20,
  }) async {
    var filtered = certificates;
    if (status.isNotEmpty) {
      filtered = filtered.where((c) => c.status == status).toList();
    }
    if (query.isNotEmpty) {
      filtered = filtered.where((c) => c.employeeName.contains(query) || c.addresseeName.contains(query)).toList();
    }
    return (items: filtered, total: filtered.length);
  }

  @override
  Future<EmploymentCertificateDetail> getCertificate({required String name}) async {
    final cert = certificates.firstWhere((c) => c.name == name);
    return EmploymentCertificateDetail(
      name: cert.name,
      company: 'شرکت نمونه',
      employee: cert.employeeNumber,
      employeeName: cert.employeeName,
      employeeNumber: cert.employeeNumber,
      number: cert.number,
      addresseeType: 'بانک',
      addresseeName: cert.addresseeName,
      addresseeTitle: 'ریاست محترم',
      purpose: cert.purpose,
      location: 'تهران',
      notes: '',
      status: cert.status,
      revision: 1,
      templateVersion: 1,
      renderedHtml: '<article><p>متن گواهی برای ${cert.employeeName}</p></article>',
      printHtml: '<article><p>متن چاپ برای ${cert.employeeName}</p></article>',
      salaryRows: cert.status == 'Final' ? [{'title': 'حقوق پایه', 'amount': '۱۰۰,۰۰۰,۰۰۰'}] : [],
      hasSalary: true,
      issueDate: cert.status == 'Final' ? '۱۴۰۵/۰۱/۱۵' : '',
    );
  }

  @override
  Future<EmploymentCertificateDetail> saveDraft({
    required String company,
    required String employee,
    String addresseeType = '',
    required String addresseeName,
    String addresseeTitle = '',
    String purpose = '',
    required String requestKey,
    int revision = 0,
    String name = '',
    String notes = '',
    bool includeSalary = false,
    String location = '',
  }) async {
    return EmploymentCertificateDetail(
      name: name.isNotEmpty ? name : 'CERT-DRAFT-NEW',
      company: company,
      employee: employee,
      employeeName: 'علی محمدی',
      employeeNumber: employee,
      number: '—',
      addresseeType: addresseeType,
      addresseeName: addresseeName,
      addresseeTitle: addresseeTitle,
      purpose: purpose,
      location: location,
      notes: notes,
      status: 'Draft',
      revision: revision + 1,
      templateVersion: 1,
      renderedHtml: '<article><p>متن پیش‌نویس</p></article>',
      printHtml: '<article><p>متن چاپ پیش‌نویس</p></article>',
      salaryRows: [],
      hasSalary: includeSalary,
      issueDate: '',
    );
  }

  @override
  Future<EmploymentCertificateDetail> finalizeCertificate({
    required String name,
    required int revision,
    required String requestKey,
  }) async {
    return EmploymentCertificateDetail(
      name: name,
      company: 'شرکت نمونه',
      employee: 'EMP-001',
      employeeName: 'علی محمدی',
      employeeNumber: 'EMP-001',
      number: '۱۴۰۵-۹۹۹',
      addresseeType: 'بانک',
      addresseeName: 'بانک ملت',
      addresseeTitle: 'ریاست',
      purpose: 'تسهیلات',
      location: 'تهران',
      notes: '',
      status: 'Final',
      revision: revision + 1,
      templateVersion: 1,
      renderedHtml: '<article><p>متن نهایی شده</p></article>',
      printHtml: '<article><p>متن چاپ نهایی</p></article>',
      salaryRows: [],
      hasSalary: false,
      issueDate: '۱۴۰۵/۰۱/۱۵',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getEmployeeOptions({required String company}) async {
    return [
      {'name': 'EMP-001', 'employee_name': 'علی محمدی', 'department': 'فنی', 'designation': 'توسعه‌دهنده'},
      {'name': 'EMP-002', 'employee_name': 'سارا احمدی', 'department': 'مالی', 'designation': 'حسابدار'},
    ];
  }
}

Widget _wrapWithRtl(Widget child, {FakeEmploymentCertificateRepository? repo, double width = 390}) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: MediaQueryData(size: Size(width, 844)),
        child: RepositoryProvider<EmploymentCertificateRepository>(
          create: (_) => repo ?? FakeEmploymentCertificateRepository(),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('EmploymentCertificate models', () {
    test('Template and clauses serialization roundtrip', () {
      final jsonMap = {
        'name': 'tmpl-1',
        'revision': 2,
        'status': 'Published',
        'salary_enabled': true,
        'clauses': [
          {'id': 'c1', 'title': 'بند ۱', 'body': 'متن ۱', 'enabled': true},
        ],
        'salary_rows': [
          {'id': 's1', 'title': 'حقوق پایه', 'field_ref': 'payroll.base', 'period': 'monthly'},
        ],
      };
      final tmpl = EmploymentCertificateTemplate.fromMap(jsonMap);
      expect(tmpl.name, 'tmpl-1');
      expect(tmpl.revision, 2);
      expect(tmpl.status, 'Published');
      expect(tmpl.salaryEnabled, true);
      expect(tmpl.clauses.first.id, 'c1');
      expect(tmpl.clauses.first.title, 'بند ۱');
      expect(tmpl.salaryRows.first.fieldRef, 'payroll.base');

      final serialized = tmpl.toMap();
      expect(serialized['salary_enabled'], true);
      expect((serialized['clauses'] as List).length, 1);
    });

    test('Detail serialization and status labels', () {
      final detail = EmploymentCertificateDetail.fromMap({
        'name': 'CERT-1',
        'company': 'شرکت الف',
        'employee': 'EMP-1',
        'employee_name': 'رضا باقری',
        'employee_number': 'EMP-1',
        'number': '۱۴۰۵-۰۲',
        'addressee_type': 'بانک',
        'addressee_name': 'بانک سپه',
        'addressee_title': '',
        'purpose': 'وام',
        'location': 'مشهد',
        'notes': '',
        'status': 'Final',
        'revision': 1,
        'template_version': 1,
        'rendered_html': '<p>متن</p>',
        'print_html': '<p>چاپ</p>',
        'salary_rows': [],
        'has_salary': false,
        'issue_date': '۱۴۰۵/۰۲/۰۱',
      });
      expect(detail.employeeName, 'رضا باقری');
      expect(detail.statusLabel, 'نهایی');
      expect(detail.isFinal, isTrue);
    });
  });

  group('EmploymentCertificatesPage UI', () {
    for (final width in [320.0, 390.0, 430.0]) {
      testWidgets('renders list and filter at width $width without overflow', (tester) async {
        final repo = FakeEmploymentCertificateRepository();
        await tester.pumpWidget(_wrapWithRtl(
          const EmploymentCertificatesPage(company: 'شرکت نمونه'),
          repo: repo,
          width: width,
        ));
        await tester.pumpAndSettle();

        expect(find.text('گواهی‌های اشتغال به کار'), findsOneWidget);
        expect(find.text('＋ گواهی جدید'), findsOneWidget);
        expect(find.text('علی محمدی'), findsOneWidget);
        expect(find.text('سارا احمدی'), findsOneWidget);
      });
    }

    testWidgets('filtering by search updates visible list', (tester) async {
      final repo = FakeEmploymentCertificateRepository();
      await tester.pumpWidget(_wrapWithRtl(
        const EmploymentCertificatesPage(company: 'شرکت نمونه'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('علی محمدی'), findsOneWidget);
      expect(find.text('سارا احمدی'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'سارا');
      await tester.pumpAndSettle();

      expect(find.text('سارا احمدی'), findsOneWidget);
      expect(find.text('علی محمدی'), findsNothing);
    });

    testWidgets('hides template builder button when canManageTemplate is false and shows when true', (tester) async {
      final repo = FakeEmploymentCertificateRepository();
      await tester.pumpWidget(_wrapWithRtl(
        const EmploymentCertificatesPage(company: 'شرکت نمونه', canManageTemplate: false),
        repo: repo,
      ));
      await tester.pumpAndSettle();
      expect(find.text('ویرایش قالب'), findsNothing);

      await tester.pumpWidget(_wrapWithRtl(
        const EmploymentCertificatesPage(company: 'شرکت نمونه', canManageTemplate: true),
        repo: repo,
      ));
      await tester.pumpAndSettle();
      expect(find.text('ویرایش قالب'), findsOneWidget);
    });
  });

  group('EmploymentCertificateFormPage UI', () {
    for (final width in [320.0, 390.0, 430.0]) {
      testWidgets('renders form fields at width $width without overflow', (tester) async {
        final repo = FakeEmploymentCertificateRepository();
        await tester.pumpWidget(_wrapWithRtl(
          const EmploymentCertificateFormPage(company: 'شرکت نمونه'),
          repo: repo,
          width: width,
        ));
        await tester.pumpAndSettle();

        expect(find.text('صدور گواهی اشتغال'), findsOneWidget);
        expect(find.text('۱. مشخصات پرسنل'), findsOneWidget);
        expect(find.text('۲. مشخصات گواهی'), findsOneWidget);

        await tester.scrollUntilVisible(find.text('ذخیره پیش‌نویس'), 300, scrollable: find.byType(Scrollable).first);
        expect(find.text('ذخیره پیش‌نویس'), findsOneWidget);
      });
    }
  });

  group('EmploymentCertificatePreviewPage UI', () {
    for (final width in [320.0, 390.0, 430.0]) {
      testWidgets('renders preview paper at width $width without overflow', (tester) async {
        final repo = FakeEmploymentCertificateRepository();
        await tester.pumpWidget(_wrapWithRtl(
          const EmploymentCertificatePreviewPage(certificateName: 'CERT-DRAFT-1', company: 'شرکت نمونه'),
          repo: repo,
          width: width,
        ));
        await tester.pumpAndSettle();

        expect(find.text('پیش‌نمایش گواهی اشتغال'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('چاپ گواهی'), 300);
        expect(find.text('چاپ گواهی'), findsOneWidget);
      });
    }
  });

  group('EmploymentCertificateTemplateBuilderPage UI', () {
    for (final width in [320.0, 390.0, 430.0]) {
      testWidgets('renders template designer at width $width without overflow', (tester) async {
        final repo = FakeEmploymentCertificateRepository();
        await tester.pumpWidget(_wrapWithRtl(
          const EmploymentCertificateTemplateBuilderPage(company: 'شرکت نمونه'),
          repo: repo,
          width: width,
        ));
        await tester.pumpAndSettle();

        expect(find.text('قالب گواهی اشتغال به کار'), findsOneWidget);
        expect(find.text('ویرایش قالب'), findsOneWidget);
        expect(find.text('پیش‌نمایش سند'), findsOneWidget);
        expect(find.text('بندهای متن گواهی'), findsOneWidget);
      });
    }

    testWidgets('disables save and publish when canManageTemplate is false', (tester) async {
      final repo = FakeEmploymentCertificateRepository();
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrapWithRtl(
        const EmploymentCertificateTemplateBuilderPage(company: 'شرکت نمونه', canManageTemplate: false),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      final saveFinder = find.widgetWithText(ElevatedButton, 'ذخیره پیش‌نویس قالب');
      expect(saveFinder, findsOneWidget);
      final saveButton = tester.widget<ElevatedButton>(saveFinder);
      expect(saveButton.onPressed, isNull);

      final publishFinder = find.widgetWithText(ElevatedButton, 'انتشار قالب');
      expect(publishFinder, findsOneWidget);
      final publishButton = tester.widget<ElevatedButton>(publishFinder);
      expect(publishButton.onPressed, isNull);
    });
  });
}
