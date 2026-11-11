import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/pharmacy_state.dart';
import '../../widgets/common.dart';

/// الطلبات اللي جاري تسليمها (قلت إنها متوفرة). "تم التسليم" بيبعت للمستخدم طلب تأكيد الاستلام.
class PharmacyReadyTab extends StatelessWidget {
  const PharmacyReadyTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<PharmacyState>();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final list = s.activeReady;

    return RefreshIndicator(
      onRefresh: () => s.reload(),
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
        Text('الطلبات اللي قلت إنها متوفرة. لما العميل ييجي ياخد الدواء اضغط "تم التسليم". الطلب بيختفي بعد 6 ساعات من وقت إنشائه.',
            style: TextStyle(color: muted)),
        const SizedBox(height: 12),
        if (s.loading)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
        else if (list.isEmpty)
          Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('مفيش طلبات جاهزة للتسليم دلوقتي', style: TextStyle(color: muted))))
        else
          for (final r in list) Padding(padding: const EdgeInsets.only(bottom: 12), child: _ReadyCard(key: ValueKey(r.targetId), r: r, now: s.now)),
      ]),
    );
  }
}

class _ReadyCard extends StatefulWidget {
  const _ReadyCard({super.key, required this.r, required this.now});
  final ReadyItem r;
  final DateTime now;
  @override
  State<_ReadyCard> createState() => _ReadyCardState();
}

class _ReadyCardState extends State<_ReadyCard> {
  bool _busy = false;
  String? _error;

  Future<void> _deliver() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تأكيد التسليم'),
        content: const Text('تأكيد تسليم الدواء للعميل؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لأ')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('أيوه، تم')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final state = context.read<PharmacyState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await state.deliver(widget.r.targetId);
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final qty = r.status == 'Partial' ? '${r.availableQty} من ${r.quantity}' : '${r.quantity}';
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(r.drugNameEn, textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        if (r.drugNameAr.isNotEmpty) Text(r.drugNameAr, style: TextStyle(color: muted)),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          StatusChip(label: statusLabel(r.status), status: r.status),
          ArTag('$qty علبة'),
          ArTag('يختفي بعد ${hoursLeft(r.expiresAt, widget.now)} ساعة'),
        ]),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600))),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: _busy ? null : _deliver,
          child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Text('تم التسليم'),
        ),
      ]),
    );
  }
}

