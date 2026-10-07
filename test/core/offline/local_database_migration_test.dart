import 'dart:convert';
import 'dart:io';

import 'package:asoud_erp/core/offline/local_database_store.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late String databasePath;

  setUpAll(() => databaseFactory = databaseFactoryFfi);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    directory = Directory.systemTemp.createTempSync('asoud_local_db_');
    databasePath = path.join(directory.path, 'asoud_erp_local_v1.db');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  /// Creates the database exactly as schema v1 (before the retry columns).
  Future<void> createV1Database({bool withRetryColumns = false}) async {
    final db = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE local_records (
            id TEXT PRIMARY KEY,
            entity_type TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            sync_status TEXT NOT NULL,
            remote_id TEXT,
            last_error TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
            ${withRetryColumns ? ', attempts INTEGER NOT NULL DEFAULT 0, next_attempt_at TEXT' : ''}
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_local_records_type ON local_records(entity_type)',
        );
        await db.execute(
          'CREATE INDEX idx_local_records_sync ON local_records(sync_status)',
        );
      },
    );
    await db.insert('local_records', {
      'id': 'OLD-1',
      'entity_type': 'office',
      'payload_json': jsonEncode({'office_name': 'دفتر قدیمی'}),
      'sync_status': 'pendingSync',
      'remote_id': null,
      'last_error': null,
      'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
      'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
    });
    await db.close();
  }

  Future<Set<Object?>> columnsOf(LocalDatabaseStore store) async {
    final db = await store.database;
    final info = await db.rawQuery('PRAGMA table_info(local_records)');
    return info.map((column) => column['name']).toSet();
  }

  for (final withRetryColumns in [false, true]) {
    test(
        'پایگاه داده نسخه 1 ${withRetryColumns ? 'با ستون‌های موجود ' : ''}'
        'به نسخه 2 ارتقا می‌یابد', () async {
      await createV1Database(withRetryColumns: withRetryColumns);

      final store = LocalDatabaseStore.forPath(databasePath);
      final db = await store.database;

      expect(await db.getVersion(), 2);
      expect(
          await columnsOf(store), containsAll(['attempts', 'next_attempt_at']));

      final old = await store.get('OLD-1');
      expect(old, isNotNull);
      expect(old!.attempts, 0);
      expect(old.nextAttemptAt, isNull);
      expect(old.payload, {'office_name': 'دفتر قدیمی'});

      final retryAt = DateTime.utc(2026, 8, 11, 12);
      await store.setStatus(
        'OLD-1',
        LocalSyncStatus.syncFailed,
        error: 'network',
        attempts: 1,
        nextAttemptAt: retryAt,
      );
      final updated = await store.get('OLD-1');
      expect(updated!.status, LocalSyncStatus.syncFailed);
      expect(updated.attempts, 1);
      expect(updated.nextAttemptAt, retryAt);

      final saved = await store.save(
        entityType: 'office',
        payload: const {'office_name': 'جدید'},
        attempts: 2,
      );
      expect((await store.get(saved.id))!.attempts, 2);
      await db.close();
    });
  }

  test('صف قدیمی SharedPreferences پس از ارتقا منتقل می‌شود', () async {
    await createV1Database();
    SharedPreferences.setMockInitialValues({
      'asoud_offline_mutations_v1': jsonEncode([
        {
          'id': 'LEGACY-1',
          'target': 'party',
          'operation': 'create',
          'payload': {'name': 'x'},
          'created_at': DateTime.utc(2026, 2, 2).toIso8601String(),
        },
      ]),
    });

    final store = LocalDatabaseStore.forPath(databasePath);
    final legacy = await store.get('LEGACY-1');

    expect(legacy, isNotNull);
    expect(legacy!.status, LocalSyncStatus.pendingSync);
    expect(legacy.attempts, 0);
    expect(legacy.nextAttemptAt, isNull);
    expect(await store.get('OLD-1'), isNotNull);
    expect(
      (await SharedPreferences.getInstance())
          .getString('asoud_offline_mutations_v1'),
      isNull,
    );
    await (await store.database).close();
  });

  test('پایگاه داده تازه مستقیم با نسخه 2 ساخته می‌شود', () async {
    final store = LocalDatabaseStore.forPath(databasePath);
    final db = await store.database;

    expect(await db.getVersion(), 2);
    expect(
        await columnsOf(store), containsAll(['attempts', 'next_attempt_at']));
    await db.close();
  });
}
