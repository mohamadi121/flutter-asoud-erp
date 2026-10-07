import 'dart:async';

import '../network/api_exception.dart';
import '../network/frappe_client.dart';
import 'local_database_store.dart';
import 'local_record.dart';
import 'offline_failure.dart';

/// What one replay run achieved. [remaining] counts every unsent row, failed
/// rows included, so a caller can tell the user how much is still on the phone.
class OfflineSyncReport {
  const OfflineSyncReport({
    required this.synced,
    required this.failed,
    required this.remaining,
  });

  final int synced;
  final int failed;
  final int remaining;
}

enum _ReplayOutcome { synced, retryLater, failed }

/// Replays queued writes oldest first, one exponential backoff per row.
/// Statuses of a write that has not reached the server yet.
const unsentQueueStatuses = {
  LocalSyncStatus.localOnly,
  LocalSyncStatus.pendingSync,
  LocalSyncStatus.syncFailed,
};

/// Whether [record] is a queued mutation (it has an `operation`), as opposed to
/// a local mirror or cache row. Shared by the queue, its screen and the counts.
bool isQueuedMutation(LocalRecord record) =>
    record.payload['operation'] is String;

class OfflineSyncService {
  OfflineSyncService(
    this._client, {
    LocalRecordStore? local,
    this.afterSync,
    DateTime Function()? clock,
  })  : _local = local ?? LocalDatabaseStore.instance,
        _clock = clock ?? DateTime.now;

  /// Wait before the next retry of a row: ۳۰ ثانیه، ۱، ۲، ۵، ۱۵ دقیقه and then
  /// half an hour for every further attempt.
  static const backoffSchedule = <Duration>[
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
  ];

  /// The wait before the [attempt]th retry; the cap holds for every later one.
  static Duration backoffFor(int attempt) =>
      backoffSchedule[(attempt - 1).clamp(0, backoffSchedule.length - 1)];

  final FrappeApiClient _client;
  final LocalRecordStore _local;
  final DateTime Function() _clock;
  final Future<void> Function()? afterSync;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Future<OfflineSyncReport>? _activeSync;

  /// Without a session there is nothing to replay and no owner to scope by.
  bool get isAuthenticated => _client.isAuthenticated;

  /// True while a run or a manual retry is in flight.
  bool get isSyncing => _activeSync != null;

  /// Emits whenever the queue or the syncing state changes, for a status widget.
  Stream<void> get changes => _changes.stream;

  Future<OfflineSyncReport> syncNow() {
    final active = _activeSync;
    if (active != null) return active;
    late final Future<OfflineSyncReport> run;
    run = _runAll().whenComplete(() {
      _activeSync = null;
      _notify();
    });
    _activeSync = run;
    _notify();
    return run;
  }

  /// Every write still waiting for the server, oldest first.
  Future<List<LocalRecord>> unsent() async {
    final rows = (await _local.list(statuses: unsentQueueStatuses))
        .where(isQueuedMutation)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return rows;
  }

  Future<int> unsentCount() async => (await unsent()).length;

  /// A manual retry of one row: it clears the backoff and is sent right away.
  Future<void> retry(String id) async {
    if (await _local.get(id) == null) return;
    await _local.setStatus(
      id,
      LocalSyncStatus.pendingSync,
      error: null,
      attempts: 0,
      nextAttemptAt: null,
    );
    if (!_client.isAuthenticated) {
      _notify();
      return;
    }
    // The replay must work on the row as it is stored now, with a fresh budget.
    final record = await _local.get(id);
    if (record == null) return;
    final owner = (await _client.getCurrentUser()).userId;
    await _replay(record, owner: owner, server: _server());
    _notify();
  }

  /// A manual resend of the whole queue; every row gets a fresh attempt budget.
  Future<void> sendAll() async {
    for (final record in await unsent()) {
      await _local.setStatus(
        record.id,
        LocalSyncStatus.pendingSync,
        error: null,
        attempts: 0,
        nextAttemptAt: null,
      );
    }
    await syncNow();
  }

  /// Drops one queued write and the local row it mirrored, so no phantom draft
  /// survives the discard.
  Future<void> discard(String id) async {
    final record = await _local.get(id);
    if (record == null) return;
    final mirror = _mirrorOf(record.entityType, record.payload);
    if (mirror != null) {
      final candidates = await _local.list(entityType: mirror.entityType);
      for (final candidate in candidates.where(mirror.matches)) {
        await _local.delete(candidate.id);
      }
    }
    await _local.delete(id);
    _notify();
  }

  Future<OfflineSyncReport> _runAll() async {
    final report = await _run();
    await afterSync?.call();
    return report;
  }

  Future<OfflineSyncReport> _run() async {
    var synced = 0;
    var failed = 0;
    final queued = await unsent();
    if (!_client.isAuthenticated || queued.isEmpty) {
      return OfflineSyncReport(synced: 0, failed: 0, remaining: queued.length);
    }
    final owner = (await _client.getCurrentUser()).userId;
    final server = _server();
    final mine = queued
        .where((record) =>
            record.payload['_asoud_owner'] == owner &&
            record.payload['_asoud_server'] == server)
        .toList(growable: false);
    final now = _clock();
    // A row the queue will not retry on its own still holds back everything
    // that writes the same server record; unrelated rows keep moving.
    final blocked = <String>{};

    rows:
    for (final record in mine) {
      if (!_client.isAuthenticated ||
          (await _client.getCurrentUser()).userId != owner) {
        break;
      }
      if (record.status == LocalSyncStatus.syncFailed &&
          record.nextAttemptAt == null) {
        // A validation failure waits for the user; only a manual retry sends it.
        _block(blocked, record);
        continue;
      }
      final key = _entityKey(record);
      if (key != null && blocked.contains(key)) continue;
      final deadline = record.nextAttemptAt;
      if (deadline != null && deadline.isAfter(now)) {
        // Backoff has not elapsed, so the prerequisite is still missing.
        _block(blocked, record);
        continue;
      }
      switch (await _replay(record, owner: owner, server: server)) {
        case _ReplayOutcome.synced:
          synced++;
        case _ReplayOutcome.failed:
          failed++;
          _block(blocked, record);
        case _ReplayOutcome.retryLater:
          break rows;
      }
    }

    return OfflineSyncReport(
      synced: synced,
      failed: failed,
      remaining: (await unsent()).length,
    );
  }

  Future<_ReplayOutcome> _replay(
    LocalRecord record, {
    required String owner,
    required String server,
  }) async {
    if (record.payload['_asoud_owner'] != owner ||
        record.payload['_asoud_server'] != server) {
      return _ReplayOutcome.failed;
    }
    final payload = Map<String, dynamic>.from(record.payload)
      ..remove('operation')
      ..remove('_asoud_owner')
      ..remove('_asoud_server');
    try {
      final response = await _client.replayOfflineMutation(
        mutationId: record.id,
        operation: record.payload['operation'] as String,
        target: record.entityType,
        data: payload,
      );
      await _local.setStatus(record.id, LocalSyncStatus.synced, attempts: 0);
      await _reconcileDomainRecord(record.entityType, payload, response);
      return _ReplayOutcome.synced;
    } catch (error) {
      final attempt = record.attempts + 1;
      final message = offlineFailureMessage(error);
      if (_shouldPause(error)) {
        await _local.setStatus(
          record.id,
          LocalSyncStatus.pendingSync,
          error: message,
          attempts: attempt,
          nextAttemptAt: _clock().add(backoffFor(attempt)),
        );
        return _ReplayOutcome.retryLater;
      }
      // A validation failure is the user's to fix: no deadline, no auto retry.
      await _local.setStatus(
        record.id,
        LocalSyncStatus.syncFailed,
        error: message,
        attempts: attempt,
      );
      return _ReplayOutcome.failed;
    }
  }

  bool _shouldPause(Object error) =>
      isRetryableOfflineFailure(error) ||
      (error is ApiException && error.kind == ApiFailureKind.unauthenticated);

  String _server() =>
      _client is FrappeClient ? _client.serverIdentity : 'injected-client';

  /// The server record a queued row writes. Rows that share it must reach the
  /// server in order, so the id inside the payload is part of the identity.
  static String? _entityKey(LocalRecord record) {
    for (final field in const ['name', 'id', 'record_id', 'docname']) {
      final value = record.payload[field]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return '${record.entityType}|$value';
      }
    }
    return null;
  }

  static void _block(Set<String> blocked, LocalRecord record) {
    final key = _entityKey(record);
    if (key != null) blocked.add(key);
  }

  Future<void> _reconcileDomainRecord(
    String target,
    Map<String, dynamic> payload,
    dynamic response,
  ) async {
    final mirror = _mirrorOf(target, payload);
    if (mirror == null) return;
    final candidates = await _local.list(entityType: mirror.entityType);
    for (final candidate in candidates.where(mirror.matches)) {
      await _local.setStatus(
        candidate.id,
        LocalSyncStatus.synced,
        remoteId: _remoteId(response),
      );
    }
  }

  void _notify() {
    if (_changes.isClosed) return;
    _changes.add(null);
  }

  String? _remoteId(dynamic response) {
    if (response is! Map) return null;
    return (response['name'] ?? response['id'] ?? response['company'])
        ?.toString();
  }
}

/// The local row a queued write kept as its draft on this device.
_LocalMirror? _mirrorOf(String target, Map<String, dynamic> payload) {
  if (target.endsWith('.setup.save_office')) {
    final name = (payload['company'] ?? payload['company_name'])?.toString();
    return _LocalMirror(
        'office', (record) => record.payload['company']?.toString() == name);
  }
  if (target.endsWith('.setup.update_company_settings')) {
    final company = payload['company']?.toString();
    return _LocalMirror(
      'company_accounting_settings',
      (record) =>
          record.id == 'company-settings:${Uri.encodeComponent(company ?? '')}',
    );
  }
  if (target.endsWith('.setup.update_account_code_settings')) {
    final company = payload['company']?.toString();
    return _LocalMirror(
      'account_code_settings',
      (record) =>
          record.id == 'account-code:${Uri.encodeComponent(company ?? '')}',
    );
  }
  if (target.endsWith('.setup.create_fiscal_year')) {
    final company = payload['company']?.toString() ?? '';
    final year = payload['fiscal_year']?.toString();
    return _LocalMirror('fiscal_year:$company',
        (record) => record.payload['year']?.toString() == year);
  }
  if (target.contains('.account.create_account') ||
      target.contains('.account.update_account')) {
    final company = payload['company']?.toString() ?? '';
    final id = payload['account']?.toString();
    final title = payload['account_name']?.toString();
    return _LocalMirror(
        'account:$company',
        (record) =>
            (id != null && record.payload['id']?.toString() == id) ||
            record.payload['title']?.toString() == title);
  }
  if (target.endsWith('.detail_group.save_detail_group') ||
      target.endsWith('.detail_group.disable_detail_group')) {
    final id = payload['name']?.toString();
    final code = payload['group_code']?.toString();
    return _LocalMirror(
        'detail_group',
        (record) =>
            (id != null && record.payload['id']?.toString() == id) ||
            (code != null && record.payload['code']?.toString() == code));
  }
  if (target.endsWith('.party.save_party') ||
      target.endsWith('.party.disable_party')) {
    final id = payload['name']?.toString();
    final title = payload['display_name']?.toString();
    return _LocalMirror(
        'party_profile',
        (record) =>
            (id != null && record.payload['id']?.toString() == id) ||
            (title != null &&
                record.payload['display_name']?.toString() == title));
  }
  if (target.contains('.floating_detail.')) {
    final id = payload['name']?.toString();
    final title = payload['title']?.toString();
    final group = payload['detail_group']?.toString();
    return _LocalMirror(
        'floating_detail',
        (record) =>
            (id != null && record.payload['id']?.toString() == id) ||
            (title != null &&
                record.payload['title']?.toString() == title &&
                record.payload['group_id']?.toString() == group));
  }
  return null;
}

class _LocalMirror {
  const _LocalMirror(this.entityType, this.matches);

  final String entityType;
  final bool Function(LocalRecord) matches;
}
