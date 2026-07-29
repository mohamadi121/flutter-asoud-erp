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
    this.employmentType,
    this.jobTitle,
    this.department,
    this.description,
  });

  final String? id, company;
  final PartyKind kind;
  final String displayName;
  final Set<PartyRole> roles;
  final String? nationalId, mobile, phone, email, website;
  final String? province, city, address, postalCode;
  final String? bankName, iban, accountNumber;
  final String? birthDate, employmentType, jobTitle, department, description;

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
        employmentType,
        jobTitle,
        department,
        description,
      ];
}

class FloatingDetail extends Equatable {
  const FloatingDetail({
    required this.id,
    required this.code,
    required this.title,
    required this.type,
    required this.groupId,
  });
  final String id, code, title, type, groupId;
  @override
  List<Object?> get props => [id, code, title, type, groupId];
}
