import 'package:asoud_erp/core/widgets/template_text.dart';
import 'package:asoud_erp/features/hr/data/personnel_introduction_letter_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_introduction_letter_template_builder_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {FakePersonnelIntroductionLetterRepository? repo, double width = 390}) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: MediaQueryData(size: Size(width, 844)),
        child: RepositoryProvider<PersonnelIntroductionLetterRepository>(
          create: (_) => repo ?? FakePersonnelIntroductionLetterRepository(),
          child: child,
        ),
      ),
    ),
  );
}

TemplateTextController _bodyController(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).last).controller! as TemplateTextController;

void main() {
  group('PersonnelIntroductionLetterTemplateBuilderPage field chip', () {
    testWidgets('known tokens render as Persian chips while source stays byte-for-byte', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = FakePersonnelIntroductionLetterRepository();
      await tester.pumpWidget(_wrap(
        const PersonnelIntroductionLetterTemplateBuilderPage(company: 'شرکت نمونه'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      // The first clause is expanded by default; open its inline editor.
      await tester.tap(find.text('ویرایش'));
      await tester.pumpAndSettle();

      // The known tokens render as Persian chips (not raw tokens).
      expect(find.text('نام مرجع دریافت‌کننده'), findsOneWidget);
      expect(find.text('نام و نام خانوادگی پرسنل'), findsOneWidget);

      // The stored source is unchanged, byte-for-byte.
      final controller = _bodyController(tester);
      expect(controller.source, repo.template.clauses.first.body);
    });

    testWidgets('inserts a chip at the cursor in the middle of Persian text', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = FakePersonnelIntroductionLetterRepository();
      await tester.pumpWidget(_wrap(
        const PersonnelIntroductionLetterTemplateBuilderPage(company: 'شرکت نمونه'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ویرایش'));
      await tester.pumpAndSettle();

      final bodyField = find.byType(TextField).last;
      await tester.enterText(bodyField, 'به نام خدا');
      final controller = _bodyController(tester);
      controller.selection = TextSelection.collapsed(offset: 3);

      await tester.tap(find.text('درج فیلد در متن بند'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'کد پرسنلی'));
      await tester.pumpAndSettle();

      expect(controller.source, 'به {{employee.employee_number}}نام خدا');
      expect(find.text('کد پرسنلی'), findsOneWidget);
    });

    testWidgets('deleting the chip keeps the surrounding text and undo restores it', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = FakePersonnelIntroductionLetterRepository();
      await tester.pumpWidget(_wrap(
        const PersonnelIntroductionLetterTemplateBuilderPage(company: 'شرکت نمونه'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ویرایش'));
      await tester.pumpAndSettle();

      // The clause body already holds chips (loaded via loadSource), so the
      // undo history starts clean. Insert a new chip at the start.
      final controller = _bodyController(tester);
      final original = controller.source;
      await tester.showKeyboard(find.byType(TextField).last);
      controller.selection = TextSelection.collapsed(offset: 0);
      controller.insertToken('{{employee.employee_number}}');
      await tester.pump(const Duration(milliseconds: 600));
      final inserted = controller.value;
      expect(controller.source, '{{employee.employee_number}}$original');

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
      expect(controller.source, '{{employee.employee_number}}$original');
    });

    testWidgets('unknown legacy token is kept verbatim and shown as unknown', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const body = 'متن با {{letter.legacy_field}} و {{employee.employee_name}}';
      final repo = FakePersonnelIntroductionLetterRepository();
      repo.template = PersonnelIntroductionTemplate(
        name: 'tmpl-intro-1',
        canManageTemplate: true,
        revision: 1,
        status: 'Draft',
        clauses: [
          IntroductionLetterClause(id: 'c1', title: 'بند تست', body: body, enabled: true),
        ],
      );
      await tester.pumpWidget(_wrap(
        const PersonnelIntroductionLetterTemplateBuilderPage(company: 'شرکت نمونه'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ویرایش'));
      await tester.pumpAndSettle();

      expect(find.text('فیلد ناشناخته'), findsOneWidget);
      expect(find.text('نام و نام خانوادگی پرسنل'), findsOneWidget);
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
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = FakePersonnelIntroductionLetterRepository();
      await tester.pumpWidget(_wrap(
        const PersonnelIntroductionLetterTemplateBuilderPage(company: 'شرکت نمونه'),
        repo: repo,
        width: 320,
      ));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('ویرایش'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('ویرایش'));
      await tester.pumpAndSettle();

      expect(find.text('نام مرجع دریافت‌کننده'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
