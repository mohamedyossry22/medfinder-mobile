import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/theme.dart';

bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16), this.borderColor});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF17211E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor ?? (dark ? const Color(0xFF26332F) : const Color(0xFFDCE8E4))),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

String statusLabel(String status, {int? qty, int? total}) {
  switch (status) {
    case 'Available':
      return 'متوفر';
    case 'Partial':
      return qty != null && total != null ? 'متوفر جزئيًا ($qty من $total)' : 'متوفر جزئيًا';
    case 'Unavailable':
      return 'غير متوفر';
    case 'Delivered':
      return 'تم التسليم';
    case 'Expired':
      return 'لم يرد';
    case 'Cancelled':
      return 'أُلغي';
    default:
      return 'بانتظار الرد';
  }
}

/// الحالة العامة للطلب
String overallLabel(String s) {
  switch (s) {
    case 'Available':
      return 'متوفر';
    case 'Partial':
      return 'متوفر جزئيًا';
    case 'Unavailable':
      return 'غير متوفر';
    case 'Delivered':
      return 'تم التسليم';
    case 'Expired':
      return 'انتهى';
    default:
      return 'بانتظار الرد';
  }
}

/// حالة بلون + نص (مش اللون لوحده)
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.status});
  final String label, status;

  @override
  Widget build(BuildContext context) {
    final s = statusStyle(status, isDark(context));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: s.fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class SoftTag extends StatelessWidget {
  const SoftTag(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
          color: dark ? const Color(0xFF12322C) : const Color(0xFFE3F6F1), borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          textDirection: TextDirection.ltr,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: dark ? const Color(0xFF7BE6CC) : const Color(0xFF0B6B58))),
    );
  }
}

class DrugTile extends StatelessWidget {
  const DrugTile({super.key, required this.drug, required this.onTap});
  final Drug drug;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return AppCard(
      onTap: onTap,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(drug.nameEn, textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            if (drug.nameAr.isNotEmpty) Text(drug.nameAr, style: TextStyle(color: muted, fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (drug.scientificName != null && drug.scientificName!.isNotEmpty) SoftTag(drug.scientificName!),
              if (drug.manufacturer != null && drug.manufacturer!.isNotEmpty) SoftTag(drug.manufacturer!),
            ]),
          ]),
        ),
        Icon(Icons.chevron_left, color: muted),
      ]),
    );
  }
}
