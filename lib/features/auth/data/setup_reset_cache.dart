import 'dart:convert';

import '../../../core/offline/local_database_store.dart';
import '../../../core/offline/local_record.dart';

bool isPendingResetRecord(LocalRecord row, {required String actor, required String server}) {
  if (row.status != LocalSyncStatus.pendingSync) return false;
  if (row.entityType == 'personnel_outbox') {
    return row.payload['owner'] == actor && row.payload['server'] == server;
  }
  final officePrefix = 'office-v2:${Uri.encodeComponent(jsonEncode([server, actor]))}:';
  return row.id.startsWith(officePrefix);
}

/// Never clears credentials, other users/sites, or an unrelated office draft.
bool belongsToReset(LocalRecord row, {required String actor, required String server,
    required Set<String> companies}) {
  List<dynamic>? key(String prefix) {
    if (!row.id.startsWith(prefix)) return null;
    try {
      final raw = row.id.substring(prefix.length).split(':').first;
      final value = jsonDecode(Uri.decodeComponent(raw));
      return value is List ? value : null;
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  final organization = key('org-v2:');
  if (organization != null) {
    return organization.length == 3 && organization[0] == server && organization[1] == actor &&
        companies.contains(organization[2]);
  }
  final office = key('office-v2:');
  if (office != null) {
    return office.length == 2 && office[0] == server && office[1] == actor &&
        companies.contains(row.payload['company']) && row.status == LocalSyncStatus.synced;
  }
  final roles = key('role-drafts-v1:');
  if (roles != null) return roles.length == 2 && roles[0] == server && roles[1] == actor;
  final personnel = key('personnel-cache:');
  if (personnel != null) {
    return personnel.length >= 3 && personnel[0] == actor && personnel[1] == server &&
        companies.contains(personnel[2]) && row.status == LocalSyncStatus.synced;
  }
  return false;
}

Future<void> clearResetCaches({required LocalRecordStore store, required String actor,
    required String server, required Set<String> companies}) async {
  if (actor.isEmpty || server.isEmpty) throw ArgumentError('A verified reset scope is required');
  for (final row in await store.list()) {
    if (belongsToReset(row, actor: actor, server: server, companies: companies)) {
      await store.delete(row.id);
    }
  }
}
