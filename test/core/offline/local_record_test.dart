import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('رکورد محلی همراه با وضعیت همگام‌سازی بازیابی می‌شود', () {
    final createdAt = DateTime.utc(2026, 8, 11, 12);
    final record = LocalRecord(
      id: 'LOCAL-1',
      entityType: 'office',
      payload: const {'office_name': 'دفتر نمونه'},
      status: LocalSyncStatus.pendingSync,
      createdAt: createdAt,
      updatedAt: createdAt,
      lastError: 'network',
    );

    final restored = LocalRecord.fromRow(record.toRow());

    expect(restored.id, record.id);
    expect(restored.entityType, 'office');
    expect(restored.payload, record.payload);
    expect(restored.status, LocalSyncStatus.pendingSync);
    expect(restored.lastError, 'network');
  });

  test('تمام وضعیت‌های همگام‌سازی قابل ذخیره و بازیابی هستند', () {
    for (final status in LocalSyncStatus.values) {
      final now = DateTime.utc(2026, 8, 11);
      final restored = LocalRecord.fromRow(
        LocalRecord(
          id: status.name,
          entityType: 'test',
          payload: const {},
          status: status,
          createdAt: now,
          updatedAt: now,
        ).toRow(),
      );
      expect(restored.status, status);
    }
  });
}
