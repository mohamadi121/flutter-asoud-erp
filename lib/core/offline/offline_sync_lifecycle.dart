import 'dart:async';

import 'package:flutter/widgets.dart';

import 'offline_sync_service.dart';

class OfflineSyncLifecycle extends StatefulWidget {
  const OfflineSyncLifecycle({
    required this.service,
    required this.child,
    this.interval = const Duration(seconds: 30),
    super.key,
  });

  final OfflineSyncService service;
  final Widget child;
  final Duration interval;

  @override
  State<OfflineSyncLifecycle> createState() => _OfflineSyncLifecycleState();
}

class _OfflineSyncLifecycleState extends State<OfflineSyncLifecycle>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    _timer = Timer.periodic(widget.interval, (_) => _sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  void _sync() => unawaited(_syncSafely());

  Future<void> _syncSafely() async {
    try {
      await widget.service.syncNow();
    } catch (_) {
      // A later lifecycle or periodic attempt retries initialization failures.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
