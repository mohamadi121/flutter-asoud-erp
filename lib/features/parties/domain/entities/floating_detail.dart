import 'package:equatable/equatable.dart';

class FloatingDetail extends Equatable {
  const FloatingDetail({
    required this.id,
    required this.code,
    required this.title,
    required this.type,
    required this.groupCode,
  });

  final String id;
  final String code;
  final String title;
  final String type;
  final String groupCode;

  @override
  List<Object?> get props => [id, code, title, type, groupCode];
}
