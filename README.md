# MedFinder Mobile (Flutter)

تطبيق المستخدمين: بحث عن دواء (كتابة / باركود / روشتة / علبة) → اختيار الكمية والنطاق → إرسال لأقرب الصيدليات → متابعة الردود لايف.

## التجهيز
```
flutter create --org com.medfinder --project-name medfinder medfinder_app
cd medfinder_app
```
1. انسخ `lib/` و`pubspec.yaml` من المجلد ده فوق المشروع (استبدل الموجود)، ثم `flutter pub get`.
2. **Android** (`android/app/build.gradle`): `minSdkVersion 23`.
   في `android/app/src/main/AndroidManifest.xml` (قبل `<application>`):
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
   <uses-permission android:name="android.permission.CAMERA"/>
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
   <queries>
     <intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>
     <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
   </queries>
   ```
   وللتطوير على http بس: `android:usesCleartextTraffic="true"` في وسم `<application>` (احذفه في الإنتاج واستخدم HTTPS).
3. **iOS** (`ios/Runner/Info.plist`): `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSPhotoLibraryUsageDescription`، وفي `LSApplicationQueriesSchemes` ضيف `tel` و`https`. الحد الأدنى iOS 15.5 (بسبب ML Kit).
4. **عنوان السيرفر**:
   ```
   flutter run --dart-define=API_BASE=http://192.168.1.5:5000
   ```
   (من الـ Android emulator الافتراضي `http://10.0.2.2:5000` شغال لوحده.)

## الإشعارات (Firebase)
```
dart pub global activate flutterfire_cli
flutterfire configure        # بيربط التطبيق بمشروع Firebase ويحط google-services.json / GoogleService-Info.plist
```
نفس مشروع Firebase بتاع الويب والباك إند (الـ service account في الباك إند). من غير ما تعمل ده التطبيق بيشتغل عادي بس من غير إشعارات (التحديث اللايف بيتم من SignalR + تحديث دوري كل 15 ثانية).
على iOS لازم APNs key مرفوع في Firebase.

## الشاشات
| الشاشة | الوظيفة |
|---|---|
| `login_screen` | رقم الموبايل ← كود OTP ← (مستخدم جديد: الاسم والسن) |
| `home_screen` | كبسولة البحث، أزرار (روشتة / باركود / علبة)، النطاق، إعلانات الصيدليات، طلباتك الأخيرة |
| `search_screen` | بحث فوري (عربي/إنجليزي/مادة فعالة) والاختيار من القايمة فقط |
| `scan_barcode_screen` | مسح أو كتابة الباركود. لو مش معروف: تربطه بدواء بالاسم (Crowdsourcing) |
| `scan_text_screen` | تصوير روشتة/علبة ← قراءة النص على الجهاز ← "هل تقصد؟" من قاعدة الأدوية |
| `new_request_screen` | الكمية + النطاق + الموقع + إرسال |
| `request_details_screen` | رادار + الصيدليات وحالة كل واحدة + اتصال/خريطة للمتوفر + توسيع النطاق |

## ملاحظات
- **قراءة الروشتة**: ML Kit على الجهاز بيقرأ الحروف اللاتينية (أسماء الأدوية الإنجليزي المطبوعة). **مش بيدعم العربي**، والخط المكتوب بالإيد دقته ضعيفة، عشان كده المستخدم دايمًا بيأكد الدواء من قايمة الاقتراحات.
- **الباركود**: بيقبل EAN/UPC وكمان GS1 DataMatrix (بنستخرج الـ GTIN منه). تغطية الباركودات بتزيد مع الاستخدام (تصويت المستخدمين والصيدليات).
- **الموقع**: بنستخدم GPS الحالي. اختيار منطقة تانية على خريطة لسه مش موجود (محتاج Google Maps API key).
- **الخصوصية**: الصيدلية ما بتشوفش اسم المستخدم ولا رقمه، وبيانات الصيدلية بتظهر للمستخدم بس لو ردّت "متوفر".
- **الإشعار والتطبيق مفتوح**: بنحدّث الشاشة بس (من غير بانر). لو عايز بانر داخل التطبيق ضيف `flutter_local_notifications`.
- **ما اتجربش**: الكود ما اتبنيش عندي (مفيش Flutter SDK هنا). أول `flutter run` ممكن يطلّع أخطاء بسيطة (إصدارات مكتبات)، ابعتهالي وأصلحها.

## قبل الإطلاق
- أيقونة واسم وسبلاش، وسياسة خصوصية (موقع + بيانات شخصية) قبل النشر على المتاجر.
- HTTPS على السيرفر وإزالة `usesCleartextTraffic`.
- اختبار على أجهزة حقيقية (الكاميرا والموقع والإشعارات).
