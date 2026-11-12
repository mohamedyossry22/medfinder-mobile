import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/models.dart';

const kAdFallback = Color(0xFF0B7F69);

/// كارت إعلان (صورة + عنوان + اسم الصيدلية). بيستخدم في الرئيسية وفي صفحة الإعلانات.
class AdTile extends StatelessWidget {
  const AdTile({super.key, required this.ad, required this.onTap, this.height = 170});
  final Ad ad;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final api = context.read<Api>();
    return Semantics(
      button: true,
      label: 'إعلان: ${ad.title}',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(fit: StackFit.expand, children: [
              Container(color: kAdFallback),
              Image.network(api.imageUrl(ad.imagePath), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
              // تدرّج داكن تحت النص عشان يتقري
              const DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.center, colors: [Color(0xCC000000), Color(0x00000000)]))),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
                  child: const Text('إعلان', style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ),
              Positioned(
                bottom: 12,
                right: 14,
                left: 14,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ad.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  if (ad.pharmacyName != null) Text(ad.pharmacyName!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
