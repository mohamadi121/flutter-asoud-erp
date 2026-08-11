import 'dart:async';

import '../network/api_exception.dart';
import '../network/frappe_client.dart';
import 'local_database_store.dart';
import 'local_record.dart';
import 'offline_failure.dart';

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

class OfflineSyncService {
  OfflineSyncService(
    this._client, {
    LocalRecordStore? local,
  }) : _local = local ?? LocalDatabaseStore.instance;

  final FrappeApiClient _client;
  final LocalRecordStore _local;
  Future<OfflineSyncReport>? _activeSync;

  Future<OfflineSyncReport> syncNow() =>
      _activeSync ??= _run().whenComplete(() => _activeSync = null);

  Future<OfflineSyncReport> _run() async {
    var synced = 0;
    var failed = 0;
    final records = await _local.list(statuses: const {
      LocalSyncStatus.localOnly,
      LocalSyncStatus.pendingSync,
    });
    final mutations = records
        .where((record) => record.payload['operation'] is String)
        .toList(growable: false)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final record in mutations) {
      final payload = Map<String, dynamic>.from(record.payload)
        ..remove('operation');
      try {
        final response = await _client.replayOfflineMutation(
          mutationId: record.id,
          operation: record.payload['operation'] as String,
          target: record.entityType,
          data: payload,
        );
        await _local.setStatus(record.id, LocalSyncStatus.synced);
        await _reconcileDomainRecord(record.entityType, payload, response);
        synced++;
      } catch (error) {
        if (_shouldPause(error)) {
          await _local.setStatus(
            record.id,
            LocalSyncStatus.pendingSync,
            error: error.toString(),
          );
          break;
        }
        await _local.setStatus(
          record.id,
          LocalSyncStatus.syncFailed,
          error: error.toString(),
        );
        failed++;
      }
    }

    final remaining = (await _local.list(statuses: const {
      LocalSyncStatus.localOnly,
      LocalSyncStatus.pendingSync,
    }))
        .where((record) => record.payload['operation'] is String)
        .length;
    return OfflineSyncReport(
      synced: synced,
      failed: failed,
      remaining: remaining,
    );
  }

  bool _shouldPause(Object error) =>
      isRetryableOfflineFailure(error) ||
      (error is ApiException && error.kind == ApiFailureKind.unauthenticated);

  Future<void> _reconcileDomainRecord(
    String target,
    Map<String, dynamic> payload,
    dynamic response,
  ) async {
    String? entityType;
    bool Function(LocalRecord)? matches;

    if (target.endsWith('.setup.save_office')) {
      entityType = 'office';
      final name = (payload['company'] ?? payload['company_name'])?.toString();
      matches = (record) => record.payload['company']?.toString() == name;
    } else if (target.endsWith('.setup.update_company_settings')) {
      entityType = 'company_accounting_settings';
      final company = payload['company']?.toString();
      matches = (record) =>
          record.id == 'company-settings:${Uri.encodeComponent(company ?? '')}';
    } else if (target.endsWith('.setup.update_account_code_settings')) {
      entityType = 'account_code_settings';
      final company = payload['company']?.toString();
      matches = (record) =>
          record.id == 'account-code:${Uri.encodeComponent(company ?? '')}';
    } else if (target.endsWith('.setup.create_fiscal_year')) {
      final company = payload['company']?.toString() ?? '';
      entityType = 'fiscal_year:$company';
      final year = payload['fiscal_year']?.toString();
      matches = (record) => record.payload['year']?.toString() == year;
    } else if (target.contains('.account.create_account') ||
        target.contains('.account.update_account')) {
      final company = payload['company']?.toString() ?? '';
      entityType = 'account:$company';
      final id = payload['account']?.toString();
      final title = payload['account_name']?.toString();
      matches = (record) =>
          (id != null && record.payload['id']?.toString() == id) ||
          record.payload['title']?.toString() == title;
    } else if (target.endsWith('.detail_group.save_detail_group') ||
        target.endsWith('.detail_group.disable_detail_group')) {
      entityType = 'detail_group';
      final id = payload['name']?.toString();
      final code = payload['group_code']?.toString();
      matches = (record) =>
          (id != null && record.payload['id']?.toString() == id) ||
          (code != null && record.payload['code']?.toString() == code);
    } else if (target.endsWith('.party.save_party') ||
        target.endsWith('.party.disable_party')) {
      entityType = 'party_profile';
      final id = payload['name']?.toString();
      final title = payload['display_name']?.toString();
      matches = (record) =>
          (id != null && record.payload['id']?.toString() == id) ||
          (title != null &&
              record.payload['display_name']?.toString() == title);
    } else if (target.contains('.floating_detail.')) {
      entityType = 'floating_detail';
      final id = payload['name']?.toString();
      final title = payload['title']?.toString();
      final group = payload['detail_group']?.toString();
      matches = (record) =>
          (id != null && record.payload['id']?.toString() == id) ||
          (title != null &&
              record.payload['title']?.toString() == title &&
              record.payload['group_id']?.toString() == group);
    }

    if (entityType == null || matches == null) return;
    final candidates = await _local.list(entityType: entityType);
    for (final candidate in candidates.where(matches)) {
      await _local.setStatus(
        candidate.id,
        LocalSyncStatus.synced,
        remoteId: _remoteId(response),
      );
    }
  }

  String? _remoteId(dynamic response) {
    if (response is! Map) return null;
    return (response['name'] ?? response['id'] ?? response['company'])
        ?.toString();
  }
}
