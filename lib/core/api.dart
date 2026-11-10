import 'package:dio/dio.dart';
import 'auth_state.dart';
import 'config.dart';
import 'models.dart';

const _errors = {
  'invalid_phone': 'رقم الموبايل غير صحيح',
  'too_many_requests': 'طلبت كود كتير، استنى 10 دقايق وحاول تاني',
  'invalid_code': 'الكود غير صحيح أو انتهت صلاحيته',
  'too_many_attempts': 'محاولات كتير، اطلب كود جديد',
  'profile_required': 'أدخل اسمك وسنك',
  'banned': 'الحساب موقوف',
  'create_failed': 'تعذر إنشاء الحساب',
  'invalid_quantity': 'الكمية غير صحيحة',
  'invalid_radius': 'النطاق غير صحيح',
  'invalid_location': 'الموقع غير صحيح',
  'drug_not_found': 'الدواء غير موجود',
  'rate_limited': 'وصلت للحد الأقصى (5 طلبات في الساعة)، حاول بعد شوية',
  'expired': 'الطلب انتهى وقته',
  'not_found': 'الطلب غير موجود',
  'closed': 'الطلب اتقفل',
  'already_closed': 'الطلب اتقفل قبل كده',
  'not_delivered': 'الصيدلية لسه ما سجّلتش تسليم الدواء',
};

String apiError(Object e, {String fallback = 'حصل خطأ، حاول تاني'}) {
  if (e is DioException) {
    if (e.response == null) return 'تعذر الاتصال بالسيرفر، اتأكد من الإنترنت';
    final d = e.response?.data;
    final code = d is Map ? d['error'] : null;
    if (code is String) {
      final m = _errors[code];
      if (m != null) return m;
      if (code.contains(' ')) return code;
    }
    if (e.response?.statusCode == 429) return 'محاولات كتير، استنى شوية';
  }
  return fallback;
}

class Api {
  Api(this._auth)
      : _dio = Dio(BaseOptions(
          baseUrl: apiBase,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) {
        final t = _auth.token;
        if (t != null) o.headers['Authorization'] = 'Bearer $t';
        h.next(o);
      },
      onError: (e, h) {
        if (e.response?.statusCode == 401 && !e.requestOptions.path.contains('/api/auth/')) _auth.logout();
        h.next(e);
      },
    ));
  }

  final Dio _dio;
  final AuthState _auth;

  String imageUrl(String path) => path.startsWith('http') ? path : '$apiBase$path';

  // ── الدخول ──
  Future<void> sendOtp(String phone) => _dio.post('/api/auth/otp/send', data: {'phone': phone});

  Future<void> verifyOtp(String phone, String code, {String? name, int? age}) async {
    final r = await _dio.post('/api/auth/otp/verify',
        data: {'phone': phone, 'code': code, 'fullName': name, 'age': age});
    await _auth.setSession(r.data['token'] as String, (r.data['fullName'] ?? '') as String);
  }

  // ── الأدوية ──
  Future<List<Drug>> searchDrugs(String q, {int limit = 15}) async {
    final r = await _dio.get('/api/drugs/search', queryParameters: {'q': q, 'limit': limit});
    return (r.data as List).map((e) => Drug.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Drug?> drugByBarcode(String code) async {
    try {
      final r = await _dio.get('/api/drugs/barcode/$code');
      return Drug.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> linkBarcode(String code, String drugId) =>
      _dio.post('/api/drugs/barcode', data: {'code': code, 'drugId': drugId});

  // ── الإعلانات ──
  Future<List<Ad>> ads() async {
    final r = await _dio.get('/api/ads');
    return (r.data as List).map((e) => Ad.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── الطلبات ──
  Future<CreateResult> createRequest({
    required String drugId,
    required int quantity,
    required double lat,
    required double lng,
    required double radiusKm,
  }) async {
    final r = await _dio.post('/api/requests',
        data: {'drugId': drugId, 'quantity': quantity, 'lat': lat, 'lng': lng, 'radiusKm': radiusKm});
    return CreateResult(r.data['requestId'] as String?, (r.data['pharmaciesCount'] ?? 0) as int);
  }

  Future<int> expand(String requestId, double radiusKm) async {
    final r = await _dio.post('/api/requests/$requestId/expand', data: {'radiusKm': radiusKm});
    return (r.data['added'] ?? 0) as int;
  }

  /// activeOnly: الطلبات الجارية بس (للصفحة الرئيسية)
  Future<List<RequestSummary>> myRequests({bool activeOnly = false}) async {
    final r = await _dio.get('/api/requests/mine', queryParameters: activeOnly ? {'scope': 'active'} : null);
    return (r.data as List).map((e) => RequestSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RequestDetails> requestDetails(String id) async {
    final r = await _dio.get('/api/requests/$id');
    return RequestDetails.fromJson(r.data as Map<String, dynamic>);
  }

  /// المستخدم بيأكد إنه استلم الدواء: الطلب بيتقفل عند كل الصيدليات
  Future<void> confirmDelivery(String requestId) => _dio.post('/api/requests/$requestId/confirm-delivery');

  // ── مسح الروشتة/العلبة بالذكاء الاصطناعي ──
  Future<List<ScanItem>> scanImage(String path) async {
    final form = FormData.fromMap({'image': await MultipartFile.fromFile(path, filename: 'scan.jpg')});
    final r = await _dio.post('/api/drugs/scan',
        data: form, options: Options(sendTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)));
    return ((r.data['items'] ?? []) as List).map((e) => ScanItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── الإشعارات ──
  Future<void> registerDevice(String token, String platform) =>
      _dio.post('/api/devices', data: {'token': token, 'platform': platform});

  Future<void> unregisterDevice(String token) =>
      _dio.post('/api/devices/unregister', data: {'token': token, 'platform': 'android'});
}
