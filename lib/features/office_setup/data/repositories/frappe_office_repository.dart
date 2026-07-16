import '../../../../core/network/frappe_client.dart';
import '../../domain/entities/office.dart';
import '../../domain/repositories/office_repository.dart';
import '../models/office_model.dart';

class FrappeOfficeRepository implements OfficeRepository {
  const FrappeOfficeRepository(this._client);

  final FrappeClient _client;

  @override
  Future<Office> createOffice(Office office) async {
    final model = OfficeModel.fromEntity(office);
    final response = await _client.createResource('Company', model.toJson());
    final data = response['data'];
    return data is Map<String, dynamic> ? OfficeModel.fromJson(data) : model;
  }

  @override
  Future<Office> updateOffice(String id, Office office) async {
    final model = OfficeModel.fromEntity(office);
    final response = await _client.updateResource('Company', id, model.toJson());
    final data = response['data'];
    return data is Map<String, dynamic> ? OfficeModel.fromJson(data) : model;
  }
}

