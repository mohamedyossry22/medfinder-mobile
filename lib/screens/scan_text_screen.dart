import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/models.dart';
import '../widgets/common.dart';
import 'search_screen.dart';

class _Match {
  final String text;
  final List<Drug> drugs;
  _Match(this.text, this.drugs);
}

const _noise = {'rx', 'tab', 'tabs', 'tablet', 'tablets', 'cap', 'caps', 'capsule', 'capsules', 'syp', 'syrup', 'inj', 'amp', 'daily', 'bid', 'tid', 'od', 'mg', 'ml', 'gm', 'the', 'and', 'for', 'take', 'after', 'before', 'meal', 'meals'};

/// بيطلّع أسماء مرشحة من النص المقروء (أسطر قصيرة بحروف إنجليزي)
List<String> _candidates(RecognizedText r) {
  final out = <String>[];
  for (final b in r.blocks) {
    for (final l in b.lines) {
      final cleaned = l.text.replaceAll(RegExp(r'[^A-Za-z\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      final words = cleaned.split(' ').where((w) => w.length >= 3 && !_noise.contains(w.toLowerCase())).take(3).toList();
      if (words.isEmpty) continue;
      final q = words.join(' ');
      if (q.length >= 4 && !out.contains(q)) out.add(q);
    }
  }
  return out.take(10).toList();
}

/// تصوير روشتة أو علبة دواء → قراءة النص (على الجهاز) → مطابقة تقريبية مع قاعدة الأدوية → "هل تقصد؟"
class ScanTextScreen extends StatefulWidget {
  const ScanTextScreen({super.key, required this.kind});
  final String kind; // 'الروشتة' أو 'علبة الدواء'
  @override
  State<ScanTextScreen> createState() => _ScanTextScreenState();
}

class _ScanTextScreenState extends State<ScanTextScreen> {
  bool _busy = false, _scanned = false;
  String? _error;
  List<_Match> _matches = [];

  Future<void> _pick(ImageSource source) async {
    final x = await ImagePicker().pickImage(source: source, imageQuality: 90, maxWidth: 2200);
    if (x == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _scanned = false;
    });
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final r = await recognizer.processImage(InputImage.fromFilePath(x.path));
      final api = context.read<Api>();
      final lines = _candidates(r);
      final results = await Future.wait(lines.map((q) async {
        try {
          return _Match(q, await api.searchDrugs(q, limit: 3));
        } catch (_) {
          return _Match(q, <Drug>[]);
        }
      }));
      // نشيل الأسطر اللي ملهاش اقتراحات، وما نكررش نفس الدواء
      final seen = <String>{};
      final matches = <_Match>[];
      for (final m in results) {
        final fresh = m.drugs.where((d) => seen.add(d.id)).toList();
        if (fresh.isNotEmpty) matches.add(_Match(m.text, fresh));
      }
      if (mounted) {
        setState(() {
          _matches = matches;
          _scanned = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر قراءة الصورة، حاول تصوّر بإضاءة أحسن');
    } finally {
      recognizer.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _manualSearch() async {
    final d = await Navigator.of(context).push<Drug>(MaterialPageRoute(builder: (_) => const SearchScreen()));
    if (d != null && mounted) Navigator.of(context).pop(d);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: Text('مسح ${widget.kind}')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          AppCard(
            child: Text(
              'صوّر ${widget.kind} بوضوح وهنقرأ أسماء الأدوية المطبوعة بالإنجليزي ونقترحلك الأقرب من قاعدة الأدوية.\n'
              'الخط المكتوب بالإيد ممكن ما يتقراش صح، فتأكد من الدواء بنفسك قبل ما تكمّل.',
              style: TextStyle(color: muted, height: 1.6),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: _busy ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('الكاميرا'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('المعرض'),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          if (_busy) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          if (_error != null) Text(_error!, style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
          if (_scanned && _matches.isEmpty && !_busy)
            Text('ما قدرناش نتعرف على دواء في الصورة. جرّب تصوّر أقرب، أو ابحث بالاسم.', style: TextStyle(color: muted)),
          for (final m in _matches) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Text('قرأنا: "${m.text}" — هل تقصد؟', style: TextStyle(color: muted, fontWeight: FontWeight.w600)),
            ),
            for (final d in m.drugs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DrugTile(drug: d, onTap: () => Navigator.of(context).pop(d)),
              ),
          ],
          const SizedBox(height: 12),
          TextButton.icon(onPressed: _manualSearch, icon: const Icon(Icons.search), label: const Text('أو ابحث بالاسم')),
        ]),
      ),
    );
  }
}
