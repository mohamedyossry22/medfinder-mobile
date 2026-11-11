import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthState extends ChangeNotifier {
  static const _store = FlutterSecureStorage();
  String? token;
  String? name;
  String? role; // User | Pharmacy

  bool get loggedIn => token != null;
  bool get isPharmacy => role == 'Pharmacy';

  Future<void> load() async {
    token = await _store.read(key: 'token');
    name = await _store.read(key: 'name');
    role = await _store.read(key: 'role');
    notifyListeners();
  }

  Future<void> setSession(String t, String n, {String role = 'User'}) async {
    token = t;
    name = n;
    this.role = role;
    await _store.write(key: 'token', value: t);
    await _store.write(key: 'name', value: n);
    await _store.write(key: 'role', value: role);
    notifyListeners();
  }

  Future<void> logout() async {
    token = null;
    name = null;
    role = null;
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
