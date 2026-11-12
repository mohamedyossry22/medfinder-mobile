import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/auth_state.dart';
import '../core/config.dart';
import '../core/models.dart';
import '../core/push.dart';
import '../core/realtime.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';
import '../widgets/request_card.dart';
import 'new_request_screen.dart';
import 'request_details_screen.dart';
import 'scan_barcode_screen.dart';
import 'scan_text_screen.dart';
import 'search_screen.dart';
import 'complaints_screen.dart';
import '../widgets/ad_tile.dart';
import 'ad_details_screen.dart';
import 'ads_screen.dart';
import '../core/location.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Ad> _ads = [];
  List<RequestSummary> _active = [];
  bool _loading = true;
  StreamSubscription<void>? _sub;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RealtimeService>().start();
      context.read<PushService>().init();
      _load();
    });
    // الحالة بتتحدث لايف أول ما صيدلية ترد، وتحديث دوري احتياطي
    _sub = context.read<RealtimeService>().updates.listen((_) => _load());
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  bool _askedLocation = false;

  Future<void> _load() async {
    final api = context.read<Api>();
    try {
      final r = await api.myRequests(activeOnly: true);
      if (mounted) setState(() => _active = r);
    } catch (_) {/* الصفحة تفضل شغالة */}
    if (mounted) setState(() => _loading = false);
    _loadAds(); // مش بنستناها: الموقع ممكن ياخد وقت
  }

  /// إعلانات الصيدليات اللي في نطاق 10 كم منك. من غير موقع مفيش إعلانات.
  Future<void> _loadAds() async {
    final api = context.read<Api>();
    final pos = await positionForAds(ask: !_askedLocation);
    _askedLocation = true;
    if (!mounted) return;
    if (pos == null) {
      if (_ads.isNotEmpty) setState(() => _ads = []);
      return;
    }
    try {
      final ads = await api.ads(lat: pos.latitude, lng: pos.longitude, take: 5);
      if (mounted) setState(() => _ads = ads);
    } catch (_) {/* بنحاول تاني في التحديث الجاي */}
  }

  /// أي مسار (كتابة / باركود / روشتة / علبة) بيرجّع Drug، وبعدها نكمل لصفحة الطلب
  Future<void> _go(Widget screen) async {
    final drug = await Navigator.of(context).push<Drug>(MaterialPageRoute(builder: (_) => screen));
    if (drug != null && mounted) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewRequestScreen(drug: drug)));
      _load();
    }
  }

  Future<void> _logout() async {
    await context.read<PushService>().unregister();
    await context.read<RealtimeService>().stop();
    if (mounted) await context.read<AuthState>().logout();
  }

  String get _greeting => DateTime.now().hour < 12 ? 'صباح الخير' : 'مساء الخير';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurfaceVariant;
    final name = (context.watch<AuthState>().name ?? '').split(' ').first;
    final radius = context.watch<Settings>().radiusKm;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Row(children: [
              const AppLogo(size: 34, showName: true),
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: 'القائمة',
                onSelected: (v) {
                  if (v == 'complaints') {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ComplaintsScreen()));
                  } else {
                    _logout();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'complaints', child: Text('الشكاوى')),
                  PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج')),
                ],
              ),
            ]),
            const SizedBox(height: 14),
            Text(name.isEmpty ? _greeting : '$_greeting يا $name', style: TextStyle(color: muted, fontSize: 13)),
            const Text('عايز تدوّر على إيه؟', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),

            // كبسولة البحث (أهم عنصر في الشاشة)
            Semantics(
              button: true,
              label: 'ابحث عن دواء',
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => _go(const SearchScreen()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: isDark(context) ? const Color(0xFF17211E) : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: cs.primary.withAlpha(120), width: 1.5),
                  ),
                  child: Row(children: [
                    Icon(Icons.search, color: cs.primary),
                    const SizedBox(width: 10),
                    Text('اسم الدواء أو المادة الفعالة', style: TextStyle(color: muted)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _Action(icon: Icons.document_scanner_outlined, label: 'روشتة', onTap: () => _go(const ScanTextScreen(kind: 'الروشتة'))),
              if (kEnableBarcode) _Action(icon: Icons.qr_code_scanner, label: 'باركود', onTap: () => _go(const ScanBarcodeScreen())),
              _Action(icon: Icons.inventory_2_outlined, label: 'علبة الدواء', onTap: () => _go(const ScanTextScreen(kind: 'علبة الدواء'))),
            ]),
            const SizedBox(height: 22),

            const Text('النطاق', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final r in Settings.radii)
                ChoiceChip(label: Text('${r.toStringAsFixed(0)} كم'), selected: radius == r, onSelected: (_) => context.read<Settings>().setRadius(r)),
            ]),
            const SizedBox(height: 22),

            // مساحة الإعلانات
            if (_ads.isNotEmpty) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('إعلانات الصيدليات', style: TextStyle(fontWeight: FontWeight.w700)),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdsScreen())),
                  child: const Text('عرض الكل', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
              _AdsCarousel(
                ads: _ads,
                onOpen: (a) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdDetailsScreen(adId: a.id))),
              ),
              const SizedBox(height: 22),
            ],

            // الطلبات اللي بيتم البحث عنها دلوقتي بس (الباقي في تاب "طلباتي")
            if (_active.isNotEmpty) ...[
              const Text('بنبحث عنها دلوقتي', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final r in _active)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RequestCard(
                    r: r,
                    onChanged: _load,
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RequestDetailsScreen(requestId: r.id)));
                      _load();
                    },
                  ),
                ),
            ] else if (!_loading)
              Center(child: Padding(padding: const EdgeInsets.all(12), child: Text('مفيش طلبات جارية دلوقتي', style: TextStyle(color: muted)))),
          ]),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: isDark(context) ? const Color(0xFF12322C) : const Color(0xFFE3F6F1), shape: BoxShape.circle),
              child: Icon(icon, size: 28, color: cs.primary),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _AdsCarousel extends StatefulWidget {
  const _AdsCarousel({required this.ads, required this.onOpen});
  final List<Ad> ads;
  final void Function(Ad) onOpen;
  @override
  State<_AdsCarousel> createState() => _AdsCarouselState();
}

class _AdsCarouselState extends State<_AdsCarousel> {
  final _page = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || widget.ads.length < 2 || !_page.hasClients) return;
      _page.animateToPage((_i + 1) % widget.ads.length, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 170,
        child: PageView.builder(
          controller: _page,
          itemCount: widget.ads.length,
          onPageChanged: (i) => setState(() => _i = i),
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AdTile(ad: widget.ads[i], onTap: () => widget.onOpen(widget.ads[i])),
          ),
        ),
      ),
      if (widget.ads.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var k = 0; k < widget.ads.length; k++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: k == _i ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(color: k == _i ? Theme.of(context).colorScheme.primary : Colors.grey.withAlpha(120), borderRadius: BorderRadius.circular(3)),
              ),
          ]),
        ),
    ]);
  }
}

