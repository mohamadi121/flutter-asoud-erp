import 'dart:convert';

enum LocalSyncStatus { localOnly, pendingSync, synced, syncFailed }

class LocalRecord {
  const LocalRecord({
    required this.id,
    required this.entityType,
    required this.payload,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.remoteId,
    this.lastError,
  });

  factory LocalRecord.fromRow(Map<String, Object?> row) => LocalRecord(
        id: row['id']! as String,
        entityType: row['entity_type']! as String,
        payload: Map<String, dynamic>.from(
          jsonDecode(row['payload_json']! as String) as Map,
        ),
        status: LocalSyncStatus.values.firstWhere(
          (status) => status.name == row['sync_status'],
          orElse: () => LocalSyncStatus.localOnly,
        ),
        createdAt: DateTime.parse(row['created_at']! as String),
        updatedAt: DateTime.parse(row['updated_at']! as String),
        remoteId: row['remote_id'] as String?,
        lastError: row['last_error'] as String?,
      );

  final String id, entityType;
  final Map<String, dynamic> payload;
  final LocalSyncStatus status;
  final DateTime createdAt, updatedAt;
  final String? remoteId, lastError;

  Map<String, Object?> toRow() => {
        'id': id,
        'entity_type': entityType,
        'payload_json': jsonEncode(payload),
        'sync_status': status.name,
        'remote_id': remoteId,
        'last_error': lastError,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
