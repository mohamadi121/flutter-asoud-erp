import 'package:asoud_erp/features/purchase/domain/purchase_request.dart';
import 'package:asoud_erp/features/purchase/domain/purchase_request_repository.dart';
import 'package:asoud_erp/features/purchase/presentation/cubit/purchase_request_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository implements PurchaseRequestRepository {
  String company = '';
  List<PurchaseRequestLine> lines = const [];

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
  }) async {
    this.company = company;
    lines = items;
    return const PurchaseRequestResult(
      name: 'MAT-PRE-0001',
      workflowInstance: 'WFI-0001',
      localOnly: false,
    );
  }
}

void main() {
  test('درخواست بدون قلم کالا ارسال نمی‌شود', () async {
    final repository = _Repository();
    final cubit = PurchaseRequestCubit(repository, 'شرکت نمونه');
    await cubit.load();
    expect(await cubit.submit('خرید کاغذ', DateTime(2026, 8, 20)), isFalse);
    expect(repository.lines, isEmpty);
    await cubit.close();
  });

  test('درخواست معتبر با شرکت و اقلام به مخزن ارسال می‌شود', () async {
    final repository = _Repository();
    final cubit = PurchaseRequestCubit(repository, 'شرکت نمونه');
    await cubit.load();
    cubit.addLine(const PurchaseRequestLine(
      itemCode: 'ITEM-1',
      itemName: 'کاغذ',
      qty: 2,
      uom: 'بسته',
    ));
    expect(await cubit.submit('خرید کاغذ', DateTime(2026, 8, 20)), isTrue);
    expect(repository.company, 'شرکت نمونه');
    expect(repository.lines.single.qty, 2);
    expect(cubit.state.result?.workflowInstance, 'WFI-0001');
    await cubit.close();
  });
}
