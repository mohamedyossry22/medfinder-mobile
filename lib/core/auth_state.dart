import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthState extends ChangeNotifier {
  static const _store = FlutterSecureStorage();
  String? token;
  String? name;

  bool get loggedIn => token != null;

  Future<void> load() async {
    token = await _store.read(key: 'token');
    name = await _store.read(key: 'name');
    notifyListeners();
  }

  Future<void> setSession(String t, String n) async {
    token = t;
    name = n;
    await _store.write(key: 'token', value: t);
    await _store.write(key: 'name', value: n);
    notifyListeners();
  }

  Future<void> logout() async {
    token = null;
    name = null;
    await _store.deleteAll();
    notifyListeners();
  }
}

/// الإعدادات المشتركة: نطاق البحث (كم)
class Settings extends ChangeNotifier {
  static const radii = [1.0, 3.0, 5.0, 10.0, 20.0];
  double radiusKm = 3;
  void setRadius(double r) {
    radiusKm = r;
    notifyListeners();
  }
}
