import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';

CollectionReference<Map<String, dynamic>> _viewersOf(String matchId) =>
    FirebaseFirestore.instance
        .collection('matchViewers')
        .doc(matchId)
        .collection('viewers');

/// Lists this device as a viewer of [matchId] for as long as it is on screen.
///
/// Wrap the whole match view with it. It writes a small heartbeat document
/// every 30 seconds and removes it when the screen closes or the app goes
/// to the background. No personal data is stored (just a random id).
class ViewerPresence extends StatefulWidget {
  const ViewerPresence({super.key, required this.matchId, required this.child});

  final String matchId;
  final Widget child;

  @override
  State<ViewerPresence> createState() => _ViewerPresenceState();
}

class _ViewerPresenceState extends State<ViewerPresence>
    with WidgetsBindingObserver {
  late final DocumentReference<Map<String, dynamic>> _doc;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final random = Random.secure();
    final id = List.generate(
      20,
      (_) => random.nextInt(36).toRadixString(36),
    ).join();
    _doc = _viewersOf(widget.matchId).doc(id);
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _beat() {
    _doc.set({'lastSeen': FieldValue.serverTimestamp()}).catchError((_) {});
  }

  void _start() {
    _beat();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _beat());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _doc.delete().catchError((_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else if (state == AppLifecycleState.paused) {
      _stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// "👁 12 watching": the number of devices with a fresh heartbeat.
class LiveViewerCount extends StatefulWidget {
  const LiveViewerCount({super.key, required this.matchId});

  final String matchId;

  @override
  State<LiveViewerCount> createState() => _LiveViewerCountState();
}

class _LiveViewerCountState extends State<LiveViewerCount> {
  int? _count;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  Future<void> _load() async {
    try {
      final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(seconds: 75)),
      );
      final snap = await _viewersOf(
        widget.matchId,
      ).where('lastSeen', isGreaterThan: cutoff).count().get();
      if (!mounted) return;
      setState(() => _count = snap.count);
    } catch (_) {
      // Keep showing the last known number.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = _count;
    if (count == null) return const SizedBox.shrink();
    // You are watching too, so never show fewer than one.
    final n = max(count, 1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.visibility_outlined, size: 15, color: AppColors.muted),
        const SizedBox(width: 5),
        Text('$n watching', style: AppText.muted(size: 12)),
      ],
    );
  }
}
