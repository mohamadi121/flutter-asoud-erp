import 'package:asoud_erp/features/roles/domain/role_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ManagedRole completion', () {
    test('missing completion key stays null and is never guessed', () {
      final role = ManagedRole.fromJson({
        'code': 'A',
        'title': 'الف',
        'category': 'C',
        'base_roles': <dynamic>[],
      });
      expect(role.completion, isNull);
      expect(role.needsCompletion, isFalse);
    });

    test('parses complete', () {
      final role = ManagedRole.fromJson({
        'code': 'A',
        'title': 'الف',
        'category': 'C',
        'base_roles': <dynamic>[],
        'completion': 'complete',
      });
      expect(role.completion, 'complete');
      expect(role.needsCompletion, isFalse);
    });

    test('parses incomplete', () {
      final role = ManagedRole.fromJson({
        'code': 'A',
        'title': 'الف',
        'category': 'C',
        'base_roles': ['System Manager'],
        'completion': 'incomplete',
      });
      expect(role.completion, 'incomplete');
      expect(role.needsCompletion, isTrue);
    });

    test('an unknown completion value stays null', () {
      final role = ManagedRole.fromJson({
        'code': 'A',
        'title': 'الف',
        'category': 'C',
        'base_roles': <dynamic>[],
        'completion': 'unknown',
      });
      expect(role.completion, isNull);
      expect(role.needsCompletion, isFalse);
    });
  });

  group('RoleCatalog summary', () {
    test('missing summary: counts computed, incomplete stays null', () {
      final catalog = RoleCatalog.fromJson({
        'categories': [
          {'code': 'FINANCE', 'title': 'مالی', 'style': 'finance'}
        ],
        'roles': [
          {
            'code': 'A',
            'title': 'الف',
            'category': 'FINANCE',
            'base_roles': ['System Manager']
          },
          {
            'code': 'B',
            'title': 'ب',
            'category': 'FINANCE',
            'base_roles': <dynamic>[]
          },
          {
            'code': 'C',
            'title': 'ج',
            'category': '',
            'base_roles': <dynamic>[]
          },
          {
            'code': 'D',
            'title': 'د',
            'category': 'FINANCE',
            'system': true,
            'base_roles': <dynamic>[]
          },
        ],
        'system_roles': [
          {'code': 'SYSTEM_ADMIN', 'title': 'مدیر کل سیستم', 'system': true}
        ],
      });
      expect(catalog.summary.roles, 3);
      expect(catalog.summary.categories, 1);
      expect(catalog.summary.uncategorized, 1);
      expect(catalog.summary.incomplete, isNull);
    });

    test('a role with an unknown category code counts as uncategorized', () {
      final catalog = RoleCatalog.fromJson({
        'categories': [
          {'code': 'FINANCE', 'title': 'مالی', 'style': 'finance'}
        ],
        'roles': [
          {
            'code': 'A',
            'title': 'الف',
            'category': 'FINANCE',
            'base_roles': <dynamic>[]
          },
          {
            'code': 'B',
            'title': 'ب',
            'category': 'UNKNOWN',
            'base_roles': <dynamic>[]
          },
        ],
      });
      expect(catalog.summary.roles, 2);
      expect(catalog.summary.uncategorized, 1);
    });

    test('the server summary is used as-is', () {
      final catalog = RoleCatalog.fromJson({
        'roles': [
          {
            'code': 'A',
            'title': 'الف',
            'category': 'C',
            'base_roles': <dynamic>[]
          }
        ],
        'summary': {
          'roles': 10,
          'categories': 4,
          'incomplete': 2,
          'uncategorized': 1,
        },
      });
      expect(catalog.summary.roles, 10);
      expect(catalog.summary.categories, 4);
      expect(catalog.summary.incomplete, 2);
      expect(catalog.summary.uncategorized, 1);
    });

    test('a server summary without incomplete keeps it null', () {
      final catalog = RoleCatalog.fromJson({
        'summary': {'roles': 1, 'categories': 1, 'uncategorized': 0},
      });
      expect(catalog.summary.incomplete, isNull);
    });

    test('empty catalog: zero counts and null incomplete', () {
      final catalog = RoleCatalog.fromJson(const {});
      expect(catalog.summary.roles, 0);
      expect(catalog.summary.categories, 0);
      expect(catalog.summary.uncategorized, 0);
      expect(catalog.summary.incomplete, isNull);
    });
  });
}
