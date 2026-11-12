/// شغّل بـ: flutter run --dart-define=API_BASE=http://192.168.1.5:5000
/// (10.0.2.2 = localhost جهاز الكمبيوتر من الـ Android emulator)
const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://10.0.2.2:5000');

/// زرار البحث بالباركود مخفي حاليًا (الكود جاهز). خليه true لما قاعدة الباركودات تتجمع.
const bool kEnableBarcode = false;

/// رابط الموقع: صفحة تسجيل الصيدليات الجديدة بتتفتح من هنا.
/// شغّل بـ: --dart-define=WEB_BASE=https://your-domain.com
const String webBase = String.fromEnvironment('WEB_BASE', defaultValue: 'http://localhost:4200');
const String webRegisterUrl = '$webBase/register';

/// الإعلان بيظهر بس للمستخدمين في نطاق الصيدلية (نفس الرقم في الباك إند)
const double kAdRadiusKm = 10;
