import '../entities/office.dart';

abstract interface class LocalPreviewOfficeRepository {
  bool get isLocalPreview;
}

abstract interface class OfficeRepository {
  Future<Office> createOffice(Office office);
  Future<Office> updateOffice(String id, Office office);
  Future<List<Office>> listOffices();
  Future<Office?> getDefaultOffice();
  Future<Office> setDefaultOffice(Office office);
}
