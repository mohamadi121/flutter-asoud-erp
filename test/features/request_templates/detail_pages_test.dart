import 'package:asoud_erp/features/request_templates/request_templates.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_attachments.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(900, 4200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(wrapPage(page));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'purchase detail: info, items table with thumbnails, files, '
      'comments and buttons', (tester) async {
    final repository = FakeRequestRepository();
    await _pump(
        tester,
        PurchaseRequestDetailPage(
            repository: repository, name: 'PR-1404-0023'));
    expect(find.text('جزئیات درخواست خرید'), findsOneWidget);
    expect(find.text('PR-1404-0023'), findsOneWidget);
    expect(find.text('ارسال شده'), findsWidgets);
    expect(find.text('خرید تجهیزات پزشکی بخش ICU'), findsOneWidget);
    // The main info card with its icon rows and the resolved labels.
    expect(find.text('اطلاعات اصلی'), findsOneWidget);
    for (final text in [
      'درخواست‌کننده',
      'علی محمدی',
      'واحد سازمانی',
      'بخش ICU',
      'مرکز هزینه',
      'تجهیزات پزشکی',
      'پروژه',
      'توسعه بخش ICU',
      'تاریخ مورد نیاز',
      'اولویت',
      'دلیل درخواست',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(find.byKey(const ValueKey('priority-chip')), findsOneWidget);
    expect(find.text('مهم'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    // 20 days after 2026-10-06 is 2026-10-20, shown as 1405/07/28.
    expect(find.text('۱۴۰۵/۰۷/۲۸'), findsOneWidget);
    // Items table: three rows, a thumbnail for the row with a file.
    expect(find.text('اقلام درخواست (۳ قلم)'), findsOneWidget);
    expect(find.text('مانیتور بیمارستانی مدل XS'), findsOneWidget);
    expect(find.text('سنسور اکسیژن SpO2'), findsOneWidget);
    expect(find.text('کابل اتصال ۵ متری'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(Table),
            matching: find.byType(RequestAttachmentThumbnail)),
        findsOneWidget);
    // General files only (the row image is not listed there).
    expect(find.text('پیوست‌ها (۱ فایل)'), findsOneWidget);
    expect(find.text('لیست مشخصات فنی.pdf'), findsOneWidget);
    expect(find.byType(RequestAttachmentTile), findsOneWidget);
    // Comments and the bottom buttons.
    expect(find.text('نظرات'), findsOneWidget);
    expect(find.textContaining('مشخصات فنی پیوست شد'), findsOneWidget);
    expect(find.text('کپی لینک'), findsOneWidget);
    expect(find.text('ویرایش'), findsOneWidget);
  });

  testWidgets('copy link puts asoud://request/<name> on the clipboard',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await _pump(
        tester,
        PurchaseRequestDetailPage(
            repository: FakeRequestRepository(), name: 'PR-1404-0023'));
    await tester.tap(find.text('کپی لینک'));
    await tester.pump();
    expect(copied, 'asoud://request/PR-1404-0023');
  });

  testWidgets('supply detail shows the visible «انصراف درخواست» button',
      (tester) async {
    final repository = FakeRequestRepository();
    await _pump(tester,
        SupplyRequestDetailPage(repository: repository, name: 'SP-1404-0007'));
    expect(find.text('جزئیات درخواست تأمین'), findsOneWidget);
    expect(find.text('محل تحویل'), findsOneWidget);
    expect(find.text('روش تأمین پیشنهادی'), findsOneWidget);
    expect(find.text('تأمین‌کننده پیشنهادی'), findsOneWidget);
    expect(find.text('نوید طب'), findsOneWidget);
    expect(find.text('اقلام درخواست (۳ قلم)'), findsOneWidget);
    expect(find.text('انصراف درخواست'), findsOneWidget);
    expect(find.text('ویرایش'), findsOneWidget);
    await tester.tap(find.text('انصراف درخواست'));
    await tester.pumpAndSettle();
    // The shared reason dialog opens.
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('a finished supply request has no cancel or edit button',
      (tester) async {
    await _pump(
        tester,
        SupplyRequestDetailPage(
            repository: FakeRequestRepository(), name: 'SP-1404-0006'));
    expect(find.text('انصراف درخواست'), findsNothing);
    expect(find.text('ویرایش'), findsNothing);
    expect(find.text('کپی لینک'), findsOneWidget);
    expect(find.text('تأیید شده'), findsWidgets);
  });

  testWidgets('daily leave detail', (tester) async {
    await _pump(
        tester,
        LeaveRequestDetailPage(
            repository: FakeRequestRepository(), name: 'LV-1404-0042'));
    expect(find.text('جزئیات درخواست مرخصی'), findsOneWidget);
    expect(find.text('LV-1404-0042'), findsOneWidget);
    expect(find.text('مرخصی سالانه (روزانه)'), findsOneWidget);
    expect(find.text('تأیید شده'), findsWidgets);
    expect(find.text('اطلاعات درخواست'), findsOneWidget);
    for (final text in [
      'نوع مرخصی',
      'سالانه',
      'نوع درخواست',
      'روزانه',
      'تاریخ شروع',
      'تاریخ پایان',
      'مدت مرخصی',
      '۳ روز',
      'محل خدمت',
      'تهران',
      'دلیل مرخصی',
      'سفر شخصی به همراه خانواده',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(find.text('ساعت شروع'), findsNothing);
    expect(find.text('تاریخ مرخصی'), findsNothing);
    // No files: the empty hint of the mockup.
    expect(find.text('فایلی وجود ندارد.'), findsOneWidget);
  });

  testWidgets('hourly leave detail shows the date, the times and the file',
      (tester) async {
    await _pump(
        tester,
        LeaveRequestDetailPage(
            repository: FakeRequestRepository(), name: 'LV-1404-0041'));
    expect(find.text('مرخصی استعلاجی (ساعتی)'), findsOneWidget);
    expect(find.text('ساعتی'), findsOneWidget);
    expect(find.text('تاریخ مرخصی'), findsOneWidget);
    expect(find.text('ساعت شروع'), findsOneWidget);
    expect(find.text('۱۰:۰۰'), findsOneWidget);
    expect(find.text('ساعت پایان'), findsOneWidget);
    expect(find.text('۱۴:۰۰'), findsOneWidget);
    expect(find.text('۴ ساعت'), findsOneWidget);
    expect(find.text('تاریخ شروع'), findsNothing);
    expect(find.text('پیوست‌ها (۱ فایل)'), findsOneWidget);
    expect(find.text('برگه وقت پزشک.pdf'), findsOneWidget);
  });

  testWidgets('a rejected leave shows the reason and no action buttons',
      (tester) async {
    await _pump(
        tester,
        LeaveRequestDetailPage(
            repository: FakeRequestRepository(), name: 'LV-1404-0040'));
    expect(find.text('رد شده'), findsWidgets);
    expect(find.text('دلیل رد: به دلیل مدارک ناقص'), findsOneWidget);
    expect(find.text('انصراف درخواست'), findsNothing);
    expect(find.text('ویرایش'), findsNothing);
  });
}
