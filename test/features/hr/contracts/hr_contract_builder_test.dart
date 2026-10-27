import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/hr/data/hr_contract_template_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/contracts/hr_contract_builder_page.dart';

void main() {
  group('HR Contract Builder UI Tests', () {
    late FakeHrContractTemplateRepository repository;

    setUp(() {
      repository = FakeHrContractTemplateRepository();
    });

    Widget createWidget({
      required Widget child,
      Size size = const Size(390, 844),
      bool canManageTemplate = true,
    }) {
      return MaterialApp(
        theme: AsoudTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQueryData(size: size),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        ),
      );
    }

    testWidgets('renders collapsible article cards and expands on tap at 390px RTL',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createWidget(
        child: HrContractBuilderPage(
          company: 'شرکت نمونه',
          repository: repository,
          canManageTemplate: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('قالب قرارداد کار'), findsOneWidget);
      expect(find.text('طرفین قرارداد'), findsOneWidget);
      expect(find.text('موضوع و محل کار'), findsOneWidget);

      // Verify article card can be tapped to expand
      final articleCard = find.text('موضوع و محل کار');
      await tester.tap(articleCard);
      await tester.pumpAndSettle();

      expect(find.textContaining('موضوع همکاری، عنوان شغل'), findsOneWidget);
    });

    testWidgets('tapping "ویرایش" opens inline editor under article, and "انصراف" discards changes',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createWidget(
        child: HrContractBuilderPage(
          company: 'شرکت نمونه',
          repository: repository,
          canManageTemplate: true,
        ),
      ));
      await tester.pumpAndSettle();

      // Expand article 1
      await tester.tap(find.text('طرفین قرارداد'));
      await tester.pumpAndSettle();

      // Tap "ویرایش" button
      final editBtn = find.text('ویرایش');
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Inline editor is visible with title, text area, and action buttons
      expect(find.text('ذخیره تغییرات'), findsOneWidget);
      expect(find.text('انصراف'), findsOneWidget);
      expect(find.text('درج فیلد پرسنلی یا شرکت در متن'), findsOneWidget);

      // Change text
      final textField = find.byType(TextFormField).first;
      await tester.enterText(textField, 'عنوان ویرایش‌شده تستی');
      await tester.pumpAndSettle();

      // Tap "انصراف"
      await tester.tap(find.text('انصراف'));
      await tester.pumpAndSettle();

      // Changes discarded, original title remains
      expect(find.text('عنوان ویرایش‌شده تستی'), findsNothing);
      expect(find.text('طرفین قرارداد'), findsOneWidget);
    });

    testWidgets('opens insert-field drawer and inserts selected field at cursor position',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createWidget(
        child: HrContractBuilderPage(
          company: 'شرکت نمونه',
          repository: repository,
          canManageTemplate: true,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap article 1 and edit
      await tester.tap(find.text('طرفین قرارداد'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ویرایش'));
      await tester.pumpAndSettle();

      // Open insert-field drawer
      final insertFieldBtn = find.text('درج فیلد پرسنلی یا شرکت در متن');
      await tester.tap(insertFieldBtn);
      await tester.pumpAndSettle();

      // Check drawer elements
      expect(find.text('انتخاب فیلد موجود'), findsOneWidget);
      expect(find.text('اطلاعات پرسنل'), findsOneWidget);

      // Tap a field to insert
      final fieldToInsert = find.widgetWithText(ListTile, 'نام');
      expect(fieldToInsert, findsOneWidget);
      await tester.tap(fieldToInsert);
      await tester.pumpAndSettle();

      // Body text now contains [نام پرسنل]
      expect(find.textContaining('[نام پرسنل]'), findsOneWidget);
    });

    testWidgets('article 4 displays repeating payroll table and field picker',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createWidget(
        child: HrContractBuilderPage(
          company: 'شرکت نمونه',
          repository: repository,
          canManageTemplate: true,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap article 4 (حقوق و مزایا)
      await tester.tap(find.text('حقوق و مزایا'));
      await tester.pumpAndSettle();

      expect(find.text('حقوق پایه'), findsWidgets);
      expect(find.text('حق مسکن'), findsWidgets);
      expect(find.text('بن خواربار'), findsWidgets);

      // Tap edit on article 4
      await tester.tap(find.text('ویرایش'));
      await tester.pumpAndSettle();

      // Repeating table editor
      expect(find.text('جدول تکرارشونده حقوق و مزایا'), findsOneWidget);
      expect(find.text('افزودن ردیف جدید'), findsOneWidget);
    });

    testWidgets('reorders articles using up/down buttons while preserving stable IDs',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createWidget(
        child: HrContractBuilderPage(
          company: 'شرکت نمونه',
          repository: repository,
          canManageTemplate: true,
        ),
      ));
      await tester.pumpAndSettle();

      // Expand article 2
      await tester.tap(find.text('موضوع و محل کار'));
      await tester.pumpAndSettle();

      // Find move up button
      final moveUpBtn = find.byIcon(Icons.arrow_upward);
      expect(moveUpBtn, findsOneWidget);
      await tester.tap(moveUpBtn);
      await tester.pumpAndSettle();

      // Article 2 is now first
      final template = repository.currentTemplate;
      expect(template.clauses.first.title, 'موضوع و محل کار');
      expect(template.clauses.first.id, 2); // ID preserved
    });

    testWidgets('non-manager user (HR expert without template permission) cannot see edit/builder entry points',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createWidget(
        canManageTemplate: false,
        child: HrContractBuilderPage(
          company: 'شرکت نمونه',
          repository: repository,
          canManageTemplate: false,
        ),
      ));
      await tester.pumpAndSettle();

      // Edit buttons and add article must NOT be rendered
      expect(find.text('ویرایش'), findsNothing);
      expect(find.text('افزودن ماده جدید'), findsNothing);
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.textContaining('دسترسی فقط‌خواندنی'), findsOneWidget);
    });

    testWidgets('renders correctly at 320px width without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createWidget(
        size: const Size(320, 640),
        child: HrContractBuilderPage(
          company: 'شرکت نمونه',
          repository: repository,
          canManageTemplate: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('قالب قرارداد کار'), findsOneWidget);
    });
  });
}
