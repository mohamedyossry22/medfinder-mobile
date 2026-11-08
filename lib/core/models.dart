double _d(dynamic v) => (v as num).toDouble();
DateTime _t(dynamic v) => DateTime.parse(v as String).toLocal();

class Drug {
  final String id, nameEn, nameAr;
  final String? scientificName, manufacturer, route;
  Drug.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        nameEn = (j['name_en'] ?? '') as String,
        nameAr = (j['name_ar'] ?? '') as String,
        scientificName = j['scientific_name'] as String?,
        manufacturer = j['manufacturer'] as String?,
        route = j['route'] as String?;
}

class Ad {
  final String id, title, imagePath;
  final String? linkUrl, pharmacyName;
  Ad.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        title = j['title'] as String,
        imagePath = j['imagePath'] as String,
        linkUrl = j['linkUrl'] as String?,
        pharmacyName = j['pharmacyName'] as String?;
}

class RequestSummary {
  final String id, drugNameEn, drugNameAr;
  final int quantity, totalPharmacies, availableCount;
  final DateTime createdAt, expiresAt;
  final bool isExpired;
  RequestSummary.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        drugNameEn = j['drugNameEn'] as String,
        drugNameAr = j['drugNameAr'] as String,
        quantity = j['quantity'] as int,
        totalPharmacies = j['totalPharmacies'] as int,
        availableCount = j['availableCount'] as int,
        createdAt = _t(j['createdAt']),
        expiresAt = _t(j['expiresAt']),
        isExpired = j['isExpired'] as bool;
}

class Contact {
  final String phone, mapsUrl;
  final String? address;
  final double lat, lng;
  Contact.fromJson(Map<String, dynamic> j)
      : phone = j['phone'] as String,
        mapsUrl = (j['mapsUrl'] ?? '') as String,
        address = j['address'] as String?,
        lat = _d(j['lat']),
        lng = _d(j['lng']);
}

class PharmacyReply {
  final String pharmacyId, name, status;
  final double distanceKm;
  final int? availableQty;
  final Contact? contact;
  PharmacyReply.fromJson(Map<String, dynamic> j)
      : pharmacyId = j['pharmacyId'] as String,
        name = j['name'] as String,
        status = j['status'] as String,
        distanceKm = _d(j['distanceKm']),
        availableQty = j['availableQty'] as int?,
        contact = j['contact'] == null ? null : Contact.fromJson(j['contact'] as Map<String, dynamic>);
}

class RequestDetails {
  final String id, drugNameEn, drugNameAr;
  final int quantity;
  final double radiusKm;
  final DateTime createdAt, expiresAt;
  final bool isExpired;
  final List<PharmacyReply> pharmacies;
  RequestDetails.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        drugNameEn = j['drugNameEn'] as String,
        drugNameAr = j['drugNameAr'] as String,
        quantity = j['quantity'] as int,
        radiusKm = _d(j['radiusKm']),
        createdAt = _t(j['createdAt']),
        expiresAt = _t(j['expiresAt']),
        isExpired = j['isExpired'] as bool,
        pharmacies = (j['pharmacies'] as List).map((e) => PharmacyReply.fromJson(e as Map<String, dynamic>)).toList();

  int get answered => pharmacies.where((p) => p.status != 'Pending' && p.status != 'Expired').length;
  int get availableCount => pharmacies.where((p) => p.status == 'Available' || p.status == 'Partial').length;
}

class CreateResult {
  final String? requestId;
  final int pharmaciesCount;
  CreateResult(this.requestId, this.pharmaciesCount);
}

/// بيستخرج رقم الباركود من القيمة المقروءة (EAN/UPC أو GS1 DataMatrix اللي بيبدأ بـ 01 + GTIN-14)
String? normalizeBarcode(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.length >= 16 && RegExp(r'^01\d{14}').hasMatch(s)) s = s.substring(2, 16);
  if (!RegExp(r'^\d{8,14}$').hasMatch(s)) return null;
  if (s.length == 14 && s.startsWith('0')) s = s.substring(1); // GTIN-14 → EAN-13
  return s;
}
