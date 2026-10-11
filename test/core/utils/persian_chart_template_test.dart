import 'package:asoud_erp/core/utils/persian_server_values.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every ERPNext chart template has a Persian label', () {
    expect(persianChartTemplateLabel('Iran Standard'), 'استاندارد ایران');
    expect(persianChartTemplateLabel('Service'), 'خدماتی');
    expect(persianChartTemplateLabel('Commercial'), 'بازرگانی');
    expect(persianChartTemplateLabel('Manufacturing'), 'تولیدی');
  });

  test('normalises separators, case and already-Persian values', () {
    expect(persianChartTemplateLabel('iran-standard'), 'استاندارد ایران');
    expect(persianChartTemplateLabel('  SERVICE '), 'خدماتی');
    expect(persianChartTemplateLabel('تولیدی'), 'تولیدی');
  });

  test('empty values become an empty label and unknown values pass through',
      () {
    expect(persianChartTemplateLabel(null), '');
    expect(persianChartTemplateLabel('   '), '');
    expect(persianChartTemplateLabel('Unmapped'), 'Unmapped');
  });
}
