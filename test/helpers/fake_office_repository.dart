import 'package:asoud_erp/features/office_setup/domain/entities/office.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';

class FakeOfficeRepository implements OfficeRepository {
  FakeOfficeRepository(
      {this.offices = const [], this.defaultOffice, this.error});

  final List<Office> offices;
  final Office? defaultOffice;
  final Object? error;

  @override
  Future<Office> createOffice(Office office) async {
    if (error != null) throw error!;
    return office;
  }

  @override
  Future<Office?> getDefaultOffice() async {
    if (error != null) throw error!;
    return defaultOffice;
  }

  @override
  Future<List<Office>> listOffices() async {
    if (error != null) throw error!;
    return offices;
  }

  @override
  Future<Office> updateOffice(String id, Office office) async {
    if (error != null) throw error!;
    return office;
  }
}
