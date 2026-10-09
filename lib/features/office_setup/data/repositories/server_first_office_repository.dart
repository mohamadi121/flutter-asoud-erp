import 'dart:async';

import '../../../../core/network/api_exception.dart';
import '../../../../core/offline/local_database_store.dart';
import '../../../../core/offline/local_record.dart';
import '../../../../core/offline/offline_failure.dart';
import '../../domain/entities/office.dart';
import '../../domain/repositories/office_repository.dart';
import '../demo/office_demo_data.dart';
import '../models/office_model.dart';

class ServerFirstOfficeRepository
    implements OfficeRepository, LocalPreviewOfficeRepository {
  ServerFirstOfficeRepository(
    this._remote, {
    LocalRecordStore? local,
    this.localPreview,
    this.defaultOfficeTimeout = const Duration(seconds: 4),
  }) : _local = local ?? LocalDatabaseStore.instance;

  static const _entityType = 'office';
  static const _preferenceEntityType = 'office_preference';
  static const _defaultOfficeId = 'office_preference:default';
  final OfficeRepository _remote;
  final LocalRecordStore _local;
  final Duration defaultOfficeTimeout;
  final bool Function()? localPreview;
  @override
  bool get isLocalPreview => localPreview?.call() ?? false;
  String get _preferenceId =>
      '${isLocalPreview ? 'preview:' : ''}$_defaultOfficeId';

  @override
  Future<Office> createOffice(Office office) async {
    if (isLocalPreview && await _local.get(_id(office.name)) != null) {
      throw const ApiException(
          kind: ApiFailureKind.conflict,
          message:
              'دفتری با این نام روی دستگاه وجود دارد؛ آن را ویرایش کنید یا نام دیگری بنویسید.');
    }
    return _write(
      office,
      () => _remote.createOffice(office),
    );
  }

  @override
  Future<Office> updateOffice(String id, Office office) async {
    // Company names also scope local personnel; do not orphan their records.
    if (isLocalPreview && id != office.name) {
      throw const ApiException(
          kind: ApiFailureKind.validation,
          message:
              'تغییر نام دفتر محلی فعلاً مجاز نیست؛ اطلاعات دیگر قابل ویرایش است.');
    }
    return _write(
      office,
      () => _remote.updateOffice(id, office),
    );
  }

  Future<Office> _write(
    Office draft,
    Future<Office> Function() writeRemote,
  ) async {
    if (isLocalPreview) {
      await _save(draft, LocalSyncStatus.localOnly);
      return draft;
    }
    try {
      final saved = await writeRemote();
      await _save(saved, LocalSyncStatus.synced);
      return saved;
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      await _save(draft, LocalSyncStatus.pendingSync);
      rethrow;
    }
  }

  @override
  Future<List<Office>> listOffices() async {
    if (isLocalPreview) {
      final local = await _localOffices();
      // Fresh preview: offer the demo company so every screen can be tried.
      // Never persisted; any created office replaces it.
      return local.isEmpty ? [demoPreviewOffice()] : local;
    }
    try {
      final remote = await _remote.listOffices();
      for (final office in remote) {
        await _cacheRemote(office);
      }
      return _mergePending(remote, await _localOffices());
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      return _localOffices();
    }
  }

  @override
  Future<Office?> getDefaultOffice() async {
    if (isLocalPreview) {
      return await _localDefaultOffice() ??
          (await _localOffices()).firstOrNull ??
          demoPreviewOffice();
    }
    try {
      final office =
          await _remote.getDefaultOffice().timeout(defaultOfficeTimeout);
      if (office != null) await _cacheRemote(office);
      if (office != null) {
        await _saveDefaultName(office.name, status: LocalSyncStatus.synced);
      }
      return office ??
          await _localDefaultOffice() ??
          (await _localOffices()).firstOrNull;
    } catch (error) {
      if (error is! TimeoutException && !isRetryableOfflineFailure(error)) {
        rethrow;
      }
      return await _localDefaultOffice() ?? (await _localOffices()).firstOrNull;
    }
  }

  @override
  Future<Office> setDefaultOffice(Office office) async {
    if (isLocalPreview) {
      await _save(office, LocalSyncStatus.localOnly);
      await _saveDefaultName(office.name, status: LocalSyncStatus.localOnly);
      return office;
    }
    await _saveDefaultName(office.name);
    try {
      final saved = await _remote.setDefaultOffice(office);
      await _save(saved, LocalSyncStatus.synced);
      await _saveDefaultName(saved.name, status: LocalSyncStatus.synced);
      return saved;
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      await _save(office, LocalSyncStatus.pendingSync);
      rethrow;
    }
  }

  Future<void> _saveDefaultName(String name,
          {LocalSyncStatus status = LocalSyncStatus.synced}) =>
      _local.save(
        id: _preferenceId,
        entityType: _preferenceEntityType,
        payload: {'company': name},
        status: status,
      );

  Future<Office?> _localDefaultOffice() async {
    final preference = await _local.get(_preferenceId);
    final name = preference?.payload['company']?.toString();
    if (name == null || name.isEmpty) return null;
    final offices = await _localOffices();
    return offices.where((office) => office.name == name).firstOrNull;
  }

  Future<void> _save(Office office, LocalSyncStatus status) => _local.save(
        id: _id(office.name),
        entityType: _entityType,
        payload: _toPayload(office),
        status: status,
      );

  Future<void> _cacheRemote(Office office) async {
    final existing = await _local.get(_id(office.name));
    if (existing != null &&
        const {LocalSyncStatus.localOnly, LocalSyncStatus.pendingSync}
            .contains(existing.status)) {
      return;
    }
    await _save(office, LocalSyncStatus.synced);
  }

  Future<List<Office>> _localOffices() async => (await _local.list(
        entityType: _entityType,
      ))
          .where((record) =>
              localPreview == null ||
              (isLocalPreview
                  ? record.status == LocalSyncStatus.localOnly
                  : record.status != LocalSyncStatus.localOnly))
          .map((record) => OfficeModel.fromSetup(record.payload))
          .toList(growable: false);

  List<Office> _mergePending(List<Office> remote, List<Office> local) {
    final merged = <String, Office>{
      for (final office in remote) office.name: office,
    };
    for (final office in local) {
      merged[office.name] = office;
    }
    return merged.values.toList(growable: false);
  }

  String _id(String name) =>
      '${isLocalPreview ? 'preview:' : ''}office:${Uri.encodeComponent(name.trim())}';

  Map<String, dynamic> _toPayload(Office office) => {
        'company': office.name,
        'office_type': office.type == OfficeType.legal ? 'Legal' : 'Personal',
        'national_id': office.nationalId,
        'economic_code': office.economicCode,
        'auto_generate_detail_code': office.generateDetailCode,
        'owner_full_name': office.ownerFullName,
        'registration_number': office.registrationNumber,
        'activity_type': office.activityType,
        'company_type': office.companyType,
        'parent_office': office.parentOffice,
        'phone': office.phone,
        'email': office.email,
        'website': office.website,
        'province': office.province,
        'city': office.city,
        'address': office.address,
        'postal_code': office.postalCode,
        'fiscal_year': office.fiscalYear,
        'fiscal_year_start_month': office.fiscalYearStart.month,
        'chart_template': office.chartTemplate,
        'description': office.description,
        'modified': office.lastSyncedAt?.toIso8601String(),
        'complete': office.setupComplete,
        'office_saved': office.setupComplete,
        'accounting_saved': office.setupComplete,
        'roles_saved': office.setupComplete,
      };
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
