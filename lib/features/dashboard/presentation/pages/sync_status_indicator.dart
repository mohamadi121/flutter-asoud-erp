import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/offline/offline_sync_service.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';

/// A small app-bar badge: how many writes are still on this phone, whether the
/// queue is running, and that nothing is left when the count reaches zero.
class SyncStatusIndicator extends StatefulWidget {
  const SyncStatusIndicator({required this.service, this.onOpen, super.key});

  final OfflineSyncService service;

  /// Opens «صف ارسال به سرور»; the badge is inert without it.
  final VoidCallback? onOpen;

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator> {
  StreamSubscription<void>? _changes;
  int? _unsent;
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
    try {
      unsent = await widget.service.unsentCount();
    } catch (_) {
      // The queue store is unavailable; the badge stays hidden rather than
      // claiming the phone holds nothing.
      return;
    }
    if (!mounted) return;
    setState(() {
      _unsent = unsent;
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
    final clear = unsent == 0;
    final color = clear ? AsoudColors.success : AsoudColors.warning;
    final label = clear
        ? 'همه داده‌ها ارسال شده'
        : '${toPersianDigits(unsent)} نوشته ارسال نشده';
    final badge = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (_syncing)
              const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AsoudColors.primary),
              )
            else
              Icon(
                  clear
                      ? Icons.check_circle_rounded
                      : Icons.cloud_upload_outlined,
                  size: 17,
                  color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800, color: color),
              ),
            ),
          ]),
        ),
      ),
    );
    return Directionality(textDirection: TextDirection.rtl, child: badge);
  }
}
