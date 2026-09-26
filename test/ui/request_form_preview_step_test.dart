import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/utils/jalali_date.dart';
import 'package:asoud_erp/core/widgets/asoud_form.dart';
import 'package:asoud_erp/features/request_types/domain/request_type_catalog.dart';
import 'package:asoud_erp/features/request_types/presentation/cubit/request_type_builder_cubit.dart';
import 'package:asoud_erp/features/request_types/presentation/widgets/request_form_preview_step.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_link_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _UnusedRepository implements WorkflowRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Preview must not call the repository.');
}

const _info = RequestTypeInfo(
    title: 'درخواست خرید', shortTitle: 'خرید کالا', iconKey: 'purchase');
const _fields = [
  WorkflowFormFieldDefinition(
      key: 'subject',
      label: 'موضوع خرید',
      type: 'Short Text',
      required: true,
      helpText: 'موضوع خرید را وارد کنید.'),
  WorkflowFormFieldDefinition(
      key: 'details',
      label: 'جزئیات خرید',
      type: 'Long Text',
      defaultValue: 'توضیحات نمونه'),
  WorkflowFormFieldDefinition(
      key: 'quantity', label: 'تعداد', type: 'Number', defaultValue: '2'),
  WorkflowFormFieldDefinition(
      key: 'amount', label: 'مبلغ', type: 'Currency', defaultValue: '100'),
  WorkflowFormFieldDefinition(
      key: 'date',
      label: 'تاریخ نیاز',
      type: 'Date',
      defaultValue: '2026-09-25'),
  WorkflowFormFieldDefinition(
      key: 'kind',
      label: 'نوع خرید',
      type: 'Choice',
      required: true,
      options: ['کالا', 'خدمت'],
      defaultValue: 'خدمت'),
  WorkflowFormFieldDefinition(
      key: 'tags',
      label: 'برچسب‌ها',
      type: 'Multi Choice',
      required: true,
      options: ['فوری', 'عادی'],
      defaultValue: 'فوری'),
  WorkflowFormFieldDefinition(
      key: 'approved', label: 'تأیید شده', type: 'Checkbox'),
  WorkflowFormFieldDefinition(
      key: 'file', label: 'سند خرید', type: 'Attachment'),
  WorkflowFormFieldDefinition(key: 'user', label: 'کاربر مسئول', type: 'User'),
  WorkflowFormFieldDefinition(
      key: 'department', label: 'واحد مسئول', type: 'Department'),
  WorkflowFormFieldDefinition(
      key: 'items', label: 'اقلام خرید', type: 'Item Table'),
];

Future<RequestTypeBuilderCubit> _pumpPreview(WidgetTester tester,
    {List<WorkflowFormFieldDefinition> fields = _fields}) async {
  final cubit = RequestTypeBuilderCubit(repository: _UnusedRepository())
    ..updateInfo(_info)
    ..setFields(fields);
  addTearDown(cubit.close);
  await tester.pumpWidget(BlocProvider.value(
    value: cubit,
    child: MaterialApp(
      theme: AsoudTheme.light,
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: RequestFormPreviewStep()),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return cubit;
}

Future<void> _validate(WidgetTester tester) async {
  final button = find.text('آزمایش اعتبارسنجی');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('previews every field and validates locally at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cubit = await _pumpPreview(tester);
      final initialState = cubit.state;

      expect(find.text('پیش‌نمایش فرم درخواست'), findsOneWidget);
      expect(
          find.text(
              'فرم ثبت درخواست برای کاربران به این شکل نمایش داده می‌شود. این پیش‌نمایش ذخیره نمی‌شود.'),
          findsOneWidget);
      expect(find.text(_info.title), findsOneWidget);
      expect(find.text(_info.shortTitle), findsOneWidget);
      expect(find.byIcon(requestIconFor(_info.iconKey).icon), findsOneWidget);
      expect(find.text('اطلاعات پایه'), findsOneWidget);
      expect(find.text('اطلاعات اختصاصی'), findsOneWidget);
      for (final label in requestBaseFields) {
        final input = find.widgetWithText(TextFormField, label);
        expect(input, findsOneWidget);
        expect(tester.widget<TextFormField>(input).enabled, isFalse);
      }
      expect(find.text('خودکار'), findsOneWidget);
      expect(find.text('کاربر جاری'), findsOneWidget);
      expect(find.text('در انتظار'), findsOneWidget);
      expect(find.text(formatJalaliIso(DateTime.now().toIso8601String())),
          findsOneWidget);
      for (final field in _fields) {
        expect(find.text('${field.label}${field.required ? ' *' : ''}'),
            findsOneWidget);
      }
      expect(find.text(_fields.first.helpText), findsOneWidget);
      expect(find.text('توضیحات نمونه'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('2026-09-25'), findsOneWidget);
      expect(
          tester
              .widget<TextField>(find.descendant(
                  of: find.widgetWithText(TextFormField, 'جزئیات خرید'),
                  matching: find.byType(TextField)))
              .maxLines,
          3);
      for (final label in ['تعداد', 'مبلغ']) {
        final input = tester.widget<TextField>(find.descendant(
            of: find.widgetWithText(TextFormField, label),
            matching: find.byType(TextField)));
        expect(input.keyboardType, TextInputType.number);
      }
      expect(find.byType(AsoudFormDateField), findsOneWidget);
      final choice = tester.widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>));
      expect(choice.initialValue, 'خدمت');
      expect(find.text('خدمت'), findsWidgets);
      expect(find.byType(RequestMultiChoiceField), findsOneWidget);
      expect(
          tester
              .widget<FilterChip>(find.widgetWithText(FilterChip, 'فوری'))
              .selected,
          isTrue);
      expect(find.byType(RequestLinkField), findsNWidgets(2));
      expect(find.byType(RequestItemTableField), findsOneWidget);
      expect(
          tester
              .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, 'انتخاب فایل'))
              .onPressed,
          isNull);

      await _validate(tester);
      expect(find.text('این فیلد الزامی است.'), findsOneWidget);
      expect(find.text('فرم معتبر است.'), findsNothing);
      final subject = find.widgetWithText(TextFormField, 'موضوع خرید *');
      await tester.ensureVisible(subject);
      await tester.enterText(subject, 'خرید تجهیزات');
      await _validate(tester);
      expect(find.text('این فیلد الزامی است.'), findsNothing);
      expect(find.text('فرم معتبر است.'), findsOneWidget);
      expect(cubit.state, initialState);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shows the empty form message', (tester) async {
    await _pumpPreview(tester, fields: const []);
    expect(
        find.text(
            'فیلد اختصاصی تعریف نشده است؛ فقط فیلدهای پایه نمایش داده می‌شوند.'),
        findsOneWidget);
    await _validate(tester);
    expect(find.text('فرم معتبر است.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
