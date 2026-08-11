import 'purchase_request.dart';

abstract interface class PurchaseRequestRepository {
  Future<List<PurchaseRequestSummary>> list(String company);
  Future<PurchaseRequestOptions> options(String company);
  Future<PurchaseRequestResult> create({
    required String company,
    required String subject,
    required DateTime scheduleDate,
    required List<PurchaseRequestLine> items,
  });
}
