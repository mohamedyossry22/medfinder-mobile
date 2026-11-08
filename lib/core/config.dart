/// شغّل بـ: flutter run --dart-define=API_BASE=http://192.168.1.5:5000
/// (10.0.2.2 = localhost جهاز الكمبيوتر من الـ Android emulator)
const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://10.0.2.2:5000');
