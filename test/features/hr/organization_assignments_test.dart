import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/features/hr/domain/organization_chart.dart';

void main() {
  test('position edit and move preserve occupants, unit id and history', () {
    final original = OrgPosition.fromJson({
      'code': 'P',
      'title': 'Title',
      'department_id': 'D',
      'occupants': ['employee:A', 'employee:B'],
      'capacity': 2,
      'duties': 'duties',
      'assignment_history': [
        {'employee': 'employee:A', 'started_at': null}
      ],
    });
    final moved = original.copyWith(parent: 'ROOT', title: 'Edited');
    expect(moved.departmentId, 'D');
    expect(moved.activeEmployees, ['employee:A', 'employee:B']);
    expect(moved.history, original.history);
    expect(OrgPosition.fromJson(moved.toJson()).duties, 'duties');
  });
  test('capacity cannot be lower than active occupants', () {
    expect(
        () => validateOrganization([
              const OrgPosition(code: 'P', title: 'P', occupants: ['A', 'B']),
            ]),
        throwsFormatException);
  });
  test('legacy occupant remains visible without inventing assignment dates',
      () {
    final position = OrgPosition.fromJson(
        {'code': 'P', 'title': 'P', 'employee': 'employee:A'});
    expect(position.activeEmployees, ['employee:A']);
    expect(position.history, isEmpty);
  });
}
