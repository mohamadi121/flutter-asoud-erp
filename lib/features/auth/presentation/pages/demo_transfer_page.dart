import 'package:flutter/material.dart';

import '../../../../core/offline/queued_offline_exception.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../data/demo_transfer_service.dart';

/// One-time page after signing in: moves rows the user created in the
/// offline demo to the server. Built-in sample rows are never listed.
class DemoTransferPage extends StatefulWidget {
  const DemoTransferPage({
    super.key,
    DemoTransferService? service,
    required this.submitRequest,
    required this.submitTemplate,
    this.onDone,
  }) : _service = service;

  final DemoTransferService? _service;

  /// Submits a preview request as a normal server write (queued by the
  /// repository when offline).
  final Future<void> Function(Map<String, dynamic> data) submitRequest;

  /// Submits a preview document template as a normal server write.
  final Future<void> Function(Map<String, dynamic> template) submitTemplate;

  /// Called when the page is finished; defaults to opening the dashboard
  /// with a cleared navigation stack.
  final VoidCallback? onDone;

  @override
  State<DemoTransferPage> createState() => _DemoTransferPageState();
}

class _DemoTransferPageState extends State<DemoTransferPage> {
  late final DemoTransferService _service =
      widget._service ?? DemoTransferService();
  List<DemoTransferItem>? _items;
  String? _busyId;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final items = await _service.listCandidates();
    if (mounted) setState(() => _items = items);
  }

  Future<void> _transfer(DemoTransferItem item) async {
    setState(() {
      _busyId = item.id;
      _error = null;
      _notice = null;
    });
    try {
      final queued = switch (item.kind) {
        DemoTransferKind.genericRequest => await _service
            .transferGenericRequest(item, submit: widget.submitRequest),
        DemoTransferKind.documentTemplate =>
          await _service.transferTemplate(item, submit: widget.submitTemplate),
        DemoTransferKind.workflowDesign =>
          throw StateError('این مورد قابل انتقال نیست.'),
      };
      // A queued write is safe on this device: say so instead of an error.
      if (queued && mounted) {
        setState(() => _notice = QueuedOfflineException.queuedFeedback);
      }
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _ignore(DemoTransferItem item) async {
    setState(() {
      _busyId = item.id;
      _error = null;
    });
    try {
      await _service.ignore(item);
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _finish() async {
    await DemoTransferService.markTransferSeen();
    if (!mounted) return;
    if (widget.onDone != null) {
      widget.onDone!();
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const DashboardLandingPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('انتقال داده‌های نسخه نمایشی')),
      body: SafeArea(
        child: items == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'این موارد را در نسخه نمایشی ساخته‌اید. هر کدام را به حساب سازمانی منتقل کنید یا نادیده بگیرید.',
                    style: TextStyle(fontSize: 12, color: AsoudColors.muted),
                  ),
                  const SizedBox(height: 12),
                  if (_notice != null)
                    Text(_notice!,
                        style: const TextStyle(color: AsoudColors.primary)),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  for (final item in items) _card(item),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'موردی برای انتقال نیست.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _busyId == null ? _finish : null,
                      child: Text(items.isEmpty ? 'ورود به حساب' : 'اتمام'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _card(DemoTransferItem item) {
    final busy = _busyId == item.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: Text(item.title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AsoudColors.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Text(item.kindLabel, style: const TextStyle(fontSize: 10)),
              ),
            ]),
            if (item.subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(item.subtitle,
                  style:
                      const TextStyle(fontSize: 11, color: AsoudColors.muted)),
            ],
            const SizedBox(height: 8),
            if (!item.transferable) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AsoudColors.warning.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'قابل انتقال نیست — ${item.nonTransferReason ?? ''}',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: busy ? null : () => _ignore(item),
                child: const Text('نادیده گرفتن'),
              ),
            ] else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: busy ? null : () => _transfer(item),
                    child: Text(busy ? 'در حال انتقال…' : 'انتقال به سرور'),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : () => _ignore(item),
                    child: const Text('نادیده گرفتن'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
