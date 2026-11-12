import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/config.dart';
import '../core/fmt.dart';
import '../core/location.dart';
import '../core/models.dart';
import '../widgets/ad_tile.dart';
import 'ad_details_screen.dart';

/// كل الإعلانات الجارية (الأحدث الأول). الرئيسية بتعرض آخر 5 بس.
class AdsScreen extends StatefulWidget {
  const AdsScreen({super.key});
  @override
  State<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends State<AdsScreen> {
  static const _pageSize = 12;
  final _scroll = ScrollController();
  final List<Ad> _items = [];
  bool _loading = true, _loadingMore = false, _more = true, _noLocation = false;
  String? _error;
  double _lat = 0, _lng = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<Api>();
    final pos = await positionForAds(ask: true);
    if (!mounted) return;
    if (pos == null) {
      setState(() {
        _noLocation = true;
        _items.clear();
        _loading = false;
      });
      return;
    }
    _lat = pos.latitude;
    _lng = pos.longitude;
    try {
      final r = await api.ads(lat: _lat, lng: _lng, take: _pageSize, skip: 0);
      if (!mounted) return;
      setState(() {
        _noLocation = false;
        _items
          ..clear()
          ..addAll(r);
        _more = r.length == _pageSize;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_more || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final r = await context.read<Api>().ads(lat: _lat, lng: _lng, take: _pageSize, skip: _items.length);
      if (!mounted) return;
      setState(() {
        final seen = _items.map((a) => a.id).toSet();
        _items.addAll(r.where((a) => !seen.contains(a.id))); // لو إعلان جديد نزل وإحنا بنتصفح
        _more = r.length == _pageSize;
      });
    } catch (_) {/* بنحاول تاني لما يسحب لتحت */}
    if (mounted) setState(() => _loadingMore = false);
  }

  void _open(Ad a) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdDetailsScreen(adId: a.id)));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurfaceVariant;

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_noLocation) {
      body = ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(32), children: [
        const SizedBox(height: 40),
        Icon(Icons.location_off_outlined, size: 56, color: muted),
        const SizedBox(height: 12),
        const Center(child: Text('محتاجين موقعك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
        const SizedBox(height: 8),
        Text('الإعلانات بتظهر بس للصيدليات اللي في نطاق ${kAdRadiusKm.toStringAsFixed(0)} كم منك. فعّل الموقع وإذن التطبيق وجرّب تاني.',
            textAlign: TextAlign.center, style: TextStyle(color: muted)),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => Geolocator.openAppSettings(), child: const Text('فتح الإعدادات')),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {
            setState(() => _loading = true);
            _load();
          },
          child: const Text('إعادة المحاولة'),
        ),
      ]);
    } else if (_items.isEmpty) {
      body = ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(32), children: [
        const SizedBox(height: 40),
        Icon(Icons.campaign_outlined, size: 56, color: muted),
        const SizedBox(height: 12),
        Center(
          child: Text(_error ?? 'مفيش إعلانات قريبة منك دلوقتي',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _error != null ? cs.error : null)),
        ),
        if (_error == null) ...[
          const SizedBox(height: 8),
          Text('إعلانات الصيدليات اللي في نطاق ${kAdRadiusKm.toStringAsFixed(0)} كم منك هتظهر هنا أول ما تتنشر.', textAlign: TextAlign.center, style: TextStyle(color: muted)),
        ],
      ]);
    } else {
      body = ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _items.length + (_more ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= _items.length) {
            return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
          }
          final a = _items[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AdTile(ad: a, height: 190, onTap: () => _open(a)),
              if (a.endDate != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                  child: Text('ساري حتى ${fmtDate(a.endDate!.toLocal())}', style: TextStyle(color: muted, fontSize: 12)),
                ),
            ]),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('الإعلانات')),
      body: SafeArea(child: RefreshIndicator(onRefresh: _load, child: body)),
    );
  }
}
