import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'local_record.dart';

class LocalDatabaseStore {
  LocalDatabaseStore._();
  static final instance = LocalDatabaseStore._();
  static const _legacyKey = 'asoud_offline_mutations_v1';
  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final root = await getDatabasesPath();
    final database = await openDatabase(
      path.join(root, 'asoud_erp_local_v1.db'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
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
    await _migrateLegacyQueue(database);
    return database;
  }

  Future<LocalRecord> save({
    String? id,
    required String entityType,
    required Map<String, dynamic> payload,
    LocalSyncStatus status = LocalSyncStatus.localOnly,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final recordId = id ?? 'LOCAL-${now.microsecondsSinceEpoch}';
    final old = await get(recordId);
    final record = LocalRecord(
      id: recordId,
      entityType: entityType,
      payload: _safePayload(payload),
      status: status,
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
      remoteId: old?.remoteId,
    );
    await db.insert('local_records', record.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return record;
  }

  Future<LocalRecord?> get(String id) async {
    final rows = await (await database)
        .query('local_records', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : LocalRecord.fromRow(rows.single);
  }

  Future<List<LocalRecord>> list({
    String? entityType,
    Set<LocalSyncStatus>? statuses,
  }) async {
    final clauses = <String>[];
    final arguments = <Object?>[];
    if (entityType != null) {
      clauses.add('entity_type = ?');
      arguments.add(entityType);
    }
    if (statuses != null && statuses.isNotEmpty) {
      clauses.add(
          'sync_status IN (${List.filled(statuses.length, '?').join(',')})');
      arguments.addAll(statuses.map((status) => status.name));
    }
    final rows = await (await database).query(
      'local_records',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: arguments,
      orderBy: 'updated_at DESC',
    );
    return rows.map(LocalRecord.fromRow).toList(growable: false);
  }

  Future<void> setStatus(
    String id,
    LocalSyncStatus status, {
    String? remoteId,
    String? error,
  }) async {
    await (await database).update(
      'local_records',
      {
        'sync_status': status.name,
        'remote_id': remoteId,
        'last_error': error,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(String id) async => (await database)
      .delete('local_records', where: 'id = ?', whereArgs: [id]);

  Future<void> _migrateLegacyQueue(Database db) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_legacyKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;
    await db.transaction((transaction) async {
      for (final value in decoded.whereType<Map>()) {
        final item = Map<String, dynamic>.from(value);
        final now = DateTime.tryParse(item['created_at']?.toString() ?? '') ??
            DateTime.now();
        final record = LocalRecord(
          id: item['id']?.toString() ?? 'LEGACY-${now.microsecondsSinceEpoch}',
          entityType: item['target']?.toString() ?? 'legacy_mutation',
          payload: {
            'operation': item['operation'],
            ...Map<String, dynamic>.from(item['payload'] as Map? ?? const {}),
          },
          status: LocalSyncStatus.pendingSync,
          createdAt: now,
          updatedAt: now,
        );
        await transaction.insert('local_records', record.toRow(),
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
    await preferences.remove(_legacyKey);
  }

  Map<String, dynamic> _safePayload(Map<String, dynamic> payload) {
    final copy = Map<String, dynamic>.from(payload);
    for (final key in copy.keys.toList()) {
      if (key.toLowerCase().contains('password') ||
          key.toLowerCase().contains('secret') ||
          key.toLowerCase().contains('token')) {
        copy.remove(key);
      }
    }
    return copy;
  }
}
