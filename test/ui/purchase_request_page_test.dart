import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/purchase/domain/purchase_request.dart';
import 'package:asoud_erp/features/purchase/domain/purchase_request_repository.dart';
import 'package:asoud_erp/features/purchase/presentation/pages/purchase_request_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository implements PurchaseRequestRepository {
  @override
  Future<List<PurchaseRequestSummary>> list(String company) async => const [];

  @override
  Future<PurchaseRequestOptions> options(String company) async =>
      const PurchaseRequestOptions(items: [
        PurchaseItemOption(code: 'ITEM-1', name: 'کاغذ', uom: 'بسته'),
      ]);

  @override
  Future<PurchaseRequestResult> create({
    required String company,
    required String subject,
    required DateTime scheduleDate,
    required List<PurchaseRequestLine> items,
  }) async =>
      const PurchaseRequestResult(
          name: 'MAT-1', workflowInstance: 'WFI-1', localOnly: false);
}

void main() {
  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets('فرم درخواست خرید در عرض $width بدون overflow است',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        RepositoryProvider<PurchaseRequestRepository>.value(
          value: _Repository(),
          child: MaterialApp(
            theme: AsoudTheme.light,
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: PurchaseRequestPage(company: 'شرکت نمونه'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('درخواست خرید'), findsOneWidget);
      expect(find.text('ثبت و ارسال به گردش‌کار'), findsOneWidget);
    });
  }
}
