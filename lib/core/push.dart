import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../screens/complaints_screen.dart';
import '../screens/pharmacy/pharmacy_request_screen.dart';
import '../screens/request_details_screen.dart';
import 'api.dart';
import 'realtime.dart';

enum PushStatus { ok, denied, unavailable }

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
      if (s.authorizationStatus == AuthorizationStatus.denied) {
        _inited = false; // لو فعّلها من الإعدادات بعدين نحاول تاني
        return;
      }
      _token = await m.getToken();
      if (_token != null) await _register(_token!);
      m.onTokenRefresh.listen(_register);
      FirebaseMessaging.onMessage.listen((_) => _realtime.poke()); // التطبيق مفتوح: نحدّث الشاشة
      FirebaseMessaging.onMessageOpenedApp.listen(_open);
      final initial = await m.getInitialMessage();
      if (initial != null) _open(initial);
    } catch (_) {/* مش مشكلة */}
  }

  /// حالة الإشعارات (للتنبيه في شاشة الصيدلية لو مش شغالة)
  Future<PushStatus> status() async {
    if (!available) return PushStatus.unavailable;
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      return s.authorizationStatus == AuthorizationStatus.denied ? PushStatus.denied : PushStatus.ok;
    } catch (_) {
      return PushStatus.unavailable;
    }
  }

  Future<void> _register(String token) async {
    _token = token;
    try {
      await _api.registerDevice(token, Platform.isIOS ? 'ios' : 'android');
    } catch (_) {}
  }

  void _open(RemoteMessage m) {
    // رد الأدمن على شكوى
    if (m.data['type'] == 'complaint') {
      _nav.currentState?.push(MaterialPageRoute(builder: (_) => const ComplaintsScreen()));
      return;
    }
    // إشعار طلب جديد للصيدلية: بيحمل targetId
    final tid = m.data['targetId'];
    if (tid is String && tid.isNotEmpty) {
      _nav.currentState?.push(MaterialPageRoute(builder: (_) => PharmacyRequestScreen(targetId: tid)));
      return;
    }
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
