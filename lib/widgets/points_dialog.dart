import 'package:flutter/material.dart';
import '../core/fmt.dart';
import '../core/models.dart';

/// "مبروك": بيظهر لما الصيدلية تكسب نقاط من الرد على طلب
Future<void> showPointsDialog(BuildContext context, RespondResult r) {
  final tier = r.pointsAwarded >= 3
      ? 'ردّيت في أول 5 دقايق'
      : r.pointsAwarded == 2
          ? 'ردّيت خلال 10 دقايق'
          : 'ردّيت بعد 10 دقايق';
  final muted = Theme.of(context).colorScheme.onSurfaceVariant;
  return showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('مبروك! 🎉'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('تم إضافة ${pointsAr(r.pointsAwarded)} إلى رصيدك',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(tier, style: TextStyle(color: muted)),
        if (r.pointsBalance != null) ...[
          const SizedBox(height: 10),
          Text('رصيدك الحالي: ${pointsAr(r.pointsBalance!)}', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 10),
        Text('استمر بالرد بسرعة علشان تستفيد بالنقاط في الإعلانات.', style: TextStyle(color: muted)),
      ]),
      actions: [FilledButton(onPressed: () => Navigator.of(c).pop(), child: const Text('تمام'))],
    ),
  );
}
