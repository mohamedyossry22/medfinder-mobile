import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/models.dart';
import '../core/realtime.dart';
import '../widgets/request_card.dart';
import 'request_details_screen.dart';

/// صفحة "طلباتي": كل طلباتك السابقة والحالية
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

enum _Filter { all, active, done }

class _OrdersScreenState extends State<OrdersScreen> {
  List<RequestSummary> _all = [];
  bool _loading = true;
  String? _error;
  _Filter _filter = _Filter.all;
  StreamSubscription<void>? _sub;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = context.read<RealtimeService>().updates.listen((_) => _load());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await context.read<Api>().myRequests();
      if (mounted) {
        setState(() {
          _all = r;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && _all.isEmpty) setState(() => _error = apiError(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  bool _isActive(RequestSummary r) => !r.isExpired && !r.isClosed;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final list = _all.where((r) => switch (_filter) {
          _Filter.all => true,
          _Filter.active => _isActive(r),
          _Filter.done => !_isActive(r),
        }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Wrap(spacing: 8, children: [
              ChoiceChip(label: const Text('الكل'), selected: _filter == _Filter.all, onSelected: (_) => setState(() => _filter = _Filter.all)),
              ChoiceChip(label: const Text('جارية'), selected: _filter == _Filter.active, onSelected: (_) => setState(() => _filter = _Filter.active)),
              ChoiceChip(label: const Text('منتهية'), selected: _filter == _Filter.done, onSelected: (_) => setState(() => _filter = _Filter.done)),
            ]),
            const SizedBox(height: 12),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (!_loading && _error == null && list.isEmpty)
              Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('مفيش طلبات هنا', style: TextStyle(color: muted)))),
            for (final r in list)
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
          ]),
        ),
      ),
    );
  }
}
