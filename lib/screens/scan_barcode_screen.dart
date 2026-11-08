import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/models.dart';
import 'search_screen.dart';

/// مسح الباركود أو كتابته. بيرجّع Drug.
class ScanBarcodeScreen extends StatefulWidget {
  const ScanBarcodeScreen({super.key});
  @override
  State<ScanBarcodeScreen> createState() => _ScanBarcodeScreenState();
}

class _ScanBarcodeScreenState extends State<ScanBarcodeScreen> {
  final _controller = MobileScannerController();
  final _manual = TextEditingController();
  bool _handled = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (_handled) return;
    for (final b in cap.barcodes) {
      final code = normalizeBarcode(b.rawValue);
      if (code != null) {
        _handled = true;
        _lookup(code);
        return;
      }
    }
  }

  Future<void> _lookup(String code) async {
    setState(() => _error = null);
    try {
      final d = await context.read<Api>().drugByBarcode(code);
      if (!mounted) return;
      if (d != null) {
        Navigator.of(context).pop(d);
        return;
      }
      final search = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('الباركود ده مش عندنا'),
          content: const Text('دوّر على الدواء بالاسم وهنربطه بالباركود ده، وبكده المرة الجاية هيتعرف أوتوماتيك.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ابحث بالاسم')),
          ],
        ),
      );
      if (!mounted) return;
      if (search == true) {
        final picked = await Navigator.of(context).push<Drug>(MaterialPageRoute(builder: (_) => SearchScreen(linkBarcode: code)));
        if (!mounted) return;
        if (picked != null) {
          Navigator.of(context).pop(picked);
          return;
        }
      }
      _handled = false;
    } catch (e) {
      if (mounted) {
        setState(() => _error = apiError(e));
        _handled = false;
      }
    }
  }

  void _submitManual() {
    final code = normalizeBarcode(_manual.text);
    if (code == null) {
      setState(() => _error = 'الباركود لازم يكون أرقام فقط (8 إلى 14 رقم)');
      return;
    }
    _handled = true;
    _lookup(code);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('مسح الباركود')),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Stack(alignment: Alignment.center, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: MobileScanner(controller: _controller, onDetect: _onDetect),
              ),
              IgnorePointer(
                child: Container(
                  width: 260,
                  height: 160,
                  decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const Positioned(
                bottom: 16,
                child: Text('وجّه الكاميرا ناحية الباركود على العلبة',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, shadows: [Shadow(blurRadius: 6)])),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _manual,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'أو اكتب رقم الباركود', border: OutlineInputBorder()),
                    onSubmitted: (_) => _submitManual(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(80, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: _submitManual,
                  child: const Text('بحث'),
                ),
              ]),
              if (_error != null)
                Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: cs.error))),
            ]),
          ),
        ]),
      ),
    );
  }
}
