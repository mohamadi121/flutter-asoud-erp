import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../data/generic_request_repository.dart';
import '../../domain/entities/request_models.dart';
import 'request_form_controller.dart';

/// Saves downloaded bytes where the user chooses.
typedef RequestFileSaver = Future<void> Function(
    String filename, Uint8List bytes);

/// Opens the system file picker for the file types of [limits].
Future<List<RequestPickedFile>> pickRequestFiles(
    RequestAttachmentLimits limits) async {
  final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: limits.pickerExtensions);
  if (result == null) return const [];
  return [
    for (final file in result.files)
      if (file.bytes != null) (filename: file.name, bytes: file.bytes!)
  ];
}

Future<void> saveRequestFile(String filename, Uint8List bytes) async {
  await FilePicker.platform.saveFile(fileName: filename, bytes: bytes);
}

/// «۱٫۲ مگابایت», «۱۸ کیلوبایت».
String formatFileSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${formatPersianNumber(double.parse((bytes / 1048576).toStringAsFixed(1)))} مگابایت';
  }
  if (bytes >= 1024) {
    return '${toPersianDigits((bytes / 1024).ceil())} کیلوبایت';
  }
  return '${toPersianDigits(bytes)} بایت';
}

/// The icon and color of a file by its name.
(IconData, Color) requestFileIcon(String filename, {bool image = false}) {
  final lower = filename.toLowerCase();
  if (image || RegExp(r'\.(png|jpe?g|gif|webp)$').hasMatch(lower)) {
    return (Icons.image_outlined, AsoudColors.primary);
  }
  if (lower.endsWith('.pdf')) {
    return (Icons.picture_as_pdf_rounded, AsoudColors.danger);
  }
  if (RegExp(r'\.xlsx?$').hasMatch(lower)) {
    return (Icons.table_chart_outlined, AsoudColors.success);
  }
  if (RegExp(r'\.docx?$').hasMatch(lower)) {
    return (Icons.description_outlined, AsoudColors.primary);
  }
  return (Icons.insert_drive_file_outlined, AsoudColors.warning);
}

/// A downscaled preview of a request image (`attachment(name, thumbnail:
/// true)`), or the file icon for other files, samples and files that are still
/// on this device.
class RequestAttachmentThumbnail extends StatefulWidget {
  const RequestAttachmentThumbnail(
      {required this.attachment,
      required this.repository,
      this.size = 44,
      super.key});
  final RequestAttachment attachment;
  final GenericRequestRepository repository;
  final double size;

  @override
  State<RequestAttachmentThumbnail> createState() =>
      _RequestAttachmentThumbnailState();
}

class _RequestAttachmentThumbnailState
    extends State<RequestAttachmentThumbnail> {
  Future<Uint8List?>? bytes;

  bool get _fetchable =>
      widget.attachment.isImage &&
      !widget.attachment.isSample &&
      widget.attachment.name.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_fetchable) {
      bytes = widget.repository
          .attachment(widget.attachment.name, thumbnail: true)
          .then<Uint8List?>((file) => file.bytes)
          .catchError((Object _) => null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = requestFileIcon(widget.attachment.filename,
        image: widget.attachment.isImage);
    Widget fallback() =>
        AsoudIconBox(icon: icon, color: color, size: widget.size);
    if (bytes == null) return fallback();
    return FutureBuilder<Uint8List?>(
      future: bytes,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return fallback();
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(data,
              key: ValueKey('thumb:${widget.attachment.name}'),
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback()),
        );
      },
    );
  }
}

/// A file of a request: icon or thumbnail, name, size and a download button
/// (`attachment(name)` then the platform save dialog).
class RequestAttachmentTile extends StatelessWidget {
  const RequestAttachmentTile({
    required this.attachment,
    required this.repository,
    this.saver = saveRequestFile,
    this.onMessage,
    super.key,
  });
  final RequestAttachment attachment;
  final GenericRequestRepository repository;
  final RequestFileSaver saver;

  /// Receives user-facing messages (download failed, sample file); defaults to
  /// a snack bar.
  final ValueChanged<String>? onMessage;

  Future<void> _download(BuildContext context) async {
    void say(String text) {
      if (onMessage != null) return onMessage!(text);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(text)));
      }
    }

    if (attachment.isSample) {
      return say('فایل نمایشی فقط برای مشاهده است و دانلود نمی‌شود.');
    }
    if (attachment.name.isEmpty) {
      return say('این فایل هنوز روی گوشی است و پس از ارسال قابل دریافت است.');
    }
    try {
      final file = await repository.attachment(attachment.name);
      await saver(file.filename, file.bytes);
    } catch (_) {
      say('دریافت فایل ممکن نشد.');
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            border: Border.all(color: AsoudColors.border),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          RequestAttachmentThumbnail(
              attachment: attachment, repository: repository),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(attachment.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
                if (attachment.size > 0)
                  Text(formatFileSize(attachment.size),
                      style: const TextStyle(
                          fontSize: 10, color: AsoudColors.muted)),
              ])),
          IconButton(
              tooltip: 'دریافت فایل',
              onPressed: () => _download(context),
              icon: const Icon(Icons.file_download_outlined,
                  color: AsoudColors.primary)),
        ]),
      );
}

/// «پیوست‌ها» of a form: the drop zone with the type's limits, the files
/// added now (general ones) and, when editing, the files already on the
/// request. Files are added to and removed from the [controller].
class RequestAttachmentsPicker extends StatelessWidget {
  const RequestAttachmentsPicker(
      {required this.controller,
      this.enabled = true,
      this.picker,
      this.onMessage,
      super.key});
  final RequestFormController controller;
  final bool enabled;

  /// Defaults to `controller.filePicker`, then [pickRequestFiles].
  final RequestFilePicker? picker;

  /// Receives limit errors; defaults to a snack bar.
  final ValueChanged<String>? onMessage;

  Future<void> _pick(BuildContext context) async {
    final files = await (picker ??
        controller.filePicker ??
        pickRequestFiles)(controller.limits);
    for (final file in files) {
      try {
        controller.addAttachment(filename: file.filename, bytes: file.bytes);
      } on RequestAttachmentException catch (error) {
        if (onMessage != null) {
          onMessage!(error.message);
        } else if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.message)));
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final limits = controller.limits;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  key: const ValueKey('request-attachments-dropzone'),
                  onTap: enabled ? () => _pick(context) : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                        color: AsoudColors.primary.withValues(alpha: .04),
                        border: Border.all(
                            color: AsoudColors.primary.withValues(alpha: .35)),
                        borderRadius: BorderRadius.circular(14)),
                    child: Column(children: [
                      const AsoudIconBox(
                          icon: Icons.cloud_upload_outlined,
                          color: AsoudColors.primary,
                          size: 44),
                      const SizedBox(height: 8),
                      const Text('فایل یا فایل‌ها را انتخاب کنید',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Tooltip(
                        message: 'فرمت‌های مجاز: ${limits.extensionsLabel}',
                        child: Text('فرمت‌های مجاز: ${limits.extensionsLabel}',
                            textAlign: TextAlign.center,
                            softWrap: true,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: AsoudColors.muted)),
                      ),
                      Text(
                          'حداکثر حجم هر فایل: ${toPersianDigits(limits.maxMb)} مگابایت',
                          style: const TextStyle(
                              fontSize: 11, color: AsoudColors.muted)),
                    ]),
                  ),
                ),
                for (final file in controller.keptExistingAttachments
                    .where((file) => file.isGeneral))
                  _FileRow(
                      filename: file.filename,
                      subtitle: formatFileSize(file.size),
                      onRemove: enabled
                          ? () => controller.removeExistingAttachment(file.name)
                          : null),
                for (final draft in controller.generalDrafts)
                  _FileRow(
                      key: ValueKey('draft:${draft.ref}'),
                      filename: draft.filename,
                      subtitle: formatFileSize(draft.size),
                      bytes: draft.isImage ? draft.bytes : null,
                      onRemove: enabled
                          ? () => controller.removeAttachment(draft.ref)
                          : null),
              ]);
        },
      );
}

class _FileRow extends StatelessWidget {
  const _FileRow(
      {required this.filename,
      required this.subtitle,
      this.bytes,
      this.onRemove,
      super.key});
  final String filename, subtitle;
  final Uint8List? bytes;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = requestFileIcon(filename);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: bytes != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(bytes!,
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      AsoudIconBox(icon: icon, color: color, size: 38)))
          : AsoudIconBox(icon: icon, color: color, size: 38),
      title: Text(filename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 10)),
      trailing: IconButton(
          tooltip: 'حذف فایل',
          icon: const Icon(Icons.close),
          onPressed: onRemove),
    );
  }
}
