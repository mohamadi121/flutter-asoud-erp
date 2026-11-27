import 'package:asoud_erp/core/widgets/template_text.dart';
import 'package:asoud_erp/features/hr/data/employment_certificate_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/employment_certificate_template_builder_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCertificateRepository implements EmploymentCertificateRepository {
  EmploymentCertificateTemplate template = const EmploymentCertificateTemplate(
    name: 'tmpl-cert-1',
    revision: 1,
    status: 'Draft',
    salaryEnabled: false,
    clauses: [
      CertificateClause(
        id: 'recipient',
        title: 'مخاطب',
        body: 'به: {{certificate.addressee_name}}',
        enabled: true,
      ),
      CertificateClause(
        id: 'main_body',
        title: 'متن اصلی',
        body:
            'گواهی می‌شود که {{employee.employee_name}} از تاریخ {{employee.date_of_joining}} در شرکت {{company.company_name}} مشغول به کار بوده است.',
        enabled: true,
      ),
    ],
    salaryRows: [],
  );

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
  }) async => template;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Widget _wrap(Widget child, {_FakeCertificateRepository? repo, double width = 390}) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: MediaQueryData(size: Size(width, 844)),
        child: RepositoryProvider<EmploymentCertificateRepository>(
          create: (_) => repo ?? _FakeCertificateRepository(),
          child: child,
        ),
      ),
    ),
  );
}

TemplateTextController _bodyController(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).last).controller! as TemplateTextController;

void main() {
  group('EmploymentCertificateTemplateBuilderPage field chip', () {
    testWidgets('known tokens render as Persian chips while source stays byte-for-byte', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _FakeCertificateRepository();
      await tester.pumpWidget(_wrap(
        const EmploymentCertificateTemplateBuilderPage(company: 'شرکت نمونه'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      // The second clause is expanded by default; open its inline editor.
      await tester.tap(find.text('ویرایش').last);
      await tester.pumpAndSettle();

      expect(find.text('نام کامل پرسنل'), findsOneWidget);
      expect(find.text('تاریخ شروع همکاری'), findsOneWidget);
      expect(find.text('نام شرکت'), findsOneWidget);
      // The editor field shows chips, not raw tokens.
      expect(
          find.descendant(of: find.byType(TextField).last, matching: find.textContaining('{{')),
          findsNothing);

      final controller = _bodyController(tester);
      expect(controller.source, repo.template.clauses[1].body);
    });

    testWidgets('inserts a chip at the cursor in the middle of Persian text', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _FakeCertificateRepository();
      await tester.pumpWidget(_wrap(
        const EmploymentCertificateTemplateBuilderPage(company: 'شرکت نمونه'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ویرایش').last);
      await tester.pumpAndSettle();

      final bodyField = find.byType(TextField).last;
      await tester.enterText(bodyField, 'گواهی اشتغال');
      final controller = _bodyController(tester);
      controller.selection = TextSelection.collapsed(offset: 3);

      await tester.tap(find.text('درج فیلد در متن بند'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'کد ملی'));
      await tester.pumpAndSettle();

      expect(controller.source, 'گوا{{employee.national_id}}هی اشتغال');
      expect(find.text('کد ملی'), findsOneWidget);
    });

    testWidgets('deleting the chip keeps the surrounding text and undo restores it', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _FakeCertificateRepository();
      await tester.pumpWidget(_wrap(
        const EmploymentCertificateTemplateBuilderPage(company: 'شرکت نمونه'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ویرایش').last);
      await tester.pumpAndSettle();

      // The clause body already holds chips (loaded via loadSource), so the
      // undo history starts clean. Insert a new chip at the start.
      final controller = _bodyController(tester);
      final original = controller.source;
      await tester.showKeyboard(find.byType(TextField).last);
      controller.selection = TextSelection.collapsed(offset: 0);
      controller.insertToken('{{employee.national_id}}');
      await tester.pump(const Duration(milliseconds: 600));
      final inserted = controller.value;
      expect(controller.source, '{{employee.national_id}}$original');

      // Delete the chip (one marker char); the surrounding text stays.
      tester.testTextInput.updateEditingValue(TextEditingValue(
        text: inserted.text.replaceRange(0, 1, ''),
        selection: TextSelection.collapsed(offset: 0),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      expect(controller.source, original);

      // Undo restores the chip.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(controller.value.text, inserted.text);
      expect(controller.source, '{{employee.national_id}}$original');
    });

    testWidgets('unknown legacy token is kept verbatim and shown as unknown', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const body = 'متن با {{certificate.legacy_field}} و {{employee.employee_name}}';
      final repo = _FakeCertificateRepository();
      repo.template = EmploymentCertificateTemplate(
        name: 'tmpl-cert-1',
        revision: 1,
        status: 'Draft',
        salaryEnabled: false,
        clauses: [
          CertificateClause(id: 'c1', title: 'بند تست', body: body, enabled: true),
        ],
        salaryRows: [],
      );
      await tester.pumpWidget(_wrap(
        const EmploymentCertificateTemplateBuilderPage(company: 'شرکت نمونه', canManageTemplate: true),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ویرایش'));
      await tester.pumpAndSettle();

      expect(find.text('فیلد ناشناخته'), findsOneWidget);
      expect(find.text('نام کامل پرسنل'), findsOneWidget);
      expect(_bodyController(tester).source, body);

      await tester.tap(find.text('ذخیره تغییرات'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('ذخیره پیش‌نویس قالب'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('ذخیره پیش‌نویس قالب'));
      await tester.pumpAndSettle();
      expect(repo.template.clauses.single.body, body);
    });

    testWidgets('editor with chips does not overflow at 320 px', (tester) async {
      // 320 px is the overflow dimension; a tall surface keeps the editor reachable.
      await tester.binding.setSurfaceSize(const Size(320, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _FakeCertificateRepository();
      await tester.pumpWidget(_wrap(
        const EmploymentCertificateTemplateBuilderPage(company: 'شرکت نمونه'),
        repo: repo,
        width: 320,
      ));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('ویرایش').first, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('ویرایش').first);
      await tester.tap(find.text('ویرایش').first);
      await tester.pumpAndSettle();

      // The first clause body holds {{certificate.addressee_name}} → «گیرنده گواهی».
      expect(find.text('گیرنده گواهی'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('new clause saves the chip as the {{token}} source, not marker text', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _FakeCertificateRepository();
      await tester.pumpWidget(_wrap(
        const EmploymentCertificateTemplateBuilderPage(company: 'شرکت نمونه', canManageTemplate: true),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      // Open the new-clause form.
      await tester.tap(find.text('افزودن بند جدید'));
      await tester.pumpAndSettle();

      // Fill the title and body, then insert a chip at the start of the body.
      await tester.enterText(find.byType(TextField).first, 'بند جدید تستی');
      await tester.enterText(find.byType(TextField).last, 'متن جدید');
      final controller = _bodyController(tester);
      controller.selection = TextSelection.collapsed(offset: 0);

      await tester.scrollUntilVisible(find.text('درج فیلد در بند جدید'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('درج فیلد در بند جدید'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'کد ملی'));
      await tester.pumpAndSettle();

      // Save the new clause, then persist the draft so the repo reflects it.
      await tester.tap(find.text('افزودن بند'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('ذخیره پیش‌نویس قالب'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('ذخیره پیش‌نویس قالب'));
      await tester.pumpAndSettle();

      final stored = repo.template.clauses.last.body;
      expect(stored, '{{employee.national_id}}متن جدید');
      // No private-use marker character may leak into the stored text.
      expect(stored.codeUnits.any((u) => u >= 0xe000 && u <= 0xf8ff), isFalse);
    });
  });
}
