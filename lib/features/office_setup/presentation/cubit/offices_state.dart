part of 'offices_cubit.dart';

enum OfficesStatus { loading, success, empty, error }

class OfficesState extends Equatable {
  const OfficesState({
    this.status = OfficesStatus.loading,
    this.offices = const [],
    this.defaultOffice,
    this.query = '',
    this.message,
    this.showCreatedBanner = false,
    this.offlinePreview = false,
    this.changingDefault = false,
  });

  final OfficesStatus status;
  final List<Office> offices;
  final Office? defaultOffice;
  final String query;
  final String? message;
  final bool showCreatedBanner;
  final bool offlinePreview;
  final bool changingDefault;

  List<Office> get filteredOffices {
    final normalized = query.trim().toLowerCase();
    return offices
        .where((office) => office != defaultOffice)
        .where((office) =>
            normalized.isEmpty ||
            office.name.toLowerCase().contains(normalized))
        .toList(growable: false);
  }

  OfficesState copyWith({
    OfficesStatus? status,
    List<Office>? offices,
    Office? defaultOffice,
    String? query,
    String? message,
    bool? showCreatedBanner,
    bool? offlinePreview,
    bool? changingDefault,
    bool clearMessage = false,
  }) =>
      OfficesState(
        status: status ?? this.status,
        offices: offices ?? this.offices,
        defaultOffice: defaultOffice ?? this.defaultOffice,
        query: query ?? this.query,
        message: clearMessage ? null : message ?? this.message,
        showCreatedBanner: showCreatedBanner ?? this.showCreatedBanner,
        offlinePreview: offlinePreview ?? this.offlinePreview,
        changingDefault: changingDefault ?? this.changingDefault,
      );

  @override
  List<Object?> get props => [
        status,
        offices,
        defaultOffice,
        query,
        message,
        showCreatedBanner,
        offlinePreview,
        changingDefault,
      ];
}
