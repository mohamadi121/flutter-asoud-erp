import 'dart:async';
import '../../../core/network/frappe_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/offline/local_database_store.dart';
import '../../../core/offline/local_record.dart';
import '../../../core/offline/offline_failure.dart';
import '../domain/organization_chart.dart';

class OrganizationSnapshot {
  const OrganizationSnapshot(this.rows, this.revision, this.pending);
  final List<OrgPosition> rows;
  final int revision;
  final bool pending;
}

class OrganizationRepository {
  OrganizationRepository(this.client, {LocalRecordStore? local})
      : local = local ?? LocalDatabaseStore.instance;
  final FrappeApiClient client;
  final LocalRecordStore local;
  String key(String company) => 'org-chart:${Uri.encodeComponent(company)}';
  OrganizationSnapshot decode(Map<String, dynamic> data, bool pending) =>
      OrganizationSnapshot(
          (data['rows'] as List? ?? [])
              .map((e) =>
                  OrgPosition.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList(),
          (data['revision'] as num?)?.toInt() ?? 0,
          pending);
  Future<OrganizationSnapshot> load(String company) async {
    final cached = await local.get(key(company));
    if (cached != null && cached.status == LocalSyncStatus.pendingSync) {
      return decode(cached.payload, true);
    }
    try {
      final value = await client.callAsoudMethod(
          'asoud_erp.api.v1.organization.get_chart',
          data: {'company': company}).timeout(const Duration(seconds: 4));
      final data = Map<String, dynamic>.from(value as Map);
      await local.save(
          id: key(company),
          entityType: 'organization_chart',
          payload: data,
          status: LocalSyncStatus.synced);
      return decode(data, false);
    } catch (e) {
      if (e is! TimeoutException && !isRetryableOfflineFailure(e)) rethrow;
      return cached == null
          ? const OrganizationSnapshot([], 0, false)
          : decode(cached.payload, false);
    }
  }

  Future<OrganizationSnapshot> save(
      String company, List<OrgPosition> rows, int revision) async {
    validateOrganization(rows);
    final payload = {
      'company': company,
      'rows': rows.map((e) => e.toJson()).toList(),
      'revision': revision
    };
    // Keep a durable draft before transport. Explicit retry uses the same revision.
    await local.save(
        id: key(company),
        entityType: 'organization_chart',
        payload: payload,
        status: LocalSyncStatus.pendingSync);
    try {
      final response = await client.callMethod(
          'asoud_erp.api.v1.organization.save_chart',
          data: {'payload': payload}).timeout(const Duration(seconds: 4));
      final envelope = response['message'] as Map;
      final data =
          Map<String, dynamic>.from((envelope['data'] ?? envelope) as Map);
      await local.save(
          id: key(company),
          entityType: 'organization_chart',
          payload: data,
          status: LocalSyncStatus.synced);
      return decode(data, false);
    } catch (e) {
      if (e is TimeoutException || isRetryableOfflineFailure(e)) {
        return OrganizationSnapshot(rows, revision, true);
      }
      if (e is ApiException) rethrow;
      rethrow;
    }
  }
}
