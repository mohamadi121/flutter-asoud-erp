import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/workflow_automation_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/document_template.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/document_template_wizard_page.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/document_templates_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _options = DocumentTemplateOptions(
  modules: [
    DocumentModule(key: 'Finance', label: 'مالی', types: [
      DocumentTypeOption(key: 'Journal Entry', label: 'سند حسابداری'),
      DocumentTypeOption(key: 'Receipt', label: 'دریافت', enabled: false),
    ]),
    DocumentModule(key: 'HR', label: 'منابع انسانی'),
  ],
  fields: {
    'Journal Entry': [
      DocumentTargetField(
          key: 'posting_date',
          label: 'تاریخ سند',
          type: 'Date',
          required: true),
      DocumentTargetField(
          key: 'amount', label: 'مبلغ', type: 'Currency', required: true),
      DocumentTargetField(
          key: 'debit_account',
          label: 'حساب بدهکار',
          type: 'Account',
          required: true),
      DocumentTargetField(key: 'project', label: 'پروژه', type: 'Project'),
    ],
  },
  sources: {
    'request': [
      DocumentValueOption(key: 'subject', label: 'عنوان درخواست', type: 'Text'),
      DocumentValueOption(
          key: 'total', label: 'مبلغ کل درخواست', type: 'Currency'),
    ],
    'system': [DocumentValueOption(key: 'today', label: 'تاریخ روز')],
  },
  placeholders: ['{{RequestNo}}'],
);

const _custom = DocumentTemplate(
    name: 'TPL-1',
    title: 'سند هزینه خرید',
    description: 'ثبت سند هزینه بر اساس درخواست خرید',
    module: 'Finance',
    documentType: 'Journal Entry');
const _ready = DocumentTemplate(
    name: 'purchase_expense',
    title: 'پرداخت به تأمین‌کننده',
    module: 'Finance',
    documentType: 'Journal Entry',
    kind: 'ready',
    presetKey: 'purchase_expense',
    mapping: {'posting_date': ValueSource(source: 'system', value: 'today')});

class _Repo extends Fake implements WorkflowAutomationRepository {
  final kinds = <String>[];
  DocumentTemplate? saved;
  String? savedWorkflow;
  @override
  Future<List<DocumentTemplate>> templates(
      {required String company,
      String kind = 'custom',
      String? module,
      String? documentType,
      String search = ''}) async {
    kinds.add(kind);
    return kind == 'ready' ? [_ready] : [_custom];
  }

  @override
  Future<DocumentTemplateOptions> templateOptions(
          {required String company, String? workflow}) async =>
      _options;

  @override
  Future<List<LinkOption>> linkOptions(
          {required String company,
          required String targetType,
          String txt = ''}) async =>
      const [LinkOption(value: 'Expenses - T', label: 'هزینه‌های عمومی')];

  @override
  Future<DocumentTemplate> saveTemplate(
      {required String company,
      required DocumentTemplate template,
      String? sourceWorkflow}) async {
    saved = template;
    savedWorkflow = sourceWorkflow;
    return DocumentTemplate(
        name: 'TPL-9',
        title: template.title,
        module: template.module,
        documentType: template.documentType,
        mapping: template.mapping);
  }
}

class _Workflows extends Fake implements WorkflowRepository {
  @override
  Future<List<WorkflowDefinition>> getWorkflows(
          {String? search,
          WorkflowDefinitionStatus? status,
          String? company,
          String orderBy = 'modified desc'}) async =>
      const [];
}

Widget _app(Widget page) => MaterialApp(
    theme: AsoudTheme.light,
    home: Directionality(textDirection: TextDirection.rtl, child: page));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('templates list switches between custom and ready at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _Repo();
      await tester.pumpWidget(
          _app(DocumentTemplatesPage(company: 'تابان', repository: repo)));
      await tester.pumpAndSettle();
      expect(find.text('سند هزینه خرید'), findsOneWidget);
      expect(find.text('سفارشی'), findsOneWidget);
      await _tap(tester, find.text('الگوهای آماده'));
      expect(repo.kinds, ['custom', 'ready']);
      expect(find.text('پرداخت به تأمین‌کننده'), findsOneWidget);
      expect(find.text('آماده'), findsOneWidget);
      expect(find.text('ایجاد الگوی جدید'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('wizard maps a ready template and saves it as custom',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Repo();
    await tester.pumpWidget(_app(DocumentTemplateWizardPage(
        company: 'تابان',
        repository: repo,
        workflows: _Workflows(),
        initial: _ready)));
    await tester.pumpAndSettle();
    expect(find.text('ایجاد الگوی سند'), findsOneWidget);
    expect(find.text('مالی'), findsOneWidget);
    expect(find.text('سند حسابداری'), findsOneWidget);
    await _tap(tester, find.text('بعدی'));

    // Required fields are selected and locked; optional ones can be added.
    expect(find.text('فیلدهای سند حسابداری'), findsOneWidget);
    expect(find.text('الزامی'), findsNWidgets(3));
    await _tap(tester, find.text('بعدی'));

    // Mapping: posting date is prefilled, amount and account are still open.
    expect(find.text('مقدار سیستم: تاریخ روز'), findsOneWidget);
    await _tap(tester, find.text('بعدی'));
    expect(find.text('منبع مقدار «مبلغ» را مشخص کنید.'), findsOneWidget);

    await _tap(tester, find.text('منبع مقدار را انتخاب کنید').first);
    await _tap(tester, find.text('فیلد درخواست'));
    expect(find.text('انتخاب فیلد درخواست'), findsOneWidget);
    expect(
        find.text('عنوان درخواست'), findsNothing); // text cannot fill an amount
    await _tap(tester, find.text('مبلغ کل درخواست'));
    await _tap(tester, find.text('انتخاب'));
    expect(find.text('فیلد درخواست: مبلغ کل درخواست'), findsOneWidget);

    await _tap(tester, find.text('منبع مقدار را انتخاب کنید').first);
    await _tap(tester, find.text('مقدار ثابت'));
    await _tap(tester, find.text('هزینه‌های عمومی'));
    await _tap(tester, find.text('انتخاب'));
    expect(find.text('Expenses - T'), findsOneWidget);

    await _tap(tester, find.text('بعدی'));
    expect(find.text('ایجاد به‌صورت پیش‌نویس'), findsOneWidget);
    await _tap(tester, find.text('ثبت خودکار'));
    await _tap(tester, find.text('ذخیره'));

    final saved = repo.saved!;
    expect(saved.isReady, isTrue); // a preset is saved as a new template
    expect(saved.autoSubmit, isTrue);
    expect(saved.mapping['amount']!.value, 'total');
    expect(saved.mapping['debit_account']!.value, 'Expenses - T');
    expect(find.text('الگو با موفقیت ایجاد شد'), findsOneWidget);
    expect(find.textContaining('در ماژول مالی - سند حسابداری'), findsOneWidget);
  });

  testWidgets('base info requires a name and disabled types stay disabled',
      (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(_app(DocumentTemplateWizardPage(
        company: 'تابان', repository: repo, workflows: _Workflows())));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('بعدی'));
    expect(find.text('نام الگو را وارد کنید.'), findsOneWidget);
    await _tap(tester, find.text('سند حسابداری'));
    expect(find.text('انتخاب نوع سند'), findsOneWidget);
    expect(find.text('به‌زودی'), findsOneWidget);
  });
}
