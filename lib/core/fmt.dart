/// أدوات تنسيق لشاشات الصيدلية (نفس منطق core/fmt.ts في الويب)
const _lifetimeMs = 6 * 3600 * 1000;

/// نسبة الوقت المتبقي للطلب (0..1)
double remainingFrac(DateTime expiresAt, DateTime now) {
  final f = expiresAt.difference(now).inMilliseconds / _lifetimeMs;
  return f < 0 ? 0.0 : (f > 1 ? 1.0 : f);
}

int hoursLeft(DateTime expiresAt, DateTime now) {
  final h = (expiresAt.difference(now).inMinutes / 60).ceil();
  return h < 0 ? 0 : h;
}

String timeAgo(DateTime t, DateTime now) {
  final m = now.difference(t).inMinutes;
  if (m < 1) return 'الآن';
  if (m < 60) return 'منذ $m دقيقة';
  return 'منذ ${m ~/ 60} ساعة';
}

String pharmacyStatusAr(String s) => switch (s) {
      'Pending' => 'قيد المراجعة',
      'Approved' => 'معتمدة',
      'Rejected' => 'مرفوضة',
      'Suspended' => 'موقوفة',
      _ => s,
    };

String fmtDate(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

String complaintCategoryAr(String c) => switch (c) {
      'Request' => 'مشكلة في طلب',
      'Pharmacy' => 'عن صيدلية',
      'User' => 'عن مستخدم',
      'App' => 'مشكلة في التطبيق',
      _ => 'أخرى',
    };

String complaintStatusAr(String s) => switch (s) {
      'New' => 'تم الإرسال',
      'InReview' => 'قيد المراجعة',
      'Resolved' => 'تم الحل',
      'Closed' => 'مغلقة',
      _ => s,
    };

/// بنستعير ألوان حالات الطلب لشارة حالة الشكوى
String complaintChipKey(String s) => switch (s) {
      'InReview' => 'Partial',
      'Resolved' => 'Available',
      'Closed' => 'Unavailable',
      _ => 'Pending',
    };

/// نقطة واحدة / نقطتين / 3 نقاط / 15 نقطة
String pointsAr(int n) {
  final a = n.abs();
  if (a == 1) return 'نقطة واحدة';
  if (a == 2) return 'نقطتين';
  return '$a ${a >= 3 && a <= 10 ? 'نقاط' : 'نقطة'}';
}
