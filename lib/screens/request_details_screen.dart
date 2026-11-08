import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/auth_state.dart';
import '../core/models.dart';
import '../core/realtime.dart';
import '../widgets/common.dart';
import '../widgets/radar.dart';
import '../core/theme.dart';
/// الصيدليات اللي اتبعتلها الطلب + حالة الرد. بتتحدث لايف (SignalR) + تحديث دوري + سحب للتحديث.
class RequestDetailsScreen extends StatefulWidget {
  const RequestDetailsScreen({super.key, required this.requestId});
  final String requestId;
  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  RequestDetails? _d;
  String? _error;
  bool _expanding = false;
  DateTime _now = DateTime.now();
  StreamSubscription<void>? _sub;
  Timer? _poll, _tick;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = context.read<RealtimeService>().updates.listen((_) => _load());
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _load());
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await context.read<Api>().requestDetails(widget.requestId);
      if (mounted) {
        setState(() {
          _d = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && _d == null) setState(() => _error = apiError(e));
    }
  }

  Future<void> _expand(RequestDetails d) async {
    final next = Settings.radii.firstWhere((r) => r > d.radiusKm, orElse: () => d.radiusKm);
    if (next <= d.radiusKm) return;
    setState(() => _expanding = true);
    try {
      final added = await context.read<Api>().expand(d.id, next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(added > 0 ? 'اتبعت الطلب لـ $added صيدلية جديدة (نطاق ${next.toStringAsFixed(0)} كم)' : 'مفيش صيدليات جديدة في النطاق ده')));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiError(e))));
    } finally {
      if (mounted) setState(() => _expanding = false);
    }
  }

  Future<void> _open(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط')));
  }

  String _remaining(DateTime exp) {
    final m = exp.difference(_now).inMinutes;
    if (m <= 0) return 'انتهى';
    final h = m ~/ 60;
    return h > 0 ? 'متبقي $h ساعة و ${m % 60} دقيقة' : 'متبقي $m دقيقة';
  }

  int _rank(String s) => (s == 'Available' || s == 'Partial' || s == 'Delivered') ? 0 : (s == 'Pending' ? 1 : 2);

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
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  AppCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d.drugNameEn, textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text('${d.drugNameAr} · ${d.quantity} علبة', style: TextStyle(color: muted)),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.timer_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text(d.isExpired ? 'انتهى وقت الطلب' : _remaining(d.expiresAt), style: TextStyle(color: muted, fontSize: 13)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: RadarView(
                      radiusKm: d.radiusKm,
                      animate: !d.isExpired && d.availableCount == 0,
                      pins: [for (final p in d.pharmacies) RadarPin(p.pharmacyId, p.status, p.distanceKm)],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'اتبعت لـ ${d.pharmacies.length} صيدلية في نطاق ${d.radiusKm.toStringAsFixed(0)} كم · ${d.answered} ردّت',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted),
                  ),
                  if (!d.isExpired && d.availableCount == 0 && d.radiusKm < Settings.radii.last) ...[
                    const SizedBox(height: 10),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: _expanding ? null : () => _expand(d),
                        icon: const Icon(Icons.zoom_out_map),
                        label: const Text('وسّع النطاق'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  for (final p in ([...d.pharmacies]..sort((a, b) {
                        final r = _rank(a.status).compareTo(_rank(b.status));
                        return r != 0 ? r : a.distanceKm.compareTo(b.distanceKm);
                      })))
                    Padding(padding: const EdgeInsets.only(bottom: 10), child: _pharmacyCard(p, d, muted)),
                  const SizedBox(height: 8),
                  Text('الرد بـ "متوفر" بيعني الدواء متاح لحظة الرد، مش حجز مضمون. كلّم الصيدلية قبل ما تروح.',
                      style: TextStyle(color: muted, fontSize: 12, height: 1.5)),
                ]),
              ),
      ),
    );
  }

  Widget _pharmacyCard(PharmacyReply p, RequestDetails d, Color muted) {
    final c = p.contact;
    final good = p.status == 'Available' || p.status == 'Partial';
    final status = (p.status == 'Pending' && d.isExpired) ? 'Expired' : p.status;
    return AppCard(
      borderColor: good ? pinColor('Available') : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700))),
          StatusChip(label: statusLabel(status, qty: p.availableQty, total: d.quantity), status: status),
        ]),
        const SizedBox(height: 2),
        Text('${p.distanceKm.toStringAsFixed(1)} كم', style: TextStyle(color: muted, fontSize: 12)),
        if (good && c != null) ...[
          if (c.address != null && c.address!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(c.address!)),
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(c.phone, textDirection: TextDirection.ltr, style: TextStyle(color: muted))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () => _open('tel:${c.phone}'),
                icon: const Icon(Icons.call),
                label: const Text('اتصال'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () => _open(c.mapsUrl.isNotEmpty ? c.mapsUrl : 'https://www.google.com/maps/search/?api=1&query=${c.lat},${c.lng}'),
                icon: const Icon(Icons.map_outlined),
                label: const Text('الخريطة'),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}
