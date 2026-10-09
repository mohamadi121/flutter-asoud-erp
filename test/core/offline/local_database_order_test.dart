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

  setUpAll(() => databaseFactory = databaseFactoryFfi);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    directory = Directory.systemTemp.createTempSync('asoud_local_order_');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('فهرست رکوردها به ترتیب آخرین به‌روزرسانی (جدیدترین اول) است', () async {
    final store = LocalDatabaseStore.forPath(
        path.join(directory.path, 'asoud_erp_local_v1.db'));
    await store.save(id: 'a', entityType: 'office', payload: {'n': 1});
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await store.save(id: 'b', entityType: 'office', payload: {'n': 2});
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await store.save(id: 'c', entityType: 'office', payload: {'n': 3});
    await Future<void>.delayed(const Duration(milliseconds: 5));
    // Editing the oldest row moves it to the front.
    await store.save(
        id: 'a',
        entityType: 'office',
        payload: {'n': 4},
        status: LocalSyncStatus.pendingSync);

    final rows = await store.list(entityType: 'office');

    expect(rows.map((row) => row.id), ['a', 'c', 'b']);
  });
}
