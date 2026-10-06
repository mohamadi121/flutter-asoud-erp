import 'dart:io';

import 'package:asoud_erp/core/offline/local_database_store.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('migrates a v1 local_records database to retry columns', () async {
    final directory = await Directory.systemTemp.createTemp('asoud-local-db-');
    addTearDown(() => directory.delete(recursive: true));
    final databasePath = '${directory.path}/asoud_erp_local_v1.db';

    final oldDatabase = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (database, _) async {
        await database.execute('''
          CREATE TABLE local_records (
            id TEXT PRIMARY KEY,
            entity_type TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            sync_status TEXT NOT NULL,
            remote_id TEXT,
            last_error TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await database.execute(
          'CREATE INDEX idx_local_records_type ON local_records(entity_type)',
        );
        await database.execute(
          'CREATE INDEX idx_local_records_sync ON local_records(sync_status)',
        );
      },
    );
    await oldDatabase.insert('local_records', {
      'id': 'old-1',
      'entity_type': 'purchase_request',
      'payload_json': '{"name":"old"}',
      'sync_status': LocalSyncStatus.pendingSync.name,
      'created_at': '2026-10-06T00:00:00.000',
      'updated_at': '2026-10-06T00:00:00.000',
    });
    await oldDatabase.close();

    final store = LocalDatabaseStore.forPath(databasePath);
    addTearDown(() async => (await store.database).close());

    final migrated = await store.get('old-1');
    expect(migrated, isNotNull);
    expect(migrated!.attempts, 0);
    expect(migrated.nextAttemptAt, isNull);

    final nextAttempt = DateTime.utc(2026, 10, 6, 12);
    await store.setStatus(
      'old-1',
      LocalSyncStatus.pendingSync,
      attempts: 2,
      nextAttemptAt: nextAttempt,
    );
    final updated = await store.get('old-1');
    expect(updated!.attempts, 2);
    expect(updated.nextAttemptAt, nextAttempt);

    await store.save(
      entityType: 'purchase_request',
      payload: {'name': 'new'},
      status: LocalSyncStatus.pendingSync,
      attempts: 1,
      nextAttemptAt: nextAttempt,
    );
    final rows = await store.list(statuses: {LocalSyncStatus.pendingSync});
    expect(rows, hasLength(2));
  });
}
