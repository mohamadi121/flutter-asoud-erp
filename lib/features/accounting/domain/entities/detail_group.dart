import 'package:equatable/equatable.dart';

class DetailGroup extends Equatable {
  const DetailGroup({
    required this.id,
    required this.code,
    required this.title,
    this.disabled = false,
  });

  final String id;
  final String code;
  final String title;
  final bool disabled;

  @override
  List<Object?> get props => [id, code, title, disabled];
}
