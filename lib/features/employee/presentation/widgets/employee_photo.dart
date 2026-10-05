import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../hr/data/personnel_repository.dart';

class EmployeePhoto extends StatefulWidget {
  const EmployeePhoto({required this.name, this.recordId, super.key});
  final String name;
  final String? recordId;
  @override
  State<EmployeePhoto> createState() => _EmployeePhotoState();
}

class _EmployeePhotoState extends State<EmployeePhoto> {
  Future<Map<String, dynamic>>? photo;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.recordId?.isNotEmpty == true) {
      photo ??= PersonnelRepository(context.read<FrappeApiClient>())
          .record(widget.recordId!);
    }
  }

  @override
  void didUpdateWidget(covariant EmployeePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recordId != widget.recordId) {
      photo = widget.recordId?.isNotEmpty == true
          ? PersonnelRepository(context.read<FrappeApiClient>())
              .record(widget.recordId!)
          : null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: photo,
        builder: (_, snapshot) {
          Widget fallback() => CircleAvatar(
              radius: 28,
              child: Text(widget.name.trim().isEmpty
                  ? '؟'
                  : widget.name.trim().characters.first));
          final data = snapshot.data?['file'];
          if (data is! String || data.isEmpty) return fallback();
          try {
            return ClipOval(
                child: Image.memory(base64Decode(data),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => fallback()));
          } on FormatException {
            return fallback();
          }
        },
      );
}
