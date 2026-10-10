import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/offline/offline_sync_service.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';

/// A full-width, tappable status bar: how many writes are still on this phone,
/// whether the queue is running, and that nothing is left when the count
/// reaches zero. It is the home entry point to «صف ارسال به سرور».
class SyncStatusIndicator extends StatefulWidget {
  const SyncStatusIndicator({required this.service, this.onOpen, super.key});

  final OfflineSyncService service;

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

  @override
  void initState() {
    super.initState();
    _changes = widget.service.changes.listen((_) => unawaited(_refresh()));
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    // Read the flag before the count: a run that finishes meanwhile is still a
    // run the user is waiting for.
    final syncing = widget.service.isSyncing;
    int? unsent;
    int localOnly;
    try {
      unsent = await widget.service.unsentCount();
      localOnly = await widget.service.localOnlyCount();
    } catch (_) {
      // The queue store is unavailable; the badge stays hidden rather than
      // claiming the phone holds nothing.
      return;
    }
    if (!mounted) return;
    setState(() {
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
    final color = clear ? AsoudColors.success : AsoudColors.warning;
    final surface =
        clear ? AsoudColors.successSurface : AsoudColors.warningSurface;
    final label = clear
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
            if (!clear && widget.onOpen != null)
              Icon(Icons.chevron_left_rounded, size: 20, color: color),
          ]),
        ),
      ),
    );
    return Directionality(textDirection: TextDirection.rtl, child: bar);
  }
}
