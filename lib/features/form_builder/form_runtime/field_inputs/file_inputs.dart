import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/offline/offline_failure.dart';
import '../../form_repository.dart';

Widget? buildFileInput({
  required BuildContext context,
  required FormMap f,
  required dynamic value,
  required String label,
  required FormRepository repository,
  required String? formName,
  required ValueChanged<dynamic> onChanged,
  bool enabled = true,
}) {
  final type = '${f['type']}';
  if (!['File', 'Image', 'Signature'].contains(type)) {
    return null;
  }
  final policy = repository is FormAttachmentPolicy ? repository as FormAttachmentPolicy : null;

  return Column(
    children: [
      Material(
        color: Colors.transparent,
        child: ListTile(
          title: Text(label),
          subtitle: Text(policy?.fileLabel(value) ?? '${value ?? 'فایل انتخاب نشده'}'),
          trailing: value == null
              ? null
              : IconButton(
                  onPressed: enabled ? () => onChanged(null) : null,
                  icon: const Icon(Icons.close),
                ),
        ),
      ),
      if (enabled && policy?.allowUploads != false) OutlinedButton.icon(
        icon: const Icon(Icons.attach_file),
        label: const Text('انتخاب فایل خصوصی'),
        onPressed: !enabled || policy?.allowUploads == false ? null : () async {
          try {
            final maxFiles = (f['max_files'] as num?)?.toInt() ?? 1;
            final result = await FilePicker.platform.pickFiles(
              withData: true,
              allowMultiple: maxFiles > 1,
              type: FileType.custom,
              allowedExtensions: (f['extensions'] as List? ??
                      (type == 'File'
                          ? ['pdf', 'jpg', 'png']
                          : ['jpg', 'jpeg', 'png']))
                  .cast<String>(),
            );
            if (result == null || result.files.any((file) => file.bytes == null)) {
              return;
            }
            if (result.files.length > maxFiles ||
                result.files.fold<int>(0, (size, file) => size + file.size) >
                    25 * 1024 * 1024) {
              throw StateError('تعداد یا مجموع حجم فایل‌ها بیش از حد مجاز است.');
            }
            if (result.files.any((file) =>
                file.size > ((f['max_mb'] as num?) ?? 10) * 1024 * 1024)) {
              throw StateError('حجم فایل بیش از حد مجاز است.');
            }
            final names = <String>[
              if (policy?.appendUploads == true && maxFiles > 1)
                ...(value is List ? value : value == null ? [] : [value]).map((name) => '$name'),
            ];
            for (final file in result.files) {
              if (formName == null) {
                names.add('پیش‌نمایش محلی: ${file.name}');
                continue;
              }
              final uploaded = formMap(
                await repository.call('upload_file', {
                  'form': formName,
                  'filename': file.name,
                  'content': base64Encode(file.bytes!),
                }),
              );
              names.add('${uploaded['name']}');
            }
            if (context.mounted) {
              if (names.toSet().length > maxFiles) throw StateError('تعداد مجموع پیوست‌ها بیش از حد مجاز است.');
              onChanged(maxFiles > 1 ? names : names.single);
            }
          } catch (error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(offlineFailureMessage(error))),
              );
            }
          }
        },
      ),
    ],
  );
}
