import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'auth_state.dart';
import 'config.dart';
import 'models.dart';

/// SignalR.
/// المستخدم: لما صيدلية ترد، السيرفر بيبعت RequestUpdated.
/// الصيدلية: NewRequest (طلب جديد لايف) و RequestClosed (الطلب اتقفل).
/// لو الاتصال فشل أو اتقطع بيحاول يرجع لوحده، والتحديث الدوري/إعادة التحميل بيغطوا الفجوة.
class RealtimeService {
  RealtimeService(this._auth);
  final AuthState _auth;
  HubConnection? _hub;
  Timer? _retry;
  bool _stopped = true;

  final _ctrl = StreamController<void>.broadcast();
  final _newReq = StreamController<IncomingRequest>.broadcast();
  final _closed = StreamController<void>.broadcast();

  /// متصل ولا لأ (للمؤشر "متصل Live")
  final ValueNotifier<bool> connected = ValueNotifier(false);

  Stream<void> get updates => _ctrl.stream;
  Stream<IncomingRequest> get newRequests => _newReq.stream;
  Stream<void> get requestClosed => _closed.stream;
  void poke() => _ctrl.add(null);

  Future<void> start() async {
    if (_hub != null || _auth.token == null) return;
    _stopped = false;
    final hub = HubConnectionBuilder()
        .withUrl('$apiBase/hubs/notifications',
            options: HttpConnectionOptions(accessTokenFactory: () async => _auth.token ?? ''))
        .withAutomaticReconnect()
        .build();
    hub.on('RequestUpdated', (_) => _ctrl.add(null));
    hub.on('NewRequest', (args) {
      final m = (args != null && args.isNotEmpty) ? args.first : null;
      if (m is Map) {
        try {
          _newReq.add(IncomingRequest.fromJson(Map<String, dynamic>.from(m)));
        } catch (_) {/* payload غير متوقع: إعادة التحميل بتغطي */}
      }
    });
    hub.on('RequestClosed', (_) => _closed.add(null));
    hub.onreconnecting(({error}) => connected.value = false);
    hub.onreconnected(({connectionId}) {
      connected.value = true;
      _ctrl.add(null);
    });
    hub.onclose(({error}) {
      connected.value = false;
      _scheduleRetry();
    });
    _hub = hub;
    await _connect();
  }

  Future<void> _connect() async {
    final hub = _hub;
    if (hub == null || _stopped) return;
    try {
      await hub.start();
      connected.value = true;
      _ctrl.add(null); // ممكن نكون فوّتنا أحداث قبل الاتصال
    } catch (_) {
      connected.value = false;
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (_stopped || _hub == null) return;
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 5), _connect);
  }

  /// لما التطبيق يرجع للواجهة: لو الاتصال وقع نرجّعه
  Future<void> ensureConnected() async {
    if (_auth.token == null) return;
    if (_hub == null) return start();
    if (_hub!.state == HubConnectionState.Disconnected) await _connect();
  }

  Future<void> stop() async {
    _stopped = true;
    _retry?.cancel();
    final h = _hub;
    _hub = null;
    connected.value = false;
    try {
      await h?.stop();
    } catch (_) {}
  }
}
