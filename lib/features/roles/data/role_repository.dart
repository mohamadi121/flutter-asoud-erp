import 'dart:async';
import 'dart:convert';
import '../../../core/offline/local_database_store.dart';
import '../../../core/offline/local_record.dart';
import '../../../core/offline/offline_failure.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/asoud_api_response.dart';
import '../domain/role_catalog.dart';
import '../domain/bundled_role_catalog.dart';

class _RemoteRoleRepository {
  const _RemoteRoleRepository(this.client);
  final FrappeApiClient client;
  static const _api = 'asoud_erp.api.v1.role_management';

  Future<dynamic> _call(String method, {Map<String, dynamic>? data}) async {
    // Reads stay on the raw transport: they must never be staged as mutations.
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

  Future<dynamic> _write(String method, {Map<String, dynamic>? data}) async {
    // Security mutations go through the shared offline queue so they are
    // staged and replayed automatically; the queue rethrows while offline and
    // the repository keeps a local draft for the UI in that case.
    return client.callAsoudMethod(method, data: data);
  }

  Future<RoleCatalog> load() async {
    final value =
        await _call('$_api.catalog').timeout(const Duration(seconds: 12));
    return RoleCatalog.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<ManagedRole> save(ManagedRole role) async {
    final value =
        await _write('$_api.save_role', data: {'payload': role.toJson()})
            .timeout(const Duration(seconds: 25));
    return ManagedRole.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<RoleCategory> createCategory(
      String code, String title, String style) async {
    final value = await _write('$_api.create_category', data: {
      'payload': {'code': code, 'title': title, 'style': style}
    }).timeout(const Duration(seconds: 20));
    return RoleCategory.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<void> applyTemplates(List<String> codes) async {
    await _write('$_api.apply_templates', data: {'codes': codes})
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

/// Drafts mirror writes staged in the shared offline queue and grant no
/// effective permissions until the server accepts them.
class RoleRepository {
  RoleRepository(this.client, {LocalRecordStore? local})
      : local = local ??
            (client is FrappeClient ? LocalDatabaseStore.instance : null),
        _remote = _RemoteRoleRepository(client) {
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
  final _RemoteRoleRepository _remote;
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
        _data['catalog'] as Map? ?? _encode(bundledRoleCatalog));
    if (offline && (raw['templates'] as List).isEmpty) {
      final bundled = _encode(bundledRoleCatalog);
      raw['templates'] = bundled['templates'];
      raw['template_categories'] = bundled['template_categories'];
    }
    final categories = (raw['categories'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final roles = (raw['roles'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    for (final draft in _drafts) {
      final values = Map<String, dynamic>.from(draft['values'] as Map);
      if (draft['kind'] == 'template') {
        final template = bundledRoleCatalog.templates
            .where((item) => item.code == values['code'])
            .firstOrNull;
        if (template != null &&
            !roles.any((row) => row['code'] == template.code)) {
          final category = bundledRoleCatalog.templateCategories
              .firstWhere((item) => item.code == template.category);
          if (!categories.any((row) => row['code'] == category.code)) {
            categories.add({
              'code': category.code,
              'title': category.title,
              'style': category.style
            });
          }
          roles.add({
            ...ManagedRole(
                    code: template.code,
                    title: template.title,
                    category: template.category,
                    baseRoles: template.baseRoles)
                .toJson(),
            'enabled': true
          });
        }
      }
      final rows = draft['kind'] == 'category'
          ? categories
          : draft['kind'] == 'role'
              ? roles
              : null;
      if (rows == null) continue;
      rows.removeWhere((e) => e['code'] == values['code']);
      rows.add(values);
    }
    final templates = (raw['templates'] as List)
        .map((row) => {
              ...Map<String, dynamic>.from(row as Map),
              'exists': roles.any((role) => role['code'] == row['code']),
            })
        .toList();
    return RoleCatalog.fromJson({
      ...raw,
      'categories': categories,
      'roles': roles,
      'templates': templates
    });
  }

  RoleCatalog get localCatalog => _view();
  bool isDraft(String code) => _drafts.any((draft) =>
      (draft['kind'] == 'role' || draft['kind'] == 'template') &&
      draft['code'] == code);

  Future<void> _remember(
      String field, Map<String, dynamic> values, int epoch) async {
    _check(epoch);
    final catalog = Map<String, dynamic>.from(
        _data['catalog'] as Map? ?? _encode(bundledRoleCatalog));
    final rows = List<dynamic>.of(catalog[field] as List)
      ..removeWhere((row) => row['code'] == values['code'])
      ..add(values);
    catalog[field] = rows;
    _data['catalog'] = catalog;
    await _persist(epoch);
  }

  bool _unreachable(Object e) =>
      e is TimeoutException ||
      isRetryableOfflineFailure(e) ||
      e.runtimeType.toString() == 'QueuedOfflineException';

  Future<RoleCatalog> load() async {
    final epoch = _epoch;
    await _identify();
    _check(epoch);
    try {
      if (client is FrappeClient && !client.isAuthenticated) {
        offline = true;
      } else {
        final catalog = await _remote.load();
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

  void _dropDraft(String kind, String code) {
    _data['drafts'] = _drafts
        .where((e) => !(e['kind'] == kind && e['code'] == code))
        .toList();
  }

  /// Marks staged queue rows for an already-applied draft as synced so the
  /// automatic replay does not send the same write a second time. Role codes
  /// are unique, so matching on the code is exact.
  Future<void> _supersedeStaged(String kind, String code) async {
    final store = local;
    if (store == null) return;
    final rows = await store.list(statuses: {
      LocalSyncStatus.localOnly,
      LocalSyncStatus.pendingSync,
      LocalSyncStatus.syncFailed,
    });
    for (final row in rows) {
      if (row.payload['operation'] is! String) continue;
      final target = row.entityType;
      final data = row.payload;
      var match = false;
      if (kind == 'role' && target.endsWith('.save_role')) {
        final payload = data['payload'];
        match = payload is Map && '${payload['code']}' == code;
      } else if (kind == 'category' && target.endsWith('.create_category')) {
        final payload = data['payload'];
        match = payload is Map && '${payload['code']}' == code;
      } else if (kind == 'template' && target.endsWith('.apply_templates')) {
        final codes = data['codes'];
        match = codes is List && codes.map((item) => '$item').contains(code);
      }
      if (match) {
        await store.setStatus(row.id, LocalSyncStatus.synced);
      }
    }
  }

  Future<ManagedRole> save(ManagedRole role) async {
    await _identify(draftOnly: offline);
    final epoch = _epoch;
    if (!offline && _drafts.isEmpty) {
      try {
        final saved = await _remote.save(role);
        _dropDraft('role', role.code);
        await _remember(
            'roles',
            {
              ...saved.toJson(),
              'enabled': saved.enabled,
              'assigned_users': saved.assignedUsers
            },
            epoch);
        await _supersedeStaged('role', role.code);
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
    if (_view().categories.any((category) => category.code == code)) {
      throw const FormatException('کد دسته تکراری است.');
    }
    final epoch = _epoch;
    if (!offline && _drafts.isEmpty) {
      try {
        final saved = await _remote.createCategory(code, title, style);
        _dropDraft('category', code);
        await _remember(
            'categories',
            {'code': saved.code, 'title': saved.title, 'style': saved.style},
            epoch);
        await _supersedeStaged('category', code);
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
        await _remote.applyTemplates(codes);
        return;
      } catch (e) {
        _check(epoch);
        if (!_unreachable(e)) rethrow;
        offline = true;
      }
    }
    _check(epoch);
    for (final code in codes) {
      final catalog = _view();
      if (catalog.roles.any((role) => role.code == code)) continue;
      final template =
          catalog.templates.where((item) => item.code == code).firstOrNull;
      if (template == null || !template.available) {
        throw const FormatException('الگوی نقش معتبر نیست.');
      }
      final category = catalog.templateCategories
          .firstWhere((item) => item.code == template.category);
      if (!catalog.categories.any((item) => item.code == category.code)) {
        await _queue('category', category.code, {
          'code': category.code,
          'title': category.title,
          'style': category.style
        });
      }
      final role = ManagedRole(
          code: template.code,
          title: template.title,
          category: template.category,
          baseRoles: template.baseRoles);
      await _queue('role', code, {...role.toJson(), 'enabled': true});
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
      final catalog = await _remote.load();
      _check(epoch);
      final values = Map<String, dynamic>.from(draft['values'] as Map);
      if (draft['kind'] == 'category') {
        final found = catalog.categories.where((e) => e.code == draft['code']);
        if (found.isEmpty) {
          await _remote.createCategory(values['code'] as String,
              values['title'] as String, values['style'] as String);
        } else if (found.first.title != values['title'] ||
            found.first.style != values['style']) {
          throw const FormatException(
              'کد دسته روی سرور متفاوت است؛ پیش‌نویس را اصلاح کنید.');
        }
      } else if (draft['kind'] == 'template') {
        await _remote.applyTemplates([draft['code'] as String]);
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
        if (found.isEmpty || !same(found.first)) await _remote.save(role);
      }
      _check(epoch);
      final confirmed = await _remote.load();
      _check(epoch);
      _data['catalog'] = _encode(confirmed);
      _data['drafts'] = _drafts
          .where((e) =>
              !(e['kind'] == draft['kind'] && e['code'] == draft['code']))
          .toList();
      await _persist(epoch);
      // The draft is on the server now; a staged queue row for the same
      // write (queued while offline) must not replay it a second time.
      await _supersedeStaged(draft['kind'] as String, draft['code'] as String);
    }
    offline = false;
  }

  /// Import is staged atomically on this device; server sync remains explicit.
  Future<void> importRoles(List<ManagedRole> roles) async {
    await _identify(draftOnly: true);
    final epoch = _epoch;
    validateImport(roles);
    final previous = _data;
    _data = {
      ..._data,
      'drafts': [
        ..._drafts,
        for (final role in roles)
          {
            'kind': 'role',
            'code': role.code,
            'values': {...role.toJson(), 'enabled': role.enabled}
          }
      ]
    };
    try {
      await _persist(epoch);
    } catch (_) {
      if (_epoch == epoch) _data = previous;
      rethrow;
    }
  }

  void validateImport(List<ManagedRole> roles) {
    if (roles.isEmpty || roles.length > 500) {
      throw const FormatException('فایل باید بین ۱ تا ۵۰۰ نقش داشته باشد.');
    }
    final catalog = _view();
    final graph = {for (final role in catalog.roles) role.code: role.parent};
    final categories = catalog.categories.map((item) => item.code).toSet();
    final pattern = RegExp(r'^[A-Z][A-Z0-9_-]{1,39}$');
    for (final role in roles) {
      if (!pattern.hasMatch(role.code) || graph.containsKey(role.code)) {
        throw FormatException('کد نامعتبر یا تکراری: ${role.code}');
      }
      if (role.title.isEmpty ||
          role.title.length > 140 ||
          role.description.length > 2000 ||
          !categories.contains(role.category) ||
          role.baseRoles.isNotEmpty) {
        throw FormatException(
            'نام یا دسته نامعتبر برای نقش ${role.code}؛ دسته را ابتدا ایجاد کنید.');
      }
      graph[role.code] = role.parent;
    }
    for (final role in roles) {
      final seen = <String>{};
      var current = role.code;
      while (current.isNotEmpty) {
        if (!graph.containsKey(current) || !seen.add(current)) {
          throw FormatException('والد نامعتبر یا ارتباط حلقوی: ${role.code}');
        }
        current = graph[current]!;
      }
    }
  }

  Future<List<RolePermissionRow>> preview(List<String> roles) =>
      _remote.preview(roles);

  Future<void> discardDrafts() async {
    await _identify();
    final epoch = _epoch;
    // Require a successful authorized read before abandoning the working draft.
    final catalog = await _remote.load();
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
