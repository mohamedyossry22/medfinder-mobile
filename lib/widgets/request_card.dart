import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/models.dart';
import '../core/realtime.dart';
import 'common.dart';

/// تأكيد استلام الدواء: بيقفل الطلب ويلغيه عند باقي الصيدليات
Future<bool> confirmReceipt(BuildContext context, String requestId) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('تأكيد الاستلام'),
      content: const Text('هل استلمت الدواء فعلًا؟\nبعد التأكيد هيتقفل الطلب وهيتلغي عند باقي الصيدليات.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لسه')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('أيوه، استلمت')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  final api = context.read<Api>();
  final rt = context.read<RealtimeService>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    await api.confirmDelivery(requestId);
    rt.poke();
    messenger.showSnackBar(const SnackBar(content: Text('تم تأكيد الاستلام. الحمد لله على السلامة')));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(apiError(e))));
    return false;
  }
}

/// كارت طلب: الحالة العامة + (زرار تأكيد الاستلام لو الصيدلية سجّلت التسليم)
class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.r, required this.onTap, this.onChanged});
  final RequestSummary r;
  final VoidCallback onTap;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return AppCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.drugNameEn, textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text('${r.quantity} علبة', style: TextStyle(color: muted, fontSize: 12)),
            ]),
          ),
          StatusChip(label: overallLabel(r.overallStatus), status: r.overallStatus),
        ]),
        if (r.needsConfirmation) ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: () async {
              if (await confirmReceipt(context, r.id)) onChanged?.call();
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('أكّد إنك استلمت الدواء'),
          ),
        ],
      ]),
    );
  }
}
