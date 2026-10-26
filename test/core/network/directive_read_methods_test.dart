import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('directive reads are never queued as offline writes', () {
    // The server refuses reads sent through sync.execute_mutation, so the
    // directive detail page showed «عملیات در سرور تکمیل نشد».
    for (final action in ['reports', 'history', 'download_attachment']) {
      expect(FrappeClient.isReadOnlyMethod('asoud_erp.api.v1.directives.$action'),
          isTrue,
          reason: action);
    }
    for (final action in ['issue', 'report', 'review', 'transfer', 'close', 'start']) {
      expect(FrappeClient.isReadOnlyMethod('asoud_erp.api.v1.directives.$action'),
          isFalse,
          reason: action);
    }
  });
}
