import 'package:flutter/material.dart';

import '../../form_repository.dart';
import '../editor_widgets.dart';

class FormSpecCard extends StatelessWidget {
  const FormSpecCard({
    required this.schema,
    required this.record,
    this.onEdit,
    super.key,
  });

  final FormMap schema;
  final FormMap record;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final title = (schema['title']?.toString().trim().isNotEmpty ?? false)
        ? '${schema['title']}'
        : 'درخواست معرفی تأمین‌کننده';
    final moduleKey = '${schema['module'] ?? 'Purchase'}';
    final moduleName = formModules[moduleKey] ?? moduleKey;
    final isDocument = schema['kind'] == 'Document';
    final kindName = isDocument ? 'فرم سند' : 'فرم درخواست';
    final isPublished =
        record['status'] == 'Published' || schema['status'] == 'Published';
    final statusText = isPublished ? 'منتشرشده' : 'پیش‌نویس';

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Right: Edit icon box (RTL start)
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: const Icon(
                Icons.edit_outlined,
                size: 20,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 10),
            // Middle: Title and Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$moduleName • $kindName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Status badge on the left (RTL end)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isPublished
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isPublished
                      ? const Color(0xFFA7F3D0)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isPublished
                      ? const Color(0xFF047857)
                      : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
