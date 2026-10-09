import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'local_record.dart';

abstract interface class LocalRecordStore {
  Future<LocalRecord> save({
    String? id,
    required String entityType,
    required Map<String, dynamic> payload,
    LocalSyncStatus status = LocalSyncStatus.localOnly,
    int? attempts,
    DateTime? nextAttemptAt,
  });

  Future<LocalRecord?> get(String id);

  Future<List<LocalRecord>> list({
    String? entityType,
    Set<LocalSyncStatus>? statuses,
  });

  /// Stores the new [status]. [attempts] and [nextAttemptAt] carry the retry
  /// schedule of a queued write: a null [attempts] keeps the stored count and a
  /// null [nextAttemptAt] clears the deadline, so the row is due immediately.
  Future<void> setStatus(
    String id,
    LocalSyncStatus status, {
    String? remoteId,
    String? error,
    int? attempts,
    DateTime? nextAttemptAt,
  });

  Future<void> delete(String id);
}

class LocalDatabaseStore implements LocalRecordStore {
  LocalDatabaseStore._([this._databasePath]);

  /// A store backed by the database file at [databasePath], so tests can open
  /// a database that already exists on disk.
  @visibleForTesting
  factory LocalDatabaseStore.forPath(String databasePath) =>
      LocalDatabaseStore._(databasePath);

  static final instance = LocalDatabaseStore._();
  static const _legacyKey = 'asoud_offline_mutations_v1';
  static const _schemaVersion = 2;
  final String? _databasePath;
  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final databasePath = _databasePath ??
        path.join(await getDatabasesPath(), 'asoud_erp_local_v1.db');
    final database = await openDatabase(
      databasePath,
      version: _schemaVersion,
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
            updated_at TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            next_attempt_at TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_local_records_type ON local_records(entity_type)',
        );
        await db.execute(
          'CREATE INDEX idx_local_records_sync ON local_records(sync_status)',
        );
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) await _addRetryColumns(db);
      },
    );
    await _migrateLegacyQueue(database);
    return database;
  }

  /// Adds the retry-schedule columns to a table created before schema v2. Only
  /// missing columns are added, because a build may already have them while
  /// still reporting version 1.
  Future<void> _addRetryColumns(Database db) async {
    final columns = (await db.rawQuery('PRAGMA table_info(local_records)'))
        .map((column) => column['name'])
        .toSet();
    if (!columns.contains('attempts')) {
      await db.execute(
        'ALTER TABLE local_records '
        'ADD COLUMN attempts INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!columns.contains('next_attempt_at')) {
      await db.execute(
        'ALTER TABLE local_records ADD COLUMN next_attempt_at TEXT',
      );
    }
  }

  @override
  Future<LocalRecord> save({
    String? id,
    required String entityType,
    required Map<String, dynamic> payload,
    LocalSyncStatus status = LocalSyncStatus.localOnly,
    int? attempts,
    DateTime? nextAttemptAt,
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
      attempts: attempts ?? old?.attempts ?? 0,
      nextAttemptAt: nextAttemptAt ?? old?.nextAttemptAt,
    );
    await db.insert('local_records', record.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return record;
  }

  @override
  Future<LocalRecord?> get(String id) async {
    final rows = await (await database)
        .query('local_records', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : LocalRecord.fromRow(rows.single);
  }

  @override
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

  @override
  Future<void> setStatus(
    String id,
    LocalSyncStatus status, {
    String? remoteId,
    String? error,
    int? attempts,
    DateTime? nextAttemptAt,
  }) async {
    final values = <String, Object?>{
      'sync_status': status.name,
      'remote_id': remoteId,
      'last_error': error,
      'next_attempt_at': nextAttemptAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      if (attempts != null) 'attempts': attempts,
    };
    await (await database).update(
      'local_records',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
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
