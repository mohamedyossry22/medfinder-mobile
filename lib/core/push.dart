import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../screens/request_details_screen.dart';
import 'api.dart';
import 'realtime.dart';

/// إشعارات FCM. لو Firebase مش متظبط (مفيش firebase_options) التطبيق بيشتغل عادي بدونها.
class PushService {
  PushService(this._api, this._nav, this._realtime);
  final Api _api;
  final GlobalKey<NavigatorState> _nav;
  final RealtimeService _realtime;
  String? _token;
  bool _inited = false;

  bool get available => Firebase.apps.isNotEmpty;

  Future<void> init() async {
    if (!available || _inited) return;
    _inited = true;
    try {
      final m = FirebaseMessaging.instance;
      final s = await m.requestPermission();
      if (s.authorizationStatus == AuthorizationStatus.denied) return;
      _token = await m.getToken();
      if (_token != null) await _register(_token!);
      m.onTokenRefresh.listen(_register);
      FirebaseMessaging.onMessage.listen((_) => _realtime.poke()); // التطبيق مفتوح: نحدّث الشاشة
      FirebaseMessaging.onMessageOpenedApp.listen(_open);
      final initial = await m.getInitialMessage();
      if (initial != null) _open(initial);
    } catch (_) {/* مش مشكلة */}
  }

  Future<void> _register(String token) async {
    _token = token;
    try {
      await _api.registerDevice(token, Platform.isIOS ? 'ios' : 'android');
    } catch (_) {}
  }

  void _open(RemoteMessage m) {
    final id = m.data['requestId'];
    if (id is String && id.isNotEmpty) {
      _nav.currentState?.push(MaterialPageRoute(builder: (_) => RequestDetailsScreen(requestId: id)));
    }
  }

  Future<void> unregister() async {
    final t = _token;
    _token = null;
    _inited = false;
    if (t == null) return;
    try {
      await _api.unregisterDevice(t);
    } catch (_) {}
  }
}
