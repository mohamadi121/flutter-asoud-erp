import 'dart:async';
import 'dart:convert';

import '../../../core/network/frappe_client.dart';
import '../../../core/offline/local_database_store.dart';
import '../../../core/offline/offline_failure.dart';
import '../domain/personnel_file.dart';

class PersonnelFileRepository {
  PersonnelFileRepository(this.client, {LocalRecordStore? store})
      : store = store ?? LocalDatabaseStore.instance;

  final FrappeApiClient client;
  final LocalRecordStore store;

  String get _server => client is FrappeClient
      ? (client as FrappeClient).serverIdentity
      : 'test-client';

  Future<dynamic> _remote(String method, Map<String, dynamic> data) => client
      .callAsoudMethod('asoud_erp.api.v1.personnel_file.$method', data: data)
      .timeout(const Duration(seconds: 20));

  Future<dynamic> _read(String method, Map<String, dynamic> data) async {
    var sessionChanged = false;
    final server = _server;
    final session = client.authenticationChanges.listen((_) {
      sessionChanged = true;
    });
    void checkSession() {
      if (sessionChanged || !client.isAuthenticated || server != _server) {
        throw StateError('نشست کاربر تغییر کرده است.');
      }
    }

    try {
      final user = await client.getCurrentUser();
      checkSession();
      final scope = jsonEncode([server, user.userId, method, data]);
      final id = 'personnel-file:${Uri.encodeComponent(scope)}';
      dynamic result;
      try {
        result = await _remote(method, data);
      } catch (error) {
        if (error is! TimeoutException && !isRetryableOfflineFailure(error)) {
          rethrow;
        }
        checkSession();
        final cached = await store.get(id);
        checkSession();
        if (cached == null) rethrow;
        return cached.payload['value'];
      }
      checkSession();
      await store.save(
          id: id,
          entityType: 'personnel_file_cache',
          payload: {'value': result});
      checkSession();
      return result;
    } finally {
      await session.cancel();
    }
  }

  Future<PersonnelFile> file(String profileId) async =>
      PersonnelFile.fromJson(Map<String, dynamic>.from(
          await _read('get_personnel_file', {'name': profileId}) as Map));

  Future<PersonnelFile> myFile() async =>
      PersonnelFile.fromJson(Map<String, dynamic>.from(
          await _read('get_my_personnel_file', {}) as Map));

  Future<EmployeeHome> myHome() async => EmployeeHome.fromJson(
      Map<String, dynamic>.from(await _read('get_my_home', {}) as Map));

  Future<List<Announcement>> announcements() async =>
      (await _read('list_announcements', {}) as List)
          .map((row) =>
              Announcement.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();

  Future<({String filename, String contentBase64})> contractFile(
      String contract) async {
    final result = Map<String, dynamic>.from(
        await _remote('get_contract_file', {'contract': contract}) as Map);
    return (
      filename: result['filename']?.toString() ?? '',
      contentBase64: result['content_base64']?.toString() ?? '',
    );
  }

  Future<List<ContractSummary>> saveContract({
    required String profileId,
    required String startDate,
    required String terms,
    String? endDate,
    String? contract,
    bool isSigned = false,
    String? fileBase64,
    String? filename,
    bool submit = false,
  }) async =>
      (await _remote('save_contract', {
        'name': profileId,
        'start_date': startDate,
        'terms': terms,
        if (endDate != null) 'end_date': endDate,
        if (contract != null) 'contract': contract,
        'is_signed': isSigned ? 1 : 0,
        if (fileBase64 != null) 'file': fileBase64,
        if (filename != null) 'filename': filename,
        'submit': submit ? 1 : 0,
      }) as List)
          .map((row) =>
              ContractSummary.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();

  Future<void> addPromotion({
    required String profileId,
    required String promotionDate,
    String? designation,
    String? department,
    String? branch,
    String? remarks,
  }) async {
    await _remote('add_promotion', {
      'name': profileId,
      'promotion_date': promotionDate,
      if (designation != null) 'designation': designation,
      if (department != null) 'department': department,
      if (branch != null) 'branch': branch,
      if (remarks != null) 'remarks': remarks,
    });
  }

  Future<void> createAnnouncement({
    required String title,
    required String content,
    String? expireOn,
  }) async {
    await _remote('create_announcement', {
      'title': title,
      'content': content,
      if (expireOn != null) 'expire_on': expireOn,
    });
  }
}
