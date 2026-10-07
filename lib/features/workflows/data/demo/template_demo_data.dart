/// Demo document templates for the offline preview (no session): three
/// custom templates built from the ready presets, so the template flow can
/// be tried end to end without a server.
///
/// Every map carries `is_sample: true` and is served only in preview while
/// no template was saved on the device; an authenticated session never sees
/// these rows.
library;

import '../offline_preview_data.dart';
import '../../../office_setup/data/demo/office_demo_data.dart';

/// Three custom demo templates derived from the ready presets.
List<Map<String, dynamic>> demoTemplateRows() {
  Map<String, dynamic> preset(String key) =>
      offlinePresets.firstWhere((row) => row['key'] == key);
  Map<String, dynamic> build(
    String key,
    String name,
    String sourceWorkflow,
    Map<String, Map<String, String>> extra,
  ) {
    final base = Map<String, dynamic>.from(preset(key));
    return {
      ...base,
      'is_sample': true,
      'local': true,
      'name': name,
      'kind': 'custom',
      'company': demoCompanyName,
      'status': 'Active',
      'source_workflow': sourceWorkflow,
      'mapping': {
        ...Map<String, dynamic>.from(base['mapping'] as Map),
        for (final entry in extra.entries)
          entry.key: {
            'source': entry.value['source'],
            'value': entry.value['value']
          },
      },
    };
  }

  return [
    build(
      'purchase_expense',
      'LOCAL-DEMO-TPL-PURCHASE',
      'SYS-PURCHASE-WP',
      {
        'amount': {'source': 'request', 'value': 'total'},
        'debit_account': {'source': 'fixed', 'value': 'هزینه خرید - نمونه'},
        'credit_account': {'source': 'fixed', 'value': 'بستانکاران - نمونه'},
        'cost_center': {'source': 'fixed', 'value': 'مرکز هزینه اصلی - نمونه'},
      },
    ),
    build(
      'supplier_payment',
      'LOCAL-DEMO-TPL-SUPPLIER',
      'SYS-PURCHASE-WP',
      {
        'amount': {'source': 'request', 'value': 'total'},
        'debit_account': {'source': 'fixed', 'value': 'بستانکاران - نمونه'},
        'credit_account': {'source': 'fixed', 'value': 'بانک - نمونه'},
      },
    ),
    build(
      'general_expense',
      'LOCAL-DEMO-TPL-GENERAL',
      'DEMO-WF-ADVANCE',
      {
        'amount': {'source': 'request', 'value': 'amount'},
        'debit_account': {
          'source': 'fixed',
          'value': 'هزینه‌های عمومی - نمونه'
        },
        'credit_account': {'source': 'fixed', 'value': 'صندوق - نمونه'},
      },
    ),
  ];
}
