import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api.dart';
import '../../core/auth_state.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/native.dart';
import '../../core/pharmacy_state.dart';
import '../../core/push.dart';
import '../../core/realtime.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/logo.dart';
import 'pharmacy_incoming_tab.dart';
import 'pharmacy_ready_tab.dart';
import '../complaints_screen.dart';

/// واجهة الصيدلية: الطلبات الجديدة (لايف) | جاري التسليم
class PharmacyShell extends StatefulWidget {
  const PharmacyShell({super.key});
  @override
  State<PharmacyShell> createState() => _PharmacyShellState();
}

class _PharmacyShellState extends State<PharmacyShell> with WidgetsBindingObserver {
  PharmacyMe? _me;
  bool _loading = true;
  String? _error;
  int _tab = 0;
  PushStatus _push = PushStatus.ok;
  late final PharmacyState _store;

  bool get _approved => _me?.status == 'Approved';

  @override
  void initState() {
    super.initState();
    _store = context.read<PharmacyState>();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMe());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // رجعنا للتطبيق: الاتصال ممكن يكون وقع في الخلفية، ويمكن في طلبات اتأخرت
    if (s == AppLifecycleState.resumed && _approved && mounted) {
      context.read<RealtimeService>().ensureConnected();
      context.read<PharmacyState>().reload();
      context.read<PushService>().init().then((_) => _checkPush());
    }
  }

  Future<void> _loadMe() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final m = await context.read<Api>().pharmacyMe();
      if (!mounted) return;
      setState(() => _me = m);
      if (m.status == 'Approved') await _startLive();
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startLive() async {
    final rt = context.read<RealtimeService>();
    final st = context.read<PharmacyState>();
    final push = context.read<PushService>();
    await Future.wait([rt.start(), st.init(), push.init()]);
    await _checkPush();
  }

  Future<void> _checkPush() async {
    final s = await context.read<PushService>().status();
    if (mounted) setState(() => _push = s);
  }

  Future<void> _logout() async {
    await context.read<PushService>().unregister();
    await context.read<RealtimeService>().stop();
    if (mounted) await context.read<AuthState>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurfaceVariant;
    final st = context.watch<PharmacyState>();
    final me = _me;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            child: Row(children: [
              const AppLogo(size: 34, showName: true),
              const Spacer(),
              if (_approved) _LivePill(rt: context.read<RealtimeService>()),
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
          ),
          if (me != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('${me.name} · ${me.pharmacistName} · ${me.governorate}', style: TextStyle(color: muted, fontSize: 13)),
              ),
            ),
          if (_approved && _push != PushStatus.ok) _PushBanner(status: _push),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _approved
                    ? IndexedStack(index: _tab, children: const [PharmacyIncomingTab(), PharmacyReadyTab()])
                    : _StatusView(me: me, error: _error, onRefresh: _loadMe),
          ),
        ]),
      ),
      bottomNavigationBar: _approved
          ? NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: [
                NavigationDestination(
                  icon: _Count(n: st.activeIncoming.length, child: const Icon(Icons.notifications_none)),
                  selectedIcon: _Count(n: st.activeIncoming.length, child: const Icon(Icons.notifications)),
                  label: 'الطلبات الجديدة',
                ),
                NavigationDestination(
                  icon: _Count(n: st.activeReady.length, ok: true, child: const Icon(Icons.local_shipping_outlined)),
                  selectedIcon: _Count(n: st.activeReady.length, ok: true, child: const Icon(Icons.local_shipping)),
                  label: 'جاري التسليم',
                ),
              ],
            )
          : null,
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.n, required this.child, this.ok = false});
  final int n;
  final Widget child;
  final bool ok;
  @override
  Widget build(BuildContext context) {
    if (n == 0) return child;
    final s = statusStyle('Available', isDark(context));
    return Badge(
      label: Text('$n'),
      backgroundColor: ok ? s.fg : kAccent,
      textColor: ok ? (isDark(context) ? const Color(0xFF10201C) : Colors.white) : const Color(0xFF10201C),
      child: child,
    );
  }
}

/// مؤشر "متصل Live" (نفس .live في الويب)
class _LivePill extends StatelessWidget {
  const _LivePill({required this.rt});
  final RealtimeService rt;
  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return ValueListenableBuilder<bool>(
      valueListenable: rt.connected,
      builder: (_, on, __) {
        final s = statusStyle(on ? 'Available' : 'Unavailable', dark);
        return Container(
          margin: const EdgeInsetsDirectional.only(end: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: s.fg, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(on ? 'متصل Live' : 'جاري إعادة الاتصال...', style: TextStyle(color: s.fg, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        );
      },
    );
  }
}

/// تنبيه لو الإشعارات مش شغالة (مهم: من غيرها مش هيجيلك طلب والتطبيق مقفول)
class _PushBanner extends StatelessWidget {
  const _PushBanner({required this.status});
  final PushStatus status;
  @override
  Widget build(BuildContext context) {
    final s = statusStyle('Partial', isDark(context));
    final denied = status == PushStatus.denied;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(Icons.notifications_off_outlined, color: s.fg),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            denied ? 'الإشعارات مقفولة: مش هيوصلك تنبيه بالطلبات الجديدة لما التطبيق يكون مقفول.' : 'الإشعارات لسه ما اتظبطتش على الجهاز ده (Firebase).',
            style: TextStyle(color: s.fg, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        if (denied) TextButton(onPressed: Native.openNotificationSettings, child: const Text('فعّلها')),
      ]),
    );
  }
}

/// حالة الحساب لو مش معتمد (نفس صفحة الويب)
class _StatusView extends StatelessWidget {
  const _StatusView({required this.me, required this.error, required this.onRefresh});
  final PharmacyMe? me;
  final String? error;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurfaceVariant;
    final m = me;
    if (m == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(error ?? 'تعذر تحميل بيانات الحساب', style: TextStyle(color: cs.error)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRefresh, child: const Text('إعادة المحاولة')),
        ]),
      );
    }
    final text = switch (m.status) {
      'Pending' => 'جاري مراجعة بيانات صيدليتك ورقم الرخصة. هيوصلك رسالة بمجرد الاعتماد، وبعدها تقدر تستقبل الطلبات.',
      'Rejected' => 'تم رفض الطلب. السبب: ${(m.reason ?? '').isEmpty ? 'غير محدد' : m.reason}',
      _ => 'الحساب موقوف حاليًا${(m.reason ?? '').isEmpty ? '' : ': ${m.reason}'}. تواصل مع الدعم.',
    };
    return ListView(padding: const EdgeInsets.all(16), children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('حالة الحساب: ${pharmacyStatusAr(m.status)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(color: muted)),
          const SizedBox(height: 14),
          OutlinedButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh), label: const Text('تحديث الحالة')),
        ]),
      ),
    ]);
  }
}
