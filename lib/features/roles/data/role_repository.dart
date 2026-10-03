import 'dart:async';
import 'dart:convert';
import '../../../core/offline/local_database_store.dart';
import '../../../core/offline/local_record.dart';
import '../../../core/offline/offline_failure.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/asoud_api_response.dart';
import '../domain/role_catalog.dart';

class _RemoteRoleRepository {
  const _RemoteRoleRepository(this.client);
  final FrappeApiClient client;
  static const _api = 'asoud_erp.api.v1.role_management';

  Future<dynamic> _call(String method, {Map<String, dynamic>? data}) async {
    // Security mutations must not be replayed later by the generic offline queue.
    final response = await client.callMethod(method, data: data);
    final envelope = response['message'];
    if (envelope is! Map ||
        envelope['meta'] is! Map ||
        (envelope['meta'] as Map)['api_version'] != 'v1') {
      throw const ApiException.protocol();
    }
    return AsoudApiResponse<dynamic>.parse(
        Map<String, dynamic>.from(envelope), (value) => value).data;
  }

  Future<RoleCatalog> load() async {
    final value =
        await _call('$_api.catalog').timeout(const Duration(seconds: 12));
    return RoleCatalog.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<ManagedRole> save(ManagedRole role) async {
    final value =
        await _call('$_api.save_role', data: {'payload': role.toJson()})
            .timeout(const Duration(seconds: 25));
    return ManagedRole.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<RoleCategory> createCategory(
      String code, String title, String style) async {
    final value = await _call('$_api.create_category', data: {
      'payload': {'code': code, 'title': title, 'style': style}
    }).timeout(const Duration(seconds: 20));
    return RoleCategory.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<void> applyTemplates(List<String> codes) async {
    await _call('$_api.apply_templates', data: {'codes': codes})
        .timeout(const Duration(seconds: 30));
  }

  Future<List<RolePermissionRow>> preview(List<String> roles) async {
    final value =
        await _call('$_api.permission_preview', data: {'roles': roles})
            .timeout(const Duration(seconds: 20));
    return (value as List)
        .map((row) =>
            RolePermissionRow.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }
}

/// Drafts never enter the generic replay queue or grant effective permissions.
class RoleRepository {
  RoleRepository(this.client, {LocalRecordStore? local})
      : local = local ??
            (client is FrappeClient ? LocalDatabaseStore.instance : null),
        remote = _RemoteRoleRepository(client) {
    if (client is FrappeClient) {
      _session = client.authenticationChanges.listen((_) {
        _epoch++;
        _key = null;
        _data = {};
        pendingCount = 0;
        offline = false;
      });
    }
  }
  final FrappeApiClient client;
  final LocalRecordStore? local;
  final _RemoteRoleRepository remote;
  StreamSubscription<bool>? _session;
  int _epoch = 0;
  String? _key;
  Map<String, dynamic> _data = {};
  bool offline = false;
  int pendingCount = 0;
  bool get isPreview => !client.isAuthenticated;
  Stream<bool> get sessionChanges => client is FrappeClient
      ? client.authenticationChanges
      : const Stream<bool>.empty();

  Future<void> dispose() async {
    _epoch++;
    await _session?.cancel();
  }

  void _check(int epoch) {
    if (_epoch != epoch) {
      throw const ApiException(
          kind: ApiFailureKind.unauthenticated,
          message: 'نشست تغییر کرده؛ صفحه را دوباره باز کنید.');
    }
  }

  Future<void> _identify({bool draftOnly = false}) async {
    // Reuse the already established owner only for local writes. Session changes
    // invalidate this key; no server operation uses this short path.
    if (draftOnly && _key != null) return;
    final epoch = _epoch;
    final owner = client.isAuthenticated
        ? (await client.getCurrentUser().timeout(const Duration(seconds: 40)))
            .userId
        : 'device-preview';
    _check(epoch);
    final server = client is FrappeClient
        ? (client as FrappeClient).serverIdentity
        : 'test';
    final key =
        'role-drafts-v1:${Uri.encodeComponent(jsonEncode([server, owner]))}';
    if (key != _key) {
      _data = (await local?.get(key))?.payload ?? {};
      _check(epoch);
      _key = key;
    }
  }

  List<Map<String, dynamic>> get _drafts => (_data['drafts'] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  Future<void> _persist(int epoch) async {
    _check(epoch);
    if (local != null) {
      await local!.save(
          id: _key!,
          entityType: 'role_drafts',
          payload: _data,
          status: LocalSyncStatus.localOnly);
    }
    _check(epoch);
    pendingCount = _drafts.length;
  }

  Map<String, dynamic> _encode(RoleCatalog catalog) => {
        'categories': catalog.categories
            .map((e) => {'code': e.code, 'title': e.title, 'style': e.style})
            .toList(),
        'roles': catalog.roles
            .map((e) => {
                  ...e.toJson(),
                  'enabled': e.enabled,
                  'assigned_users': e.assignedUsers
                })
            .toList(),
        'base_roles': catalog.baseRoles
            .map((e) => {
                  'name': e.name,
                  'title': e.title,
                  'description': e.description,
                  'available': e.available
                })
            .toList(),
        'templates': catalog.templates
            .map((e) => {
                  'code': e.code,
                  'title': e.title,
                  'category': e.category,
                  'base_roles': e.baseRoles,
                  'available': e.available,
                  'exists': e.exists
                })
            .toList(),
        'template_categories': catalog.templateCategories
            .map((e) => {'code': e.code, 'title': e.title, 'style': e.style})
            .toList(),
      };

  RoleCatalog _view() {
    final raw = Map<String, dynamic>.from(
        _data['catalog'] as Map? ?? _encode(const RoleCatalog()));
    final categories = (raw['categories'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final roles = (raw['roles'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    for (final draft in _drafts) {
      final values = Map<String, dynamic>.from(draft['values'] as Map);
      final rows = draft['kind'] == 'category'
          ? categories
          : draft['kind'] == 'role'
              ? roles
              : null;
      if (rows == null) continue;
      rows.removeWhere((e) => e['code'] == values['code']);
      rows.add(values);
    }
    return RoleCatalog.fromJson(
        {...raw, 'categories': categories, 'roles': roles});
  }

  RoleCatalog get localCatalog => _view();
  bool isDraft(String code) => _drafts.any(
      (draft) => draft['kind'] == 'role' && draft['code'] == code);

  Future<void> _remember(
      String field, Map<String, dynamic> values, int epoch) async {
    _check(epoch);
    final catalog = Map<String, dynamic>.from(
        _data['catalog'] as Map? ?? _encode(const RoleCatalog()));
    final rows = List<dynamic>.of(catalog[field] as List)
      ..removeWhere((row) => row['code'] == values['code'])
      ..add(values);
    catalog[field] = rows;
    _data['catalog'] = catalog;
    await _persist(epoch);
  }

  bool _unreachable(Object e) =>
      e is TimeoutException || isRetryableOfflineFailure(e);

  Future<RoleCatalog> load() async {
    final epoch = _epoch;
    await _identify();
    _check(epoch);
    try {
      if (client is FrappeClient && !client.isAuthenticated) {
        offline = true;
      } else {
        final catalog = await remote.load();
        _check(epoch);
        _data['catalog'] = _encode(catalog);
        offline = false;
      }
    } catch (e) {
      _check(epoch);
      if (!_unreachable(e)) rethrow;
      offline = true;
    }
    await _persist(epoch);
    return _view();
  }

  Future<void> _queue(
      String kind, String code, Map<String, dynamic> values) async {
    final epoch = _epoch;
    final drafts = _drafts;
    final index =
        drafts.indexWhere((e) => e['kind'] == kind && e['code'] == code);
    // Retain the original concurrency tokens across offline edits.
    if (kind == 'role' && index >= 0) {
      final original = drafts[index]['values'] as Map;
      values = {
        ...values,
        'modified': original['modified'],
        'profile_modified': original['profile_modified']
      };
    }
    final draft = {'kind': kind, 'code': code, 'values': values};
    if (index >= 0) {
      drafts[index] = draft;
    } else {
      drafts.add(draft);
    }
    _data['drafts'] = drafts;
    await _persist(epoch);
  }

  Future<ManagedRole> save(ManagedRole role) async {
    await _identify(draftOnly: offline);
    final epoch = _epoch;
    if (!offline && _drafts.isEmpty) {
      try {
        final saved = await remote.save(role);
        await _remember(
            'roles',
            {
              ...saved.toJson(),
              'enabled': saved.enabled,
              'assigned_users': saved.assignedUsers
            },
            epoch);
        return saved;
      } catch (e) {
        _check(epoch);
        if (!_unreachable(e)) rethrow;
        offline = true;
      }
    }
    _check(epoch);
    await _queue('role', role.code, {
      ...role.toJson(),
      'enabled': role.enabled,
      'assigned_users': role.assignedUsers
    });
    return role;
  }

  Future<RoleCategory> createCategory(
      String code, String title, String style) async {
    await _identify(draftOnly: offline);
    final epoch = _epoch;
    if (!offline && _drafts.isEmpty) {
      try {
        final saved = await remote.createCategory(code, title, style);
        await _remember(
            'categories',
            {'code': saved.code, 'title': saved.title, 'style': saved.style},
            epoch);
        return saved;
      } catch (e) {
        _check(epoch);
        if (!_unreachable(e)) rethrow;
        offline = true;
      }
    }
    _check(epoch);
    await _queue(
        'category', code, {'code': code, 'title': title, 'style': style});
    return RoleCategory(code: code, title: title, style: style);
  }

  Future<void> applyTemplates(List<String> codes) async {
    await _identify(draftOnly: offline);
    final epoch = _epoch;
    if (!offline && _drafts.isEmpty) {
      try {
        await remote.applyTemplates(codes);
        return;
      } catch (e) {
        _check(epoch);
        if (!_unreachable(e)) rethrow;
        offline = true;
      }
    }
    _check(epoch);
    for (final code in codes) {
      await _queue('template', code, {'code': code});
    }
  }

  Future<void> synchronize() async {
    await _identify();
    if (!client.isAuthenticated) {
      throw const ApiException(
          kind: ApiFailureKind.unauthenticated,
          message:
              'پیش‌نویس حالت بدون ورود، خودکار به حساب دیگری منتقل نمی‌شود. ابتدا با حساب اصلی وارد شوید.');
    }
    final epoch = _epoch;
    final drafts = _drafts;
    // Categories, role parents, then children; unresolved graphs remain drafts.
    final ordered = <Map<String, dynamic>>[];
    ordered.addAll(drafts.where((e) => e['kind'] != 'role'));
    final roles = drafts.where((e) => e['kind'] == 'role').toList();
    while (roles.isNotEmpty) {
      final ready = roles
          .where((e) =>
              !roles.any((p) => p['code'] == (e['values'] as Map)['parent']))
          .toList();
      if (ready.isEmpty) {
        throw const FormatException(
            'ارتباط حلقوی در نقش‌های پیش‌نویس وجود دارد.');
      }
      ordered.addAll(ready);
      roles.removeWhere(ready.contains);
    }
    for (final draft in ordered) {
      _check(epoch);
      final catalog = await remote.load();
      _check(epoch);
      final values = Map<String, dynamic>.from(draft['values'] as Map);
      if (draft['kind'] == 'category') {
        final found = catalog.categories.where((e) => e.code == draft['code']);
        if (found.isEmpty) {
          await remote.createCategory(values['code'] as String,
              values['title'] as String, values['style'] as String);
        } else if (found.first.title != values['title'] ||
            found.first.style != values['style']) {
          throw const FormatException(
              'کد دسته روی سرور متفاوت است؛ پیش‌نویس را اصلاح کنید.');
        }
      } else if (draft['kind'] == 'template') {
        await remote.applyTemplates([draft['code'] as String]);
      } else {
        final role = ManagedRole.fromJson(values);
        final found = catalog.roles.where((e) => e.code == role.code);
        bool same(ManagedRole other) =>
            other.title == role.title &&
            other.category == role.category &&
            other.parent == role.parent &&
            other.description == role.description &&
            other.enabled == role.enabled &&
            other.baseRoles.length == role.baseRoles.length &&
            other.baseRoles.toSet().containsAll(role.baseRoles);
        if (found.isEmpty || !same(found.first)) await remote.save(role);
      }
      _check(epoch);
      final confirmed = await remote.load();
      _check(epoch);
      _data['catalog'] = _encode(confirmed);
      _data['drafts'] = _drafts
          .where((e) =>
              !(e['kind'] == draft['kind'] && e['code'] == draft['code']))
          .toList();
      await _persist(epoch);
    }
    offline = false;
  }

  Future<List<RolePermissionRow>> preview(List<String> roles) =>
      remote.preview(roles);

  Future<void> discardDrafts() async {
    await _identify();
    final epoch = _epoch;
    // Require a successful authorized read before abandoning the working draft.
    final catalog = await remote.load();
    _check(epoch);
    if (local != null) {
      await local!.save(
          id: '$_key:archive:${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'role_draft_archive',
          payload: _data);
    }
    _check(epoch);
    _data = {'catalog': _encode(catalog), 'drafts': []};
    offline = false;
    await _persist(epoch);
  }
}
