import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/pharmacy_state.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/countdown_ring.dart';
import '../../widgets/response_actions.dart';
import 'pharmacy_request_screen.dart';

/// الطلبات الجديدة: بتوصل لايف من غير Refresh (SignalR) + إشعار لو التطبيق مقفول
class PharmacyIncomingTab extends StatelessWidget {
  const PharmacyIncomingTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<PharmacyState>();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final list = s.activeIncoming;

    Widget body;
    if (s.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (list.isEmpty) {
      body = ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(32), children: [
        const SizedBox(height: 40),
        Icon(Icons.notifications_none, size: 56, color: muted),
        const SizedBox(height: 12),
        Center(
          child: Text(s.error != null ? s.error! : 'مفيش طلبات دلوقتي',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: s.error != null ? Theme.of(context).colorScheme.error : null)),
        ),
        const SizedBox(height: 8),
        Text('أول ما حد يدور على دواء في نطاقك هيظهر هنا فورًا، من غير ما تعمل Refresh.',
            textAlign: TextAlign.center, style: TextStyle(color: muted)),
      ]);
    } else {
      body = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: list.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _IncomingCard(key: ValueKey(list[i].targetId), r: list[i], fresh: s.fresh.contains(list[i].targetId), now: s.now),
        ),
      );
    }
    return RefreshIndicator(onRefresh: () => s.reload(), child: body);
  }
}

class _IncomingCard extends StatelessWidget {
  const _IncomingCard({super.key, required this.r, required this.fresh, required this.now});
  final IncomingRequest r;
  final bool fresh;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    // دايمًا ملفوف بنفس الـ widget عشان حالة الأزرار ماتضيعش لما "جديد" يخلص؛ الحركة بتشتغل بس لو الكارت وصل جديد
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: fresh ? 0.0 : 1.0, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, -14 * (1 - v)), child: child)),
      child: AppCard(
        borderColor: fresh ? kAccent : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (fresh) const Padding(padding: EdgeInsets.only(bottom: 4), child: _NewBadge()),
                Text(r.drugNameEn, textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                if (r.drugNameAr.isNotEmpty) Text(r.drugNameAr, style: TextStyle(color: muted)),
                if (r.activeIngredient != null && r.activeIngredient!.isNotEmpty)
                  Text(r.activeIngredient!, textDirection: TextDirection.ltr, style: TextStyle(color: muted, fontSize: 12)),
              ]),
            ),
            const SizedBox(width: 8),
            CountdownRing(expiresAt: r.expiresAt, now: now),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            ArTag('${r.quantity} علبة'),
            ArTag('${r.distanceKm.toStringAsFixed(r.distanceKm % 1 == 0 ? 0 : 1)} كم'),
            ArTag(timeAgo(r.createdAt, now)),
          ]),
          const SizedBox(height: 12),
          ResponseActions(
            targetId: r.targetId,
            quantity: r.quantity,
            onDetails: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PharmacyRequestScreen(targetId: r.targetId))),
          ),
        ]),
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(999)),
        child: const Text('جديد', style: TextStyle(color: Color(0xFF10201C), fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

