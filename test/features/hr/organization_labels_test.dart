import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/core/utils/organization_labels.dart';
import 'package:asoud_erp/features/hr/domain/organization_chart.dart';
import 'package:asoud_erp/features/hr/domain/organization_templates.dart';

void main() {
  test('known standard labels are Persian and custom names are preserved', () {
    expect(organizationLabel('  HUMAN   RESOURCES '), 'منابع انسانی');
    expect(organizationLabel('All Departments'), 'همهٔ واحدها');
    for (final custom in [
      'Sales - Tehran',
      'My Sales Team',
      'Salesforce',
      'بازاریابی دیجیتال'
    ]) {
      expect(organizationLabel(custom), custom);
    }
  });

  test('display and unchanged editor values never rename raw chart data', () {
    const row = OrgPosition(
        code: 'P1',
        title: 'Sales Manager',
        department: 'Sales',
        departmentId: 'Sales - EX');
    expect(row.displayTitle, 'مدیر فروش');
    expect(row.displayDepartment, 'فروش');
    expect(row.toJson()['title'], 'Sales Manager');
    expect(row.toJson()['department_id'], 'Sales - EX');
    final edited = row.copyWith(
        title: organizationEditedTitle(row.displayTitle, row.title),
        capacity: 2);
    expect(edited.title, row.title);
    expect(edited.capacity, 2);
    expect(organizationEditedTitle('مدیر فروش تهران', row.title),
        'مدیر فروش تهران');
  });

  test('all built-in template position and unit titles are already Persian',
      () {
    for (final template in organizationTemplates) {
      expect(RegExp('[A-Za-z]').hasMatch(template.title), isFalse);
      for (final row in template.positions) {
        expect(RegExp('[A-Za-z]').hasMatch(row.title), isFalse);
        expect(RegExp('[A-Za-z]').hasMatch(row.department), isFalse);
      }
    }
  });
}
