import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/models.dart';
import '../widgets/common.dart';

/// بحث بالاسم (عربي/إنجليزي/المادة الفعالة). المستخدم لازم يختار من القايمة، مفيش كتابة حرة.
/// بيرجّع Drug عن طريق Navigator.pop.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery, this.linkBarcode});
  final String? initialQuery;
  final String? linkBarcode; // لو جاي من باركود مش معروف: هنربطه بالدواء اللي يختاره
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _c = TextEditingController(text: widget.initialQuery ?? '');
  Timer? _deb;
  int _seq = 0;
  List<Drug> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if ((widget.initialQuery ?? '').trim().length >= 2) _search(widget.initialQuery!.trim());
  }

  @override
  void dispose() {
    _deb?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _deb?.cancel();
    final q = v.trim();
    if (q.length < 2) {
      setState(() {
        _results = [];
        _error = null;
        _loading = false;
      });
      return;
    }
    _deb = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String q) async {
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await context.read<Api>().searchDrugs(q);
      if (!mounted || seq != _seq) return;
      setState(() => _results = r);
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _error = apiError(e));
    } finally {
      if (mounted && seq == _seq) setState(() => _loading = false);
    }
  }

  Future<void> _pick(Drug d) async {
    final code = widget.linkBarcode;
    if (code != null) {
      try {
        await context.read<Api>().linkBarcode(code, d.id); // Crowdsourcing: صوتنا للربط
      } catch (_) {}
    }
    if (mounted) Navigator.of(context).pop(d);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('بحث عن دواء')),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _c,
              autofocus: true,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'اسم الدواء أو المادة الفعالة (عربي / English)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _c.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _c.clear();
                          _onChanged('');
                        }),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ),
          if (widget.linkBarcode != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Text('الباركود ${widget.linkBarcode} لسه مش عندنا. اختار الدواء الصح وهنربطه بيه، وبكده بتساعد غيرك.',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              ),
            ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _body(cs)),
        ]),
      ),
    );
  }

  Widget _body(ColorScheme cs) {
    if (_error != null) return Center(child: Text(_error!, style: TextStyle(color: cs.error)));
    if (_c.text.trim().length < 2) {
      return Center(child: Text('اكتب حرفين على الأقل', style: TextStyle(color: cs.onSurfaceVariant)));
    }
    if (!_loading && _results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text('ما لقيناش الدواء ده.\nجرّب اسم تاني، أو صوّر العلبة / الروشتة.',
              textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => DrugTile(drug: _results[i], onTap: () => _pick(_results[i])),
    );
  }
}
