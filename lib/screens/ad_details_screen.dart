import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/fmt.dart';
import '../core/location.dart';
import '../core/models.dart';
import '../widgets/ad_tile.dart';
import '../widgets/common.dart';

/// تفاصيل الإعلان: الصورة + بيانات الصيدلية (العنوان، الموبايل، الخريطة)
class AdDetailsScreen extends StatefulWidget {
  const AdDetailsScreen({super.key, required this.adId});
  final String adId;
  @override
  State<AdDetailsScreen> createState() => _AdDetailsScreenState();
}

class _AdDetailsScreenState extends State<AdDetailsScreen> {
  AdDetails? _d;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<Api>();
    try {
      final pos = await positionForAds(); // نفس موقع القايمة (متخزن)
      if (pos == null) {
        if (mounted) setState(() => _error = 'محتاجين موقعك علشان نعرض الإعلان');
        return;
      }
      final d = await api.adDetails(widget.adId, lat: pos.latitude, lng: pos.longitude);
      if (mounted) setState(() => _d = d);
    } catch (_) {
      if (mounted) setState(() => _error = 'الإعلان انتهى أو مش متاح دلوقتي');
    }
  }

  Future<void> _open(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط')));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurfaceVariant;
    final d = _d;
    final api = context.read<Api>();

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الإعلان')),
      body: SafeArea(
        child: d == null
            ? Center(child: _error != null ? Text(_error!, style: TextStyle(color: cs.error)) : const CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(fit: StackFit.expand, children: [
                      Container(color: kAdFallback),
                      Image.network(api.imageUrl(d.imagePath), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                Text(d.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  ArTag('ساري حتى ${fmtDate(d.endDate.toLocal())}'),
                  if (d.governorate.isNotEmpty) ArTag(d.governorate),
                ]),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Icon(Icons.local_pharmacy_outlined, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(d.pharmacyName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                    ]),
                    if (d.contact.address != null && d.contact.address!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.place_outlined, size: 20, color: muted),
                        const SizedBox(width: 8),
                        Expanded(child: Text(d.contact.address!)),
                      ]),
                    ],
                    const SizedBox(height: 12),
                    Row(children: [
                      Icon(Icons.call_outlined, size: 20, color: muted),
                      const SizedBox(width: 8),
                      Expanded(child: SelectableText(d.contact.phone, textDirection: TextDirection.ltr, textAlign: TextAlign.start)),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          onPressed: () => _open('tel:${d.contact.phone}'),
                          icon: const Icon(Icons.call),
                          label: const Text('اتصال'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          onPressed: () => _open(d.contact.mapsUrl.isNotEmpty
                              ? d.contact.mapsUrl
                              : 'https://www.google.com/maps/search/?api=1&query=${d.contact.lat},${d.contact.lng}'),
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('الموقع على الخريطة'),
                        ),
                      ),
                    ]),
                  ]),
                ),
                if (d.linkUrl != null && d.linkUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: () => _open(d.linkUrl!),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('فتح رابط الإعلان'),
                  ),
                ],
              ]),
      ),
    );
  }
}
