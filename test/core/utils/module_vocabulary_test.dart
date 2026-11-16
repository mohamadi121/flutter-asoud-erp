import 'package:asoud_erp/core/utils/module_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeModuleKey', () {
    test('canonical keys resolve to themselves', () {
      for (final key in moduleKeys) {
        expect(normalizeModuleKey(key), key);
      }
    });

    test('legacy workflow keys resolve to their canonical key', () {
      expect(normalizeModuleKey('Accounting'), 'Finance');
      expect(normalizeModuleKey('Sales'), 'Selling');
      expect(normalizeModuleKey('Inventory'), 'Stock');
      expect(normalizeModuleKey('Support'), 'Admin');
    });

    test('empty, null and unknown keys are not modules', () {
      expect(normalizeModuleKey(''), isNull);
      expect(normalizeModuleKey(null), isNull);
      expect(normalizeModuleKey('Administration'), isNull);
      expect(normalizeModuleKey('General'), isNull);
    });
  });

  group('moduleLabel', () {
    test('canonical keys show their Persian label', () {
      expect(moduleLabel('Finance'), 'مالی');
      expect(moduleLabel('Purchase'), 'خرید');
      expect(moduleLabel('Selling'), 'فروش');
      expect(moduleLabel('Stock'), 'انبار');
      expect(moduleLabel('HR'), 'منابع انسانی');
      expect(moduleLabel('Admin'), 'خدمات اداری');
      expect(moduleLabel('IT'), 'IT و تجهیزات');
    });

    test('legacy keys show the canonical Persian label', () {
      expect(moduleLabel('Accounting'), 'مالی');
      expect(moduleLabel('Sales'), 'فروش');
      expect(moduleLabel('Inventory'), 'انبار');
      expect(moduleLabel('Support'), 'خدمات اداری');
    });

    test('empty and unknown keys never leak a raw English id', () {
      expect(moduleLabel(''), isEmpty);
      expect(moduleLabel(null), isEmpty);
      expect(moduleLabel('Administration'), 'سایر');
      expect(moduleLabel('General'), 'سایر');
    });
  });
}
