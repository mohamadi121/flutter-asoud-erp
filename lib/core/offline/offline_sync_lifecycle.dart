import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import 'offline_sync_service.dart';

/// Drives the offline queue from the app: the first frame, a periodic timer,
/// returning from the background and — the fast path — the moment the network
/// comes back.
class OfflineSyncLifecycle extends StatefulWidget {
  const OfflineSyncLifecycle({
    required this.service,
    required this.child,
    this.interval = const Duration(seconds: 30),
    this.connectivityDebounce = const Duration(seconds: 2),
    this.onlineChanges,
    super.key,
  });

  final OfflineSyncService service;
  final Widget child;
  final Duration interval;

  /// Time the network must stay up before the queue is replayed, so a flapping
  /// connection replays once instead of once per flap.
  final Duration connectivityDebounce;

  /// Injected for tests; the device connectivity stream is used otherwise.
  final Stream<bool>? onlineChanges;

  @override
  State<OfflineSyncLifecycle> createState() => _OfflineSyncLifecycleState();
}

class _OfflineSyncLifecycleState extends State<OfflineSyncLifecycle>
    with WidgetsBindingObserver {
  Timer? _timer;
  Timer? _connectivityDebounce;
  StreamSubscription<bool>? _connectivity;
  late final Stream<bool> _onlineChanges;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    _timer = Timer.periodic(widget.interval, (_) => _sync());
    _onlineChanges = widget.onlineChanges ?? _deviceConnectivity();
    _connectivity = _onlineChanges.listen(_onConnectivityChange);
  }

  Stream<bool> _deviceConnectivity() =>
      Connectivity().onConnectivityChanged.map((results) =>
          results.any((result) => result != ConnectivityResult.none));

  /// Only the return to the network matters; staying online is not a new event.
  void _onConnectivityChange(bool online) {
    if (!online) return;
    _connectivityDebounce?.cancel();
    _connectivityDebounce = Timer(widget.connectivityDebounce, () {
      if (!mounted) return;
      _sync();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  void _sync() {
    // A timer tick without a session has nothing to replay and no owner to
    // scope the replay by, so it would only spin.
    if (!widget.service.isAuthenticated) return;
    unawaited(_syncSafely());
  }

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
    _connectivityDebounce?.cancel();
    unawaited(_connectivity?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
