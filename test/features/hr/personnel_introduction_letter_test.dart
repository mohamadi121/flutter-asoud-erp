import 'package:asoud_erp/features/hr/data/personnel_introduction_letter_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_introduction_letter_form_page.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_introduction_letter_preview_page.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_introduction_letter_template_builder_page.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_introduction_letters_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapWithRtl(Widget child, {PersonnelIntroductionLetterRepository? repo, double width = 390}) {
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

class _RetryFinalizationRepository extends FakePersonnelIntroductionLetterRepository {
  final keys = <String>[];

  @override
  Future<PersonnelIntroductionLetterDetail> finalizeLetter({
    required String name,
    required int revision,
    required String requestKey,
  }) async {
    keys.add(requestKey);
    throw Exception('connection lost');
  }
}

class _OperationalRepository extends FakePersonnelIntroductionLetterRepository {
  @override
  Future<PersonnelIntroductionTemplate> getTemplate({required String company}) async =>
      PersonnelIntroductionTemplate.fromMap({
        'name': 'template', 'revision': 1, 'status': 'Published',
        'clauses': <Map<String, dynamic>>[],
      });
}

class _PendingWorkflowRepository extends FakePersonnelIntroductionLetterRepository {
  PersonnelIntroductionLetterDetail _detail(String status) => PersonnelIntroductionLetterDetail.fromMap({
    'name': 'INTRO-DRAFT-1', 'id': 'INTRO-DRAFT-1', 'company': 'شرکت نمونه',
    'employee': 'HR-EMP-1', 'employee_name': 'نام پرسنل', 'employee_number': '125',
    'recipient_type': 'bank', 'recipient_name': '', 'bank_name': 'بانک ملت', 'branch_name': '',
    'recipient_text': 'بانک ملت', 'purpose': 'افتتاح حساب', 'validity_date': '', 'notes': '',
    'number': '—', 'issue_date': '—', 'revision': status == 'Draft' ? 1 : 2, 'template_version': 1,
    'status': status, 'rendered_html': '<article>متن معرفی‌نامه</article>',
    'print_html': '<article>پیش‌نویس ـ فاقد اعتبار نهایی</article>',
    'values_snapshot': <String, dynamic>{}, 'template_snapshot': <String, dynamic>{},
    if (status == 'Pending') 'workflow_request': 'REQ-1',
    if (status == 'Pending') 'workflow_instance': 'INSTANCE-1',
  });

  @override
  Future<PersonnelIntroductionLetterDetail> getLetter({required String name}) async => _detail('Draft');

  @override
  Future<PersonnelIntroductionLetterDetail> finalizeLetter({
    required String name, required int revision, required String requestKey,
  }) async => _detail('Pending');
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('workflow submission remains pending without another issue action at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrapWithRtl(
        const PersonnelIntroductionLetterPreviewPage(letterName: 'INTRO-DRAFT-1', company: 'شرکت نمونه'),
        repo: _PendingWorkflowRepository(), width: width,
      ));
      await tester.pumpAndSettle();
      final issue = find.text('صدور نهایی معرفی‌نامه');
      await tester.ensureVisible(issue);
      await tester.tap(issue);
      await tester.pumpAndSettle();
      expect(find.text('معرفی‌نامه برای بررسی به گردش کار ارسال شد.'), findsOneWidget);
      expect(find.text('در جریان'), findsOneWidget);
      expect(find.text('صدور نهایی معرفی‌نامه'), findsNothing);
      expect(find.text('معرفی‌نامه با موفقیت صادر و نهایی گردید.'), findsNothing);
      expect(find.text('INTRO-DRAFT-1'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('template retains the chosen existing workflow at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = FakePersonnelIntroductionLetterRepository();
      repo.template = PersonnelIntroductionTemplate.fromMap({
        ...repo.template.toMap(), 'workflow': 'WF-INTRO',
        'workflow_options': [{'name': 'WF-INTRO', 'title': 'بررسی معرفی‌نامه'}],
      });
      await tester.pumpWidget(_wrapWithRtl(
        const PersonnelIntroductionLetterTemplateBuilderPage(company: 'شرکت نمونه'), repo: repo, width: width,
      ));
      await tester.pumpAndSettle();
      final selector = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(selector);
      expect(find.text('بررسی معرفی‌نامه'), findsOneWidget);
      expect(find.text('WF-INTRO'), findsNothing);
      expect(tester.widget<DropdownButtonFormField<String>>(selector).initialValue, 'WF-INTRO');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('printing sends the exact server print payload', (tester) async {
    const channel = MethodChannel('net.nfet.printing');
    String? receivedHtml;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'convertHtml') {
        receivedHtml = (call.arguments as Map)['html'] as String;
        throw PlatformException(code: 'unavailable');
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    final repo = FakePersonnelIntroductionLetterRepository();
    final server = await repo.getLetter(name: 'INTRO-DRAFT-1');
    await tester.pumpWidget(_wrapWithRtl(
      const PersonnelIntroductionLetterPreviewPage(
        letterName: 'INTRO-DRAFT-1', company: 'شرکت نمونه',
      ), repo: repo,
    ));
    await tester.pumpAndSettle();
    final printButton = find.text('چاپ / ذخیره سند');
    await tester.ensureVisible(printButton);
    await tester.tap(printButton);
    await tester.pumpAndSettle();
    expect(receivedHtml, server.printHtml);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('operational user has no template entry points at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrapWithRtl(
        const PersonnelIntroductionLettersPage(company: 'شرکت نمونه'),
        repo: _OperationalRepository(), width: width,
      ));
      await tester.pumpAndSettle();
      expect(find.text('ویرایش قالب'), findsNothing);
      expect(find.byTooltip('ویرایش قالب'), findsNothing);
      expect(find.text('＋ معرفی‌نامه جدید'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  group('PersonnelIntroductionLetter models', () {
    test('Template and clauses serialization roundtrip', () {
      final jsonMap = {
        'name': 'tmpl-intro-1',
        'revision': 2,
        'status': 'Published',
        'required_recipient': true,
        'required_purpose': true,
        'has_expiry': false,
        'clauses': [
          {'id': 'c1', 'title': 'بند ۱', 'body': 'متن ۱', 'enabled': true},
        ],
      };
      final tmpl = PersonnelIntroductionTemplate.fromMap(jsonMap);
      expect(tmpl.name, 'tmpl-intro-1');
      expect(tmpl.revision, 2);
      expect(tmpl.status, 'Published');
      expect(tmpl.requiredRecipient, isTrue);
      expect(tmpl.requiredPurpose, isTrue);
      expect(tmpl.hasExpiry, isFalse);
      expect(tmpl.clauses.first.id, 'c1');
      expect(tmpl.clauses.first.title, 'بند ۱');

      final serialized = tmpl.toMap();
      expect(serialized['required_recipient'], true);
      expect((serialized['clauses'] as List).length, 1);
    });

    test('Detail serialization and status labels', () {
      final detail = PersonnelIntroductionLetterDetail.fromMap({
        'name': 'INTRO-1',
        'id': 'INTRO-1',
        'company': 'شرکت الف',
        'employee': 'EMP-1',
        'employee_name': 'رضا باقری',
        'employee_number': 'EMP-1',
        'number': '۱۴۰۵-۰۲',
        'recipient_type': 'bank',
        'recipient_name': '',
        'bank_name': 'بانک سپه',
        'branch_name': 'مرکزی',
        'recipient_text': 'بانک سپه ـ شعبه مرکزی',
        'purpose': 'افتتاح حساب',
        'validity_date': '',
        'notes': '',
        'status': 'Final',
        'revision': 1,
        'template_version': 1,
        'rendered_html': '<p>متن</p>',
        'print_html': '<p>چاپ</p>',
        'issue_date': '۱۴۰۵/۰۲/۰۱',
      });
      expect(detail.employeeName, 'رضا باقری');
      expect(detail.statusLabel, 'نهایی');
      expect(detail.isFinal, isTrue);
      expect(detail.recipientText, 'بانک سپه ـ شعبه مرکزی');
    });
  });

  group('PersonnelIntroductionLettersPage UI', () {
    for (final width in [320.0, 390.0, 430.0]) {
      testWidgets('renders list and filter at width $width without overflow', (tester) async {
        final repo = FakePersonnelIntroductionLetterRepository();
        await tester.pumpWidget(_wrapWithRtl(
          const PersonnelIntroductionLettersPage(company: 'شرکت نمونه'),
          repo: repo,
          width: width,
        ));
        await tester.pumpAndSettle();

        expect(find.text('معرفی‌نامه‌های پرسنلی'), findsOneWidget);
        expect(find.text('＋ معرفی‌نامه جدید'), findsOneWidget);
        expect(find.text('ویرایش قالب'), findsWidgets);
        expect(find.text('معرفی‌نامه ـ علی محمدی'), findsOneWidget);
        expect(find.text('معرفی‌نامه ـ سارا احمدی'), findsOneWidget);
      });
    }

    testWidgets('filtering by search updates visible list', (tester) async {
      final repo = FakePersonnelIntroductionLetterRepository();
      await tester.pumpWidget(_wrapWithRtl(
        const PersonnelIntroductionLettersPage(company: 'شرکت نمونه'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'سارا');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('معرفی‌نامه ـ سارا احمدی'), findsOneWidget);
      expect(find.text('معرفی‌نامه ـ علی محمدی'), findsNothing);
    });
  });

  group('PersonnelIntroductionLetterFormPage UI', () {
    for (final width in [320.0, 390.0, 430.0]) {
      testWidgets('renders form fields at width $width without overflow', (tester) async {
        final repo = FakePersonnelIntroductionLetterRepository();
        await tester.pumpWidget(_wrapWithRtl(
          const PersonnelIntroductionLetterFormPage(company: 'شرکت نمونه'),
          repo: repo,
          width: width,
        ));
        await tester.pumpAndSettle();

        expect(find.text('صدور معرفی‌نامه پرسنل'), findsOneWidget);
        expect(find.text('۱. مشخصات پرسنل'), findsOneWidget);
        expect(find.text('۲. مخاطب معرفی‌نامه'), findsOneWidget);
        expect(find.text('ذخیره پیش‌نویس'), findsOneWidget);
      });
    }

    testWidgets('toggling recipient type changes fields', (tester) async {
      final repo = FakePersonnelIntroductionLetterRepository();
      await tester.pumpWidget(_wrapWithRtl(
        const PersonnelIntroductionLetterFormPage(company: 'شرکت نمونه'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('نام بانک *'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('سازمان / اداره').last);
      await tester.pumpAndSettle();

      expect(find.text('نام مرجع دریافت‌کننده *'), findsOneWidget);
    });
  });

  testWidgets('finalization retries reuse the form request key', (tester) async {
    final repo = _RetryFinalizationRepository();
    await tester.pumpWidget(_wrapWithRtl(
      const PersonnelIntroductionLetterPreviewPage(
        letterName: 'INTRO-DRAFT-1', company: 'شرکت نمونه',
      ),
      repo: repo,
    ));
    await tester.pumpAndSettle();
    final button = find.text('صدور نهایی معرفی‌نامه');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(repo.keys, hasLength(2));
    expect(repo.keys.last, repo.keys.first);
  });

  group('PersonnelIntroductionLetterPreviewPage UI', () {
    for (final width in [320.0, 390.0, 430.0]) {
      testWidgets('renders preview at width $width without overflow', (tester) async {
        final repo = FakePersonnelIntroductionLetterRepository();
        await tester.pumpWidget(_wrapWithRtl(
          const PersonnelIntroductionLetterPreviewPage(
            letterName: 'INTRO-DRAFT-1',
            company: 'شرکت نمونه',
          ),
          repo: repo,
          width: width,
        ));
        await tester.pumpAndSettle();

        expect(find.text('پیش‌نمایش معرفی‌نامه'), findsOneWidget);
        expect(find.text('معرفی‌نامه پرسنل'), findsOneWidget);
        expect(find.text('پیش‌نویس ـ فاقد اعتبار نهایی'), findsOneWidget);
        expect(find.text('صدور نهایی معرفی‌نامه'), findsOneWidget);
      });
    }
  });

  group('PersonnelIntroductionLetterTemplateBuilderPage UI', () {
    for (final width in [320.0, 390.0, 430.0]) {
      testWidgets('renders template builder at width $width without overflow', (tester) async {
        final repo = FakePersonnelIntroductionLetterRepository();
        await tester.pumpWidget(_wrapWithRtl(
          const PersonnelIntroductionLetterTemplateBuilderPage(company: 'شرکت نمونه'),
          repo: repo,
          width: width,
        ));
        await tester.pumpAndSettle();

        expect(find.text('قالب معرفی‌نامه پرسنل'), findsOneWidget);
        expect(find.text('ویرایش قالب'), findsOneWidget);
        expect(find.text('پیش‌نمایش سند'), findsOneWidget);
        expect(find.text('تنظیمات قالب معرفی‌نامه'), findsOneWidget);
        expect(find.text('بندهای متن معرفی‌نامه'), findsOneWidget);
      });
    }

    testWidgets('switches to preview tab', (tester) async {
      final repo = FakePersonnelIntroductionLetterRepository();
      await tester.pumpWidget(_wrapWithRtl(
        const PersonnelIntroductionLetterTemplateBuilderPage(company: 'شرکت نمونه'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('پیش‌نمایش سند'));
      await tester.pumpAndSettle();

      expect(find.text('اطلاعات نمونه برای پیش‌نمایش سند'), findsOneWidget);
      expect(find.text('معرفی‌نامه پرسنل'), findsOneWidget);
      expect(find.text('چاپ / ذخیره PDF پیش‌نمایش'), findsOneWidget);
    });
  });
}
