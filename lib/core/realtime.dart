import 'dart:async';
import 'package:signalr_netcore/signalr_client.dart';
import 'auth_state.dart';
import 'config.dart';

/// SignalR: لما صيدلية ترد، السيرفر بيبعت RequestUpdated وإحنا بنحدّث الشاشة.
/// لو الاتصال فشل، التحديث الدوري في صفحة التفاصيل بيغطي.
class RealtimeService {
  RealtimeService(this._auth);
  final AuthState _auth;
  HubConnection? _hub;
  final _ctrl = StreamController<void>.broadcast();

  Stream<void> get updates => _ctrl.stream;
  void poke() => _ctrl.add(null);

  Future<void> start() async {
    if (_hub != null || _auth.token == null) return;
    final hub = HubConnectionBuilder()
        .withUrl('$apiBase/hubs/notifications',
            options: HttpConnectionOptions(accessTokenFactory: () async => _auth.token ?? ''))
        .withAutomaticReconnect()
        .build();
    hub.on('RequestUpdated', (_) => _ctrl.add(null));
    hub.onreconnected(({connectionId}) => _ctrl.add(null));
    _hub = hub;
    try {
      await hub.start();
    } catch (_) {/* التحديث الدوري يغطي */}
  }

  Future<void> stop() async {
    final h = _hub;
    _hub = null;
    try {
      await h?.stop();
    } catch (_) {}
  }
}
