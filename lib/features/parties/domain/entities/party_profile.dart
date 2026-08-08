import 'package:equatable/equatable.dart';

enum PartyKind { individual, organization }

enum PartyRole { customer, supplier, employee, shareholder, other }

class PartyProfile extends Equatable {
  const PartyProfile({
    this.id,
    this.company,
    required this.kind,
    required this.displayName,
    required this.roles,
    this.nationalId,
    this.mobile,
    this.phone,
    this.email,
    this.website,
    this.province,
    this.city,
    this.address,
    this.postalCode,
    this.bankName,
    this.iban,
    this.accountNumber,
    this.birthDate,
    this.employeeGender,
    this.dateOfJoining,
    this.fatherName,
    this.birthCertificateNumber,
    this.birthCertificateIssuePlace,
    this.employmentType,
    this.jobTitle,
    this.department,
    this.description,
    this.aliasName,
    this.managerName,
    this.registrationNumber,
    this.economicCode,
    this.foundingDate,
    this.secondaryPhone,
    this.creditLimit,
    this.openingBalance,
    this.balanceType,
    this.cardNumber,
    this.accountHolder,
    this.region,
    this.neighborhood,
    this.plaque,
    this.unit,
    this.latitude,
    this.longitude,
    this.employeeRoles = const {},
    this.detailGroups = const {},
    this.floatingDetails = const [],
    this.disabled = false,
  });

  final String? id, company;
  final PartyKind kind;
  final String displayName;
  final Set<PartyRole> roles;
  final String? nationalId, mobile, phone, email, website;
  final String? province, city, address, postalCode;
  final String? bankName, iban, accountNumber;
  final String? birthDate, employeeGender, dateOfJoining;
  final String? fatherName, birthCertificateNumber;
  final String? birthCertificateIssuePlace;
  final String? employmentType, jobTitle, department, description;
  final String? aliasName, managerName, registrationNumber, economicCode;
  final String? foundingDate, secondaryPhone;
  final double? creditLimit, openingBalance, latitude, longitude;
  final String? balanceType, cardNumber, accountHolder;
  final String? region, neighborhood, plaque, unit;
  final Set<String> employeeRoles;
  final Set<String> detailGroups;
  final List<FloatingDetail> floatingDetails;
  final bool disabled;

  @override
  List<Object?> get props => [
        id,
        company,
        kind,
        displayName,
        roles,
        nationalId,
        mobile,
        phone,
        email,
        website,
        province,
        city,
        address,
        postalCode,
        bankName,
        iban,
        accountNumber,
        birthDate,
        employeeGender,
        dateOfJoining,
        fatherName,
        birthCertificateNumber,
        birthCertificateIssuePlace,
        employmentType,
        jobTitle,
        department,
        description,
        aliasName,
        managerName,
        registrationNumber,
        economicCode,
        foundingDate,
        secondaryPhone,
        creditLimit,
        openingBalance,
        balanceType,
        cardNumber,
        accountHolder,
        region,
        neighborhood,
        plaque,
        unit,
        latitude,
        longitude,
        employeeRoles,
        detailGroups,
        floatingDetails,
        disabled,
      ];
}

class FloatingDetail extends Equatable {
  const FloatingDetail({
    required this.id,
    required this.code,
    required this.title,
    required this.type,
    required this.groupId,
    this.groupTitle,
    this.linkedDocument,
  });
  final String id, code, title, type, groupId;
  final String? groupTitle;
  final String? linkedDocument;
  @override
  List<Object?> get props =>
      [id, code, title, type, groupId, groupTitle, linkedDocument];
}
