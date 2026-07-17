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
  });

  final String name;
  final OfficeType type;
  final DateTime fiscalYearStart;
  final String? nationalId;
  final String? economicCode;
  final bool generateDetailCode;

  @override
  List<Object?> get props => [
        name,
        type,
        fiscalYearStart,
        nationalId,
        economicCode,
        generateDetailCode,
      ];
}
