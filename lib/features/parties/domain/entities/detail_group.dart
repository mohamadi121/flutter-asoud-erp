import 'package:equatable/equatable.dart';

class DetailGroup extends Equatable {
  const DetailGroup({required this.code, required this.title});

  final String code;
  final String title;

  @override
  List<Object?> get props => [code, title];
}
