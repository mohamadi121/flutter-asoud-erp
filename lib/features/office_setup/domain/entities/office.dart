import 'package:equatable/equatable.dart';

enum OfficeType { personal, legal }

class Office extends Equatable {
  const Office({
    required this.name,
    required this.type,
    required this.fiscalYearStart,
    this.nationalId,
    this.economicCode,
    this.generateDetailCode = true,
    this.ownerFullName,
    this.registrationNumber,
    this.activityType,
    this.companyType,
    this.parentOffice,
    this.phone,
    this.email,
    this.website,
    this.province,
    this.city,
    this.address,
    this.postalCode,
    this.fiscalYear,
    this.chartTemplate,
    this.description,
    this.lastSyncedAt,
  });

  final String name;
  final OfficeType type;
  final DateTime fiscalYearStart;
  final String? nationalId;
  final String? economicCode;
  final bool generateDetailCode;
  final String? ownerFullName;
  final String? registrationNumber;
  final String? activityType;
  final String? companyType;
  final String? parentOffice;
  final String? phone, email, website, province, city, address, postalCode;
  final String? fiscalYear, chartTemplate, description;
  final DateTime? lastSyncedAt;

  @override
  List<Object?> get props => [
        name,
        type,
        fiscalYearStart,
        nationalId,
        economicCode,
        generateDetailCode,
        ownerFullName,
        registrationNumber,
        activityType,
        companyType,
        parentOffice,
        phone,
        email,
        website,
        province,
        city,
        address,
        postalCode,
        fiscalYear,
        chartTemplate,
        description,
        lastSyncedAt,
      ];
}
