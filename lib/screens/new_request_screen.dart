import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/auth_state.dart';
import '../core/location.dart';
import '../core/models.dart';
import '../widgets/common.dart';
import 'request_details_screen.dart';

/// الدواء اتحدد (من قاعدة الأدوية): نختار الكمية والنطاق ونبعت.
class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key, required this.drug});
  final Drug drug;
  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  int _qty = 1;
  Position? _pos;
  String? _locError;
  bool _locSettings = false, _locating = true, _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locError = null;
    });
    try {
      final p = await currentPosition();
      if (mounted) setState(() => _pos = p);
    } on LocationException catch (e) {
      if (mounted) {
        setState(() {
          _locError = e.message;
          _locSettings = e.openSettings;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locError = 'تعذر تحديد موقعك، حاول تاني');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _send() async {
    final pos = _pos;
    if (pos == null) return;
    final radius = context.read<Settings>().radiusKm;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final r = await context.read<Api>().createRequest(
          drugId: widget.drug.id, quantity: _qty, lat: pos.latitude, lng: pos.longitude, radiusKm: radius);
      if (!mounted) return;
      if (r.requestId == null) {
        await _noPharmacies(radius);
        return;
      }
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => RequestDetailsScreen(requestId: r.requestId!)));
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _noPharmacies(double radius) async {
    final next = Settings.radii.firstWhere((r) => r > radius, orElse: () => radius);
    final widen = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('مفيش صيدليات في النطاق ده'),
        content: Text('مفيش صيدليات معتمدة في نطاق ${radius.toStringAsFixed(0)} كم من موقعك.'
            '${next > radius ? ' تحب نوسّع النطاق لـ ${next.toStringAsFixed(0)} كم؟' : ''}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إغلاق')),
          if (next > radius) FilledButton(onPressed: () => Navigator.pop(c, true), child: Text('وسّع لـ ${next.toStringAsFixed(0)} كم')),
        ],
      ),
    );
    if (widen == true && mounted) {
      context.read<Settings>().setRadius(next);
      _send();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurfaceVariant;
    final radius = context.watch<Settings>().radiusKm;
    final d = widget.drug;

    return Scaffold(
      appBar: AppBar(title: const Text('طلب الدواء')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.nameEn, textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              if (d.nameAr.isNotEmpty) Text(d.nameAr, style: TextStyle(color: muted)),
              if (d.scientificName != null) ...[
                const SizedBox(height: 8),
                SoftTag(d.scientificName!),
              ],
            ]),
          ),
          const SizedBox(height: 18),
          const Text('الكمية', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          AppCard(
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('عدد العلب', style: TextStyle(color: muted)),
              Row(children: [
                IconButton.filledTonal(tooltip: 'أقل', onPressed: _qty > 1 ? () => setState(() => _qty--) : null, icon: const Icon(Icons.remove)),
                SizedBox(width: 48, child: Text('$_qty', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                IconButton.filledTonal(tooltip: 'أكتر', onPressed: _qty < 20 ? () => setState(() => _qty++) : null, icon: const Icon(Icons.add)),
              ]),
            ]),
          ),
          const SizedBox(height: 18),
          const Text('النطاق', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final r in Settings.radii)
              ChoiceChip(
                label: Text('${r.toStringAsFixed(0)} كم'),
                selected: radius == r,
                onSelected: (_) => context.read<Settings>().setRadius(r),
              ),
          ]),
          const SizedBox(height: 18),
          AppCard(
            child: Row(children: [
              Icon(_pos != null ? Icons.my_location : Icons.location_off_outlined, color: _pos != null ? cs.primary : muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _locating ? 'جاري تحديد موقعك...' : (_pos != null ? 'تم تحديد موقعك' : (_locError ?? '')),
                  style: TextStyle(color: _pos != null ? cs.onSurface : muted),
                ),
              ),
              if (!_locating && _pos == null) ...[
                if (_locSettings) TextButton(onPressed: Geolocator.openLocationSettings, child: const Text('الإعدادات')),
                TextButton(onPressed: _locate, child: const Text('إعادة')),
              ],
            ]),
          ),
          const SizedBox(height: 8),
          Text('موقعك بيتستخدم لتحديد الصيدليات القريبة بس، والصيدلية ما بتشوفش اسمك ولا رقمك.',
              style: TextStyle(color: muted, fontSize: 12)),
          if (_error != null)
            Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: cs.error, fontWeight: FontWeight.w600))),
          const SizedBox(height: 22),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: (_pos == null || _sending) ? null : _send,
            child: _sending
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('ابعت الطلب للصيدليات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}
