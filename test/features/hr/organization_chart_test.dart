import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/hr/data/organization_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/features/hr/domain/organization_chart.dart';
import 'package:mocktail/mocktail.dart';

class _PreviewClient extends Mock implements FrappeApiClient {}

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
  test('offline preview loads the seeded organization chart', () async {
    final client = _PreviewClient();
    when(() => client.isAuthenticated).thenReturn(false);
    when(() => client.authenticationChanges)
        .thenAnswer((_) => const Stream.empty());
    final repository = OrganizationRepository(client);
    addTearDown(repository.dispose);

    final snapshot = await repository.load('شرکت نمونه آسود');

    expect(snapshot.rows, hasLength(standardOrganization.length));
    expect(snapshot.rows.first.title, 'مدیرعامل');
    expect(snapshot.pending, isFalse);
  });
}
