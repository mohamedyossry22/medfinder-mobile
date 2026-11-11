import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../widgets/common.dart';
import '../../widgets/response_actions.dart';

/// تفاصيل طلب (من كارت الطلبات الواردة أو من الإشعار)
class PharmacyRequestScreen extends StatefulWidget {
  const PharmacyRequestScreen({super.key, required this.targetId});
  final String targetId;
  @override
  State<PharmacyRequestScreen> createState() => _PharmacyRequestScreenState();
}

class _PharmacyRequestScreenState extends State<PharmacyRequestScreen> {
  PharmacyRequest? _d;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await context.read<Api>().pharmacyRequest(widget.targetId);
      if (mounted) setState(() => _d = d);
    } catch (_) {
      if (mounted) setState(() => _error = 'الطلب غير موجود أو انتهى');
    }
  }

  Widget _row(String k, String? v, Color muted) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(k, style: TextStyle(color: muted))),
          Expanded(child: Text((v == null || v.isEmpty) ? '—' : v, textDirection: TextDirection.ltr, textAlign: TextAlign.end)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurfaceVariant;
    final d = _d;
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الطلب')),
      body: SafeArea(
        child: d == null
            ? Center(child: _error != null ? Text(_error!, style: TextStyle(color: cs.error)) : const CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(d.drugNameEn, textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
                    if (d.drugNameAr.isNotEmpty) Text(d.drugNameAr, style: TextStyle(color: muted)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      ArTag('الكمية المطلوبة: ${d.quantity}'),
                      ArTag('${d.distanceKm.toStringAsFixed(d.distanceKm % 1 == 0 ? 0 : 1)} كم'),
                      ArTag(timeAgo(d.createdAt, DateTime.now())),
                      StatusChip(label: statusLabel(d.status), status: d.status),
                    ]),
                    const SizedBox(height: 10),
                    _row('المادة الفعالة', d.activeIngredient, muted),
                    _row('الشركة المصنعة', d.manufacturer, muted),
                    _row('طريقة الاستخدام', d.route, muted),
                    if (d.availableQty != null && d.availableQty! > 0) _row('الكمية المتاحة', '${d.availableQty}', muted),
                    if (d.status == 'Pending') ...[
                      const SizedBox(height: 12),
                      ResponseActions(targetId: d.id, quantity: d.quantity, onDone: () => Navigator.of(context).maybePop()),
                    ],
                  ]),
                ),
              ]),
      ),
    );
  }
}

