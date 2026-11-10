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
