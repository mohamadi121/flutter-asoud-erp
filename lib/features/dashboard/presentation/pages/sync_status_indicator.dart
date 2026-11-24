import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/offline/offline_sync_service.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';

/// A full-width, tappable status bar: how many writes are still on this phone,
/// whether the queue is running, and that nothing is left when the count
/// reaches zero. It is the home entry point to «صف ارسال به سرور».
class SyncStatusIndicator extends StatefulWidget {
  const SyncStatusIndicator({required this.service, this.onOpen, this.hideWhenClear = false, super.key});

  final OfflineSyncService service;
  final bool hideWhenClear;

  /// Opens «صف ارسال به سرور»; the bar is inert without it.
  final VoidCallback? onOpen;

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator> {
  StreamSubscription<void>? _changes;
  int? _unsent;
  int _localOnly = 0;
  bool _syncing = false;
  bool _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _changes = widget.service.changes.listen((_) => unawaited(_refresh()));
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    // Read the flag before the count: a run that finishes meanwhile is still a
    // run the user is waiting for.
    final token = ++_generation;
    final syncing = widget.service.isSyncing;
    int? unsent;
    int localOnly;
    bool failed;
    try {
      final rows = await widget.service.unsent();
      unsent = rows.length;
      failed = rows.any((r) => r.lastError?.isNotEmpty == true);
      localOnly = await widget.service.localOnlyCount();
    } catch (_) {
      // The queue store is unavailable; the badge stays hidden rather than
      // claiming the phone holds nothing.
      return;
    }
    if (!mounted || token != _generation) return;
    setState(() {
      _failed = failed;
      _unsent = unsent;
      _localOnly = localOnly;
      _syncing = syncing || widget.service.isSyncing;
    });
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unsent = _unsent;
    if (unsent == null) return const SizedBox.shrink();
    final clear = unsent == 0 && _localOnly == 0;
    if (clear && !_syncing && widget.hideWhenClear) return const SizedBox.shrink();
    final color = _failed ? AsoudColors.danger : const Color(0xFF2878DE);
    final surface = _failed ? const Color(0xFFFCE7EA) : const Color(0xFFEAF3FF);
    final label = _syncing ? 'در حال همگام‌سازی…' : _failed
        ? 'ارسال برخی تغییرات انجام نشد' : clear
        ? 'همه داده‌ها ارسال شده'
        : unsent > 0
            ? '${toPersianDigits(unsent)} تغییر ارسال نشد — مشاهده'
            : '${toPersianDigits(_localOnly)} داده روی گوشی';
    final bar = Material(
      color: surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: widget.onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            if (_syncing)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: AsoudColors.primary),
              )
            else
              Icon(
                  clear
                      ? Icons.check_circle_rounded
                      : Icons.cloud_upload_outlined,
                  size: 22,
                  color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: color),
              ),
            ),
            if (_failed && !_syncing)
              TextButton(onPressed: () async {
                try {
                  await widget.service.retryAll();
                } catch (_) {
                  if (mounted) setState(() => _failed = true);
                } finally {
                  if (mounted) await _refresh();
                }
              }, child: const Text('تلاش مجدد')),
            if (!clear && widget.onOpen != null)
              Icon(Icons.chevron_left_rounded, size: 20, color: color),
          ]),
        ),
      ),
    );
    return Directionality(textDirection: TextDirection.rtl, child: bar);
  }
}
