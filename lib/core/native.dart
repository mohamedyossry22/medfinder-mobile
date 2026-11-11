import 'package:flutter/services.dart';

/// جسر بسيط لأندرويد (MainActivity.kt): نغمة تنبيه + فتح إعدادات الإشعارات
class Native {
  static const _ch = MethodChannel('medfinder/native');

  static Future<void> beep() async {
    try {
      HapticFeedback.heavyImpact();
      await _ch.invokeMethod('beep');
    } catch (_) {/* مش مشكلة */}
  }

  static Future<void> openNotificationSettings() async {
    try {
      await _ch.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }
}
