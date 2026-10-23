import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../data/generic_request_repository.dart';
import '../../domain/entities/request_models.dart';
import 'request_attachments.dart';

/// «گواهی صادرشده»: the issued employment certificate with «دانلود گواهی».
/// Built only when `get_request.certificate` is present, which the server
/// sends to the requester, HR managers and System managers alone.
class RequestCertificateCard extends StatefulWidget {
  const RequestCertificateCard({
    required this.certificate,
    required this.requestName,
    required this.repository,
    required this.saver,
    this.onMessage,
    super.key,
  });

  final RequestCertificate certificate;
  final String requestName;
  final GenericRequestRepository repository;
  final RequestFileSaver saver;
  final ValueChanged<String>? onMessage;

  @override
  State<RequestCertificateCard> createState() => _RequestCertificateCardState();
}

class _RequestCertificateCardState extends State<RequestCertificateCard> {
  bool _running = false;

  void _say(String text) {
    if (widget.onMessage != null) return widget.onMessage!(text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _download() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      final file = await widget.repository.certificate(widget.requestName);
      await widget.saver(file.filename, file.bytes);
    } on ApiException catch (error) {
      // A validation answer carries the server's own Persian sentence.
      _say(error.kind == ApiFailureKind.validation && error.message.isNotEmpty
          ? error.message
          : failureMessage(error));
    } catch (_) {
      _say('دریافت گواهی ممکن نشد.');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final issued = widget.certificate.issuedOn;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AsoudColors.primary.withValues(alpha: 0.06),
        border: Border.all(color: AsoudColors.primary.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.workspace_premium_outlined,
              size: 18, color: AsoudColors.primary),
          SizedBox(width: 6),
          Expanded(
            child: Text('گواهی صادرشده',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AsoudColors.primary)),
          ),
        ]),
        const SizedBox(height: 4),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text('شماره گواهی: ${widget.certificate.number}',
              style: const TextStyle(fontSize: 13, height: 1.7)),
        ),
        if (issued.isNotEmpty)
          Text('تاریخ صدور: ${formatJalaliDateTimeIso(issued)}',
              style:
                  const TextStyle(fontSize: 12, color: AsoudColors.muted)),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _running ? null : _download,
          icon: const Icon(Icons.file_download_outlined, size: 18),
          label: Text(_running ? 'در حال دریافت…' : 'دانلود گواهی'),
        ),
      ]),
    );
  }
}
