import 'package:geolocator/geolocator.dart';

class LocationException implements Exception {
  final String message;
  final bool openSettings;
  LocationException(this.message, {this.openSettings = false});
}

Future<Position> currentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw LocationException('شغّل خدمة الموقع (GPS) من الإعدادات', openSettings: true);
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
  if (perm == LocationPermission.denied) {
    throw LocationException('محتاجين إذن الموقع عشان نوصّل طلبك لأقرب الصيدليات');
  }
  if (perm == LocationPermission.deniedForever) {
    throw LocationException('إذن الموقع مرفوض، فعّله من إعدادات التطبيق', openSettings: true);
  }
  return Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
    timeLimit: const Duration(seconds: 15),
  );
}

Position? _adsPos;
DateTime? _adsPosAt;

/// موقع المستخدم للإعلانات القريبة. بيتخزن 10 دقايق.
/// ask=true بيطلب الإذن لو لسه ماتطلبش. بيرجّع null لو الموقع مش متاح (من غير ما يرمي خطأ).
Future<Position?> positionForAds({bool ask = false}) async {
  final at = _adsPosAt;
  if (_adsPos != null && at != null && DateTime.now().difference(at) < const Duration(minutes: 10)) return _adsPos;
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied && ask) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever || perm == LocationPermission.unableToDetermine) {
      return null;
    }
    Position? p;
    try {
      p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium, timeLimit: const Duration(seconds: 10));
    } catch (_) {
      p = await Geolocator.getLastKnownPosition();
    }
    if (p == null) return null;
    _adsPos = p;
    _adsPosAt = DateTime.now();
    return p;
  } catch (_) {
    return null;
  }
}
