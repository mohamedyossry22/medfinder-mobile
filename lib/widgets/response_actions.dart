import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/pharmacy_state.dart';
import '../core/theme.dart';
import 'common.dart';
import 'points_dialog.dart';

/// الأزرار الأربعة: متوفر / متوفر جزئي / غير متوفر / (تفاصيل اختياري). نفس ResponseActions في الويب.
class ResponseActions extends StatefulWidget {
  const ResponseActions({super.key, required this.targetId, required this.quantity, this.onDetails, this.onDone});
  final String targetId;
  final int quantity;
  final VoidCallback? onDetails; // لو null مفيش زرار تفاصيل (صفحة التفاصيل نفسها)
  final VoidCallback? onDone;

  @override
  State<ResponseActions> createState() => _ResponseActionsState();
}

class _ResponseActionsState extends State<ResponseActions> {
  final _qty = TextEditingController(text: '1');
  bool _busy = false, _partial = false;
  String? _error;

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  Future<void> _send(String status) async {
    int? q;
    if (status == 'Partial') {
      q = int.tryParse(_qty.text.trim());
      if (q == null || q < 1 || q >= widget.quantity) {
        setState(() => _error = 'الكمية لازم تكون أكبر من صفر وأقل من المطلوبة');
        return;
      }
    }
    final state = context.read<PharmacyState>();
    // الكارت بيتشال من القايمة بعد الرد، فبناخد الـ navigator قبلها عشان نقدر نعرض "مبروك"
    final nav = Navigator.of(context, rootNavigator: true);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await state.respond(widget.targetId, status, qty: q);
      if (r.pointsAwarded > 0) await showPointsDialog(nav.context, r);
      widget.onDone?.call(); // الكارت بيتشال من القايمة، فمفيش setState بعد كده
    } catch (e) {
      final code = _code(e);
      if (code == 'expired' || code == 'closed') state.drop(widget.targetId);
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _code(Object e) {
    try {
      final d = (e as dynamic).response?.data;
      return d is Map ? d['error'] as String? : null;
    } catch (_) {
      return null;
    }
  }

  ButtonStyle _style(Color bg, Color fg, {BorderSide? side}) => FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg.withAlpha(110),
        disabledForegroundColor: fg.withAlpha(150),
        minimumSize: const Size.fromHeight(46),
        side: side,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      );

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final cs = Theme.of(context).colorScheme;
    final ok = statusStyle('Available', dark);
    final pa = statusStyle('Partial', dark);
    final no = statusStyle('Unavailable', dark);

    final available = FilledButton(
      style: _style(ok.fg, dark ? const Color(0xFF10201C) : Colors.white),
      onPressed: _busy ? null : () => _send('Available'),
      child: const Text('متوفر'),
    );
    final partial = FilledButton(
      style: _style(pa.bg, pa.fg),
      onPressed: (_busy || widget.quantity < 2) ? null : () => setState(() => _partial = true),
      child: const Text('متوفر جزئي'),
    );
    final unavailable = FilledButton(
      style: _style(no.bg, no.fg),
      onPressed: _busy ? null : () => _send('Unavailable'),
      child: const Text('غير متوفر'),
    );
    final details = widget.onDetails == null
        ? null
        : OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              foregroundColor: cs.primary,
              side: BorderSide(color: dark ? const Color(0xFF26332F) : const Color(0xFFDCE8E4), width: 2),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: widget.onDetails,
            child: const Text('تفاصيل'),
          );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Expanded(child: available), const SizedBox(width: 8), Expanded(child: partial)]),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: unavailable), if (details != null) ...[const SizedBox(width: 8), Expanded(child: details)]]),
      if (_partial) ...[
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _qty,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                isDense: true,
                labelText: 'الكمية المتاحة (من ${widget.quantity})',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(72, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: _busy ? null : () => _send('Partial'),
            child: const Text('تأكيد'),
          ),
          TextButton(onPressed: () => setState(() => _partial = false), child: const Text('إلغاء')),
        ]),
      ],
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_error!, style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
        ),
    ]);
  }
}
