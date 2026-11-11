import 'dart:async';
import 'package:flutter/widgets.dart';
import 'api.dart';
import 'models.dart';
import 'native.dart';
import 'realtime.dart';

/// حالة صفحات الصيدلية: الواردة + الجاهزة للتسليم، وبتتحدث لايف من SignalR
/// (نفس فكرة PharmacyStore في الويب).
class PharmacyState extends ChangeNotifier {
  PharmacyState(this._api, this._rt);
  final Api _api;
  final RealtimeService _rt;

  List<IncomingRequest> incoming = [];
  List<ReadyItem> ready = [];
  Set<String> fresh = {}; // الطلبات الجديدة (للتمييز لحظيًا)
  bool loading = true;
  String? error;
  DateTime now = DateTime.now();

  // الطلبات اللي خلص وقتها بتختفي أوتوماتيك
  List<IncomingRequest> get activeIncoming => incoming.where((r) => r.expiresAt.isAfter(now)).toList();
  List<ReadyItem> get activeReady => ready.where((r) => r.expiresAt.isAfter(now)).toList();

  bool _started = false, _reloading = false, _pending = false;
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _timer;

  Future<void> init() async {
    if (_started) return;
    _started = true;
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      now = DateTime.now();
      notifyListeners();
    });
    _subs.addAll([
      _rt.newRequests.listen(_onNew),
      _rt.requestClosed.listen((_) => reload()),
      _rt.updates.listen((_) => reload()), // إعادة اتصال / إشعار وصل والتطبيق مفتوح
    ]);
    await reload(spinner: true);
  }

  Future<void> reload({bool spinner = false}) async {
    if (_reloading) {
      _pending = true;
      return;
    }
    _reloading = true;
    if (spinner) {
      loading = true;
      notifyListeners();
    }
    try {
      final r = await Future.wait([_api.incomingRequests(), _api.readyItems()]);
      incoming = r[0] as List<IncomingRequest>;
      ready = r[1] as List<ReadyItem>;
      now = DateTime.now();
      error = null;
    } catch (e) {
      if (incoming.isEmpty && ready.isEmpty) error = apiError(e);
    } finally {
      loading = false;
      _reloading = false;
      notifyListeners();
    }
    if (_pending) {
      _pending = false;
      await reload();
    }
  }

  void _onNew(IncomingRequest r) {
    if (incoming.any((x) => x.targetId == r.targetId)) return;
    incoming = [r, ...incoming];
    fresh = {...fresh, r.targetId};
    notifyListeners();
    Future.delayed(const Duration(seconds: 15), () {
      if (!_started) return;
      fresh = {...fresh}..remove(r.targetId);
      notifyListeners();
    });
    // التطبيق في الخلفية: إشعار النظام (FCM) هو اللي بيرن، فمنرنّش مرتين
    final st = WidgetsBinding.instance.lifecycleState;
    if (st == null || st == AppLifecycleState.resumed) Native.beep();
  }

  void drop(String targetId) {
    incoming = incoming.where((x) => x.targetId != targetId).toList();
    notifyListeners();
  }

  Future<RespondResult> respond(String targetId, String status, {int? qty}) async {
    final result = await _api.respond(targetId, status, qty: qty);
    drop(targetId);
    if (status != 'Unavailable') {
      try {
        ready = await _api.readyItems();
        notifyListeners();
      } catch (_) {}
    }
    return result;
  }

  Future<void> deliver(String targetId) async {
    await _api.deliver(targetId);
    ready = ready.where((x) => x.targetId != targetId).toList();
    notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _started = false;
    incoming = [];
    ready = [];
    fresh = {};
    loading = true;
    error = null;
  }
}
