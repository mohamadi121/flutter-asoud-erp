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
    this.attempts = 0,
    this.nextAttemptAt,
  });

  factory LocalRecord.fromRow(Map<String, Object?> row) {
    DateTime? nextAttempt;
    final next = row['next_attempt_at'] as String?;
    if (next != null && next.isNotEmpty) {
      nextAttempt = DateTime.parse(next);
    }
    return LocalRecord(
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
      attempts: (row['attempts'] as num?)?.toInt() ?? 0,
      nextAttemptAt: nextAttempt,
    );
  }

  final String id, entityType;
  final Map<String, dynamic> payload;
  final LocalSyncStatus status;
  final DateTime createdAt, updatedAt;
  final String? remoteId, lastError;

  /// How often the queue has already tried to send this row.
  final int attempts;

  /// When the next retry is due; null means the row is due right now.
  final DateTime? nextAttemptAt;

  Map<String, Object?> toRow() => {
        'id': id,
        'entity_type': entityType,
        'payload_json': jsonEncode(payload),
        'sync_status': status.name,
        'remote_id': remoteId,
        'last_error': lastError,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'attempts': attempts,
        'next_attempt_at': nextAttemptAt?.toIso8601String(),
      };
}
