import '../entities/detail_group.dart';

abstract interface class DetailGroupRepository {
  Future<List<DetailGroup>> getGroups();
  Future<List<DetailGroup>> seedDefaults();
  Future<DetailGroup> saveGroup({required String code, required String title});
}
