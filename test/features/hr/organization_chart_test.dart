import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/features/hr/domain/organization_chart.dart';

void main() {
  test('template permits vacant positions', () {
    expect(() => validateOrganization(standardOrganization), returnsNormally);
  });
  test('rejects cycles, absent parents and duplicate assignments', () {
    for (final rows in [
      [const OrgPosition(code: 'A', title: 'A', parent: 'A')],
      [
        const OrgPosition(code: 'A', title: 'A', parent: 'B'),
        const OrgPosition(code: 'B', title: 'B', parent: 'A')
      ],
      [const OrgPosition(code: 'A', title: 'A', parent: 'missing')],
      [
        const OrgPosition(code: 'A', title: 'A'),
        const OrgPosition(code: 'A', title: 'Other')
      ],
      [
        const OrgPosition(code: 'A', title: 'A', employee: 'E'),
        const OrgPosition(code: 'B', title: 'B', employee: 'E')
      ],
    ]) {
      expect(() => validateOrganization(rows), throwsFormatException);
    }
  });
  test('preserves hierarchy and assignment on serialization', () {
    const row = OrgPosition(
        code: 'ACC',
        title: 'حسابدار',
        parent: 'FIN',
        department: 'مالی',
        employee: 'E');
    final decoded = OrgPosition.fromJson(row.toJson());
    expect(decoded.toJson(), row.toJson());
  });
}
