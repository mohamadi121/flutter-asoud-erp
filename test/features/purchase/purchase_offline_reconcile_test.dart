import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/purchase/data/frappe_purchase_request_repository.dart';
import 'package:asoud_erp/features/purchase/domain/purchase_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends Mock implements FrappeClient {}

void main() {
  late _Client client;
  late FrappePurchaseRequestRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client = _Client();
    repository = FrappePurchaseRequestRepository(
      client,
      pendingCreates: () async => const [],
    );
  });

  const network = ApiException(
    kind: ApiFailureKind.network,
    message: 'offline',
  );

  List<PurchaseRequestLine> lines() => const [
        PurchaseRequestLine(
          itemCode: 'ITEM-1',
          itemName: 'کاغذ',
          qty: 2,
          uom: 'بسته',
        ),
      ];

  test('offline create shows one pending row; sync leaves exactly one row',
      () async {
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenThrow(network);

    final created = await repository.create(
      company: 'شرکت نمونه',
      subject: 'خرید کاغذ',
      scheduleDate: DateTime(2026, 8, 20),
      items: lines(),
    );
    expect(created.localOnly, isTrue);
    expect(created.name.startsWith('LOCAL-PR-'), isTrue);

    var rows = await repository.list('شرکت نمونه');
    expect(rows, hasLength(1));
    expect(rows.single.localOnly, isTrue);
    expect(rows.single.status, 'در انتظار ارسال');

    // Simulated reconnect: the server accepted the queued mutation and now
    // lists a single server row. The local draft must be gone so the list
    // still has exactly one row and no orphaned LOCAL-PR entry.
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((_) async => [
              {
                'name': 'MAT-PRE-0001',
                'status': 'ثبت‌شده',
                'workflow_instance': 'WFI-0001',
                'schedule_date': '2026-08-20',
              },
            ]);

    rows = await repository.list('شرکت نمونه');
    expect(rows, hasLength(1));
    expect(rows.single.name, 'MAT-PRE-0001');
    expect(rows.single.localOnly, isFalse);

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getStringList('asoud_offline_purchase_requests_v1') ?? [],
      isEmpty,
    );

    rows = await repository.list('شرکت نمونه');
    expect(rows, hasLength(1));
  });
}
