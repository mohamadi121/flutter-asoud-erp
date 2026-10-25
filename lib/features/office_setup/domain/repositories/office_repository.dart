import '../entities/office.dart';

abstract interface class LocalPreviewOfficeRepository {
  bool get isLocalPreview;
}

/// Implemented by repositories that can call
/// `onboarding.create_first_office` (idempotent, administrator only).
abstract interface class FirstOfficeRepository {
  Future<Office> createFirstOffice(Office office);
}

abstract interface class OfficeRepository {
  Future<Office> createOffice(Office office);
  Future<Office> updateOffice(String id, Office office);
  Future<List<Office>> listOffices();
  Future<Office?> getDefaultOffice();
  Future<Office> setDefaultOffice(Office office);
}
