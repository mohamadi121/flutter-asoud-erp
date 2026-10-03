import '../../../../core/offline/local_database_store.dart';
import '../../../../core/offline/local_record.dart';
import '../../../../core/offline/offline_failure.dart';
import '../../domain/entities/detail_group.dart';
import '../../domain/repositories/detail_group_repository.dart';

class ServerFirstDetailGroupRepository implements DetailGroupRepository {
  ServerFirstDetailGroupRepository(this._remote,
      {LocalRecordStore? local, this.localPreview})
      : _local = local ?? LocalDatabaseStore.instance;

  static const _entityType = 'detail_group';
  final DetailGroupRepository _remote;
  final LocalRecordStore _local;
  final bool Function()? localPreview;
  bool get _isPreview => localPreview?.call() ?? false;

  @override
  Future<List<DetailGroup>> getGroups() async {
    if (_isPreview) return _localGroups();
    try {
      final remote = await _remote.getGroups();
      for (final group in remote) {
        await _cacheRemote(group);
      }
      return _merge(remote, await _localGroups());
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      return _localGroups();
    }
  }

  @override
  Future<DetailGroup> saveGroup({
    required String code,
    required String title,
    String? id,
  }) async {
    final previous =
        (await _localGroups()).where((group) => group.id == id).firstOrNull;
    final draft = DetailGroup(
        id: id ?? code,
        code: code,
        title: title,
        partyRole: previous?.partyRole,
        parentGroup: previous?.parentGroup,
        iconKey: previous?.iconKey,
        colorHex: previous?.colorHex,
        disabled: previous?.disabled ?? false);
    if (_isPreview) {
      final groups = await _localGroups();
      if (groups.any((group) => group.code == code && group.id != id)) {
        throw StateError('کد گروه تکراری است.');
      }
      await _save(draft, LocalSyncStatus.localOnly);
      return draft;
    }
    try {
      final saved = await _remote.saveGroup(code: code, title: title, id: id);
      await _save(saved, LocalSyncStatus.synced);
      return saved;
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      await _save(draft, LocalSyncStatus.pendingSync);
      rethrow;
    }
  }

  @override
  Future<List<DetailGroup>> seedDefaults() async {
    if (_isPreview) {
      await _seedLocal(LocalSyncStatus.localOnly);
      return _localGroups();
    }
    try {
      final saved = await _remote.seedDefaults();
      for (final group in saved) {
        await _cacheRemote(group);
      }
      return _merge(saved, await _localGroups());
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      await _local.save(
        id: 'detail-groups:seed-defaults',
        entityType: 'detail_group_seed',
        payload: const {'seed_defaults': true},
        status: LocalSyncStatus.pendingSync,
      );
      await _seedLocal(LocalSyncStatus.pendingSync);
      rethrow;
    }
  }

  Future<void> _seedLocal(LocalSyncStatus status) async {
    final existing = await _localGroups();
    const defaults = [
      ('10000', 'مشتریان', 'Customer'),
      ('20000', 'تأمین‌کنندگان', 'Supplier'),
      ('30000', 'پرسنل', 'Employee'),
      ('40000', 'بانک‌ها', null),
      ('50000', 'صندوق‌ها', null),
      ('60000', 'مراکز هزینه', null),
      ('70000', 'پروژه‌ها', null),
      ('90000', 'سایر', null),
    ];
    for (final item in defaults) {
      if (existing
          .any((group) => group.code == item.$1 || group.title == item.$2)) {
        continue;
      }
      await _save(
          DetailGroup(
              id: item.$1, code: item.$1, title: item.$2, partyRole: item.$3),
          status);
    }
  }

  @override
  Future<void> disableGroup(String id) async {
    if (_isPreview) {
      await _markDisabled(id, LocalSyncStatus.localOnly);
      return;
    }
    try {
      await _remote.disableGroup(id);
      await _markDisabled(id, LocalSyncStatus.synced);
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      await _markDisabled(id, LocalSyncStatus.pendingSync);
      rethrow;
    }
  }

  Future<void> _markDisabled(String id, LocalSyncStatus status) async {
    final groups = await _localGroups();
    final current = groups.where((group) => group.id == id).firstOrNull;
    if (current == null) return;
    await _save(
      DetailGroup(
        id: current.id,
        code: current.code,
        title: current.title,
        disabled: true,
        partyRole: current.partyRole,
        parentGroup: current.parentGroup,
        iconKey: current.iconKey,
        colorHex: current.colorHex,
      ),
      status,
    );
  }

  Future<void> _cacheRemote(DetailGroup group) async {
    final existing = await _local.get(_id(group));
    if (existing != null &&
        const {LocalSyncStatus.localOnly, LocalSyncStatus.pendingSync}
            .contains(existing.status)) {
      return;
    }
    await _save(group, LocalSyncStatus.synced);
  }

  Future<void> _save(DetailGroup group, LocalSyncStatus status) => _local.save(
        id: _id(group),
        entityType: _entityType,
        payload: {
          'id': group.id,
          'code': group.code,
          'title': group.title,
          'disabled': group.disabled,
          'party_role': group.partyRole,
          'parent_group': group.parentGroup,
          'icon_key': group.iconKey,
          'color_hex': group.colorHex,
        },
        status: status,
      );

  Future<List<DetailGroup>> _localGroups() async =>
      (await _local.list(entityType: _entityType))
          .where((record) =>
              localPreview == null ||
              (_isPreview
                  ? record.status == LocalSyncStatus.localOnly
                  : record.status != LocalSyncStatus.localOnly))
          .map((record) => DetailGroup(
                id: record.payload['id']?.toString() ?? '',
                code: record.payload['code']?.toString() ?? '',
                title: record.payload['title']?.toString() ?? '',
                disabled: record.payload['disabled'] == true,
                partyRole: record.payload['party_role']?.toString(),
                parentGroup: record.payload['parent_group']?.toString(),
                iconKey: record.payload['icon_key']?.toString(),
                colorHex: record.payload['color_hex']?.toString(),
              ))
          .toList(growable: false);

  List<DetailGroup> _merge(List<DetailGroup> remote, List<DetailGroup> local) {
    final values = <String, DetailGroup>{
      for (final item in remote) _key(item): item
    };
    for (final item in local) {
      values[_key(item)] = item;
    }
    return values.values.toList(growable: false);
  }

  String _id(DetailGroup value) =>
      '${_isPreview ? 'preview:' : ''}detail-group:${Uri.encodeComponent(_key(value))}';
  String _key(DetailGroup value) =>
      value.id.isNotEmpty ? value.id : '${value.code}:${value.title}';
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
