import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/features/hr/domain/organization_unit_navigation.dart';

void main() {
  final navigation = OrganizationUnitNavigation([
    {'name': 'root', 'department_name': 'ریشه'},
    {
      'name': 'sales',
      'parent_department': 'root',
      'department_name': 'بازاریابی'
    },
    {
      'name': 'other',
      'parent_department': 'root',
      'department_name': 'بازاریابی'
    },
    for (var i = 0; i < 9; i++)
      {'name': 'child$i', 'parent_department': 'sales'},
    {'name': 'deep', 'parent_department': 'child0'},
  ]);
  test('focused path follows IDs, not identical labels', () {
    expect(navigation.path('child0').map((u) => u['name']),
        ['root', 'sales', 'child0']);
    expect(navigation.children('sales').length, 9);
    expect(navigation.children('child0').map((u) => u['name']), ['deep']);
    expect(
        navigation.children('root').map((u) => u['name']), ['sales', 'other']);
  });
  test('four card pages expose every direct child exactly once', () {
    expect(navigation.page('sales', 0).length, 4);
    expect(navigation.page('sales', 1).length, 4);
    expect(navigation.page('sales', 2).map((u) => u['name']), ['child8']);
    expect(navigation.children('deep'), isEmpty);
  });
  test('move exclusions include descendants, never siblings', () {
    expect(
        navigation.subtree('sales'), containsAll(['sales', 'child0', 'deep']));
    expect(navigation.subtree('sales'), isNot(contains('other')));
  });
  test('corrupt cycles cannot hang path construction', () {
    final bad = OrganizationUnitNavigation([
      {'name': 'a', 'parent_department': 'b'},
      {'name': 'b', 'parent_department': 'a'},
    ]);
    expect(bad.path('a').length, 2);
    expect(bad.subtree('a'), {'a', 'b'});
  });
}
