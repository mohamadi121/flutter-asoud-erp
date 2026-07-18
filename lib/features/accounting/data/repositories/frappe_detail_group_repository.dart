import '../../../../core/network/frappe_client.dart';
import '../../domain/entities/detail_group.dart';
import '../../domain/repositories/detail_group_repository.dart';

class FrappeDetailGroupRepository implements DetailGroupRepository {
  const FrappeDetailGroupRepository(this._client);
  final FrappeApiClient _client;

  @override
  Future<List<DetailGroup>> getGroups() async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.detail_group.list_detail_groups',
    );
    return _parse(data);
  }

  @override
  Future<List<DetailGroup>> seedDefaults() async {
    await _client.callAsoudMethod(
      'asoud_erp.api.v1.detail_group.seed_default_detail_groups',
    );
    return getGroups();
  }

  @override
  Future<DetailGroup> saveGroup(
      {required String code, required String title}) async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.detail_group.save_detail_group',
      data: {'group_code': code, 'group_name': title},
    );
    if (data is! Map) {
      throw StateError('Invalid detail group response');
    }
    return _parse([data]).single;
  }

  List<DetailGroup> _parse(dynamic data) {
    if (data is! List) return const [];
    return data.whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      return DetailGroup(
        id: item['name']?.toString() ?? '',
        code: item['group_code']?.toString() ?? '',
        title: item['group_name']?.toString() ?? '',
        disabled: item['disabled'] == 1 || item['disabled'] == true,
      );
    }).toList(growable: false);
  }
}
