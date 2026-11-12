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
  'invalid_credentials': 'البريد أو كلمة المرور غير صحيحة',
  'locked_out': 'الحساب مقفول مؤقتًا بسبب محاولات كتيرة، حاول بعد 15 دقيقة',
  'locked': 'مينفعش تعدّل الرد دلوقتي',
  'invalid_subject': 'عنوان الشكوى لازم يكون من 3 لـ 150 حرف',
  'invalid_message': 'نص الشكوى لازم يكون من 10 لـ 2000 حرف',
  'invalid_category': 'نوع الشكوى غير صحيح',
  'pharmacy_not_approved': 'حساب الصيدلية لسه مش معتمد',
};

/// الحساب اتسجّل دخوله بنجاح بس مش حساب صيدلية (مثلاً أدمن)
class NotPharmacyAccount implements Exception {
  const NotPharmacyAccount();
}

String apiError(Object e, {String fallback = 'حصل خطأ، حاول تاني'}) {
  if (e is NotPharmacyAccount) return 'الحساب ده مش حساب صيدلية. لوحة الإدارة متاحة من الويب بس';
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

  // ── الشكاوى (مستخدم وصيدلية) ──
  Future<void> createComplaint(String category, String subject, String message) =>
      _dio.post('/api/complaints', data: {'category': category, 'subject': subject, 'message': message});

  Future<List<MyComplaint>> myComplaints() async {
    final r = await _dio.get('/api/complaints/mine');
    return (r.data as List).map((e) => MyComplaint.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── الصيدلية ──
  Future<void> pharmacyLogin(String email, String password) async {
    final r = await _dio.post('/api/auth/login', data: {'email': email, 'password': password});
    if (r.data['role'] != 'Pharmacy') throw const NotPharmacyAccount();
    await _auth.setSession(r.data['token'] as String, (r.data['fullName'] ?? '') as String, role: 'Pharmacy');
  }

  Future<PharmacyMe> pharmacyMe() async {
    final r = await _dio.get('/api/pharmacy/me');
    return PharmacyMe.fromJson(r.data as Map<String, dynamic>);
  }

  Future<List<IncomingRequest>> incomingRequests() async {
    final r = await _dio.get('/api/pharmacy/requests/incoming');
    return (r.data as List).map((e) => IncomingRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PharmacyRequest> pharmacyRequest(String targetId) async {
    final r = await _dio.get('/api/pharmacy/requests/$targetId');
    return PharmacyRequest.fromJson(r.data as Map<String, dynamic>);
  }

  /// status: Available | Partial | Unavailable
  Future<RespondResult> respond(String targetId, String status, {int? qty}) async {
    final r = await _dio.post('/api/pharmacy/requests/$targetId/respond', data: {'status': status, 'availableQty': qty});
    return RespondResult.fromJson(r.data as Map<String, dynamic>);
  }

  Future<List<ReadyItem>> readyItems() async {
    final r = await _dio.get('/api/pharmacy/ready');
    return (r.data as List).map((e) => ReadyItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> deliver(String targetId) => _dio.post('/api/pharmacy/ready/$targetId/deliver', data: {});

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
  /// الأحدث الأول. الرئيسية: take=5، وصفحة الإعلانات بتكمّل بـ skip
  /// بس الإعلانات اللي صيدليتها في نطاق 10 كم من موقع المستخدم
  Future<List<Ad>> ads({required double lat, required double lng, int take = 5, int skip = 0}) async {
    final r = await _dio.get('/api/ads', queryParameters: {'lat': lat, 'lng': lng, 'take': take, 'skip': skip});
    return (r.data as List).map((e) => Ad.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdDetails> adDetails(String id, {required double lat, required double lng}) async {
    final r = await _dio.get('/api/ads/$id', queryParameters: {'lat': lat, 'lng': lng});
    return AdDetails.fromJson(r.data as Map<String, dynamic>);
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
