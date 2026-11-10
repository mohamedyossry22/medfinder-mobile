import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/models.dart';
import '../widgets/common.dart';
import 'search_screen.dart';

class _Group {
  final String text;
  final String? strength, confidence;
  final List<Drug> drugs;
  _Group(this.text, this.strength, this.confidence, this.drugs);
}

const _noise = {'rx', 'tab', 'tabs', 'tablet', 'tablets', 'cap', 'caps', 'capsule', 'capsules', 'syp', 'syrup', 'inj', 'amp', 'daily', 'bid', 'tid', 'od', 'mg', 'ml', 'gm', 'the', 'and', 'for', 'take', 'after', 'before', 'meal', 'meals'};

/// احتياطي (لو الذكاء الاصطناعي مش متاح): أسماء مرشحة من القراءة المحلية
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

/// تصوير روشتة أو علبة دواء ← الذكاء الاصطناعي يقرأ الأسماء ← مطابقة مع قاعدة الأدوية ← المستخدم يختار.
/// لو الخدمة مش متاحة بنرجع للقراءة المحلية (ML Kit).
class ScanTextScreen extends StatefulWidget {
  const ScanTextScreen({super.key, required this.kind});
  final String kind; // 'الروشتة' أو 'علبة الدواء'
  @override
  State<ScanTextScreen> createState() => _ScanTextScreenState();
}

class _ScanTextScreenState extends State<ScanTextScreen> {
  bool _busy = false, _scanned = false;
  String? _error, _note;
  List<_Group> _groups = [];

  Future<void> _pick(ImageSource source) async {
    // نصغّر الصورة: أسرع في الرفع وأرخص في المعالجة
    final x = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1600);
    if (x == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _note = null;
      _scanned = false;
    });
    try {
      List<_Group> groups;
      try {
        groups = await _aiScan(x.path);
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code == 503 || code == 502 || code == 429) {
          _note = code == 429
              ? 'وصلت للحد الأقصى للمسح الذكي لحد الساعة دي، فاستخدمنا القراءة العادية (أقل دقة).'
              : 'المسح الذكي مش متاح دلوقتي، فاستخدمنا القراءة العادية (أقل دقة).';
          groups = await _localScan(x.path);
        } else {
          rethrow;
        }
      }
      if (mounted) {
        setState(() {
          _groups = groups;
          _scanned = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e is DioException ? apiError(e) : 'تعذر قراءة الصورة، حاول تصوّر بإضاءة أحسن');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<_Group>> _aiScan(String path) async {
    final items = await context.read<Api>().scanImage(path);
    return [for (final i in items) _Group(i.text, i.strength, i.confidence, i.matches)];
  }

  Future<List<_Group>> _localScan(String path) async {
    final api = context.read<Api>();
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final r = await recognizer.processImage(InputImage.fromFilePath(path));
      final lines = _candidates(r);
      return await Future.wait(lines.map((q) async {
        try {
          return _Group(q, null, null, await api.searchDrugs(q, limit: 3));
        } catch (_) {
          return _Group(q, null, null, <Drug>[]);
        }
      }));
    } finally {
      recognizer.close();
    }
  }

  Future<void> _manualSearch([String? q]) async {
    final d = await Navigator.of(context).push<Drug>(MaterialPageRoute(builder: (_) => SearchScreen(initialQuery: q)));
    if (d != null && mounted) Navigator.of(context).pop(d);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurfaceVariant;
    final seen = <String>{};

    return Scaffold(
      appBar: AppBar(title: Text('مسح ${widget.kind}')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          AppCard(
            child: Text(
              'صوّر ${widget.kind} بوضوح، والذكاء الاصطناعي هيقرا أسماء الأدوية ونقترحلك الأقرب من قاعدة الأدوية.\n'
              'الخط المكتوب بالإيد ممكن يتقري غلط، فاختار الدواء الصح بنفسك. الصورة بتتبعت للقراءة بس وما بنخزنهاش.',
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
          if (_busy)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text('بنقرا الصورة...', style: TextStyle(color: muted)),
                ]),
              ),
            ),
          if (_error != null) Text(_error!, style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
          if (_note != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_note!, style: TextStyle(color: muted, fontSize: 12))),
          if (_scanned && _groups.isEmpty && !_busy)
            Text('ما قدرناش نتعرف على دواء في الصورة. جرّب تصوّر أقرب وبإضاءة أحسن، أو ابحث بالاسم.', style: TextStyle(color: muted)),
          for (final g in _groups) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Text(
                'قرأنا: "${g.text}"${g.strength != null && g.strength!.isNotEmpty ? ' (${g.strength})' : ''}'
                '${g.confidence == 'low' ? ' · غير واضح' : ''}',
                style: TextStyle(color: muted, fontWeight: FontWeight.w600),
              ),
            ),
            if (g.drugs.isEmpty)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(onPressed: () => _manualSearch(g.text), icon: const Icon(Icons.search), label: Text('ابحث عن "${g.text}"')),
              )
            else
              for (final d in g.drugs.where((d) => seen.add(d.id)))
                Padding(padding: const EdgeInsets.only(bottom: 8), child: DrugTile(drug: d, onTap: () => Navigator.of(context).pop(d))),
          ],
          const SizedBox(height: 12),
          TextButton.icon(onPressed: _manualSearch, icon: const Icon(Icons.search), label: const Text('أو ابحث بالاسم')),
        ]),
      ),
    );
  }
}
