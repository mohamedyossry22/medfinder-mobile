import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/auth_state.dart';
import '../core/fmt.dart';
import '../core/models.dart';
import '../widgets/common.dart';

/// شكاواي: بتظهر للمستخدم وللصيدلية. الشكوى بتروح للأدمن، وردّه بيظهر هنا وبيوصل إشعار.
class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});
  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  List<MyComplaint>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await context.read<Api>().myComplaints();
      if (mounted) {
        setState(() {
          _items = r;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    }
  }

  Future<void> _new() async {
    final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const NewComplaintScreen()));
    if (sent == true) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('وصلت شكواك للإدارة، هنرد عليك قريب')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurfaceVariant;
    final items = _items;

    Widget body;
    if (items == null && _error == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (items == null || items.isEmpty) {
      body = ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(32), children: [
        const SizedBox(height: 40),
        Icon(Icons.support_agent_outlined, size: 56, color: muted),
        const SizedBox(height: 12),
        Center(
          child: Text(_error ?? 'مفيش شكاوى',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _error != null ? cs.error : null)),
        ),
        if (_error == null) ...[
          const SizedBox(height: 8),
          Text('لو واجهتك مشكلة أو عندك ملاحظة، ابعتها للإدارة من زرار "شكوى جديدة".', textAlign: TextAlign.center, style: TextStyle(color: muted)),
        ],
      ]);
    } else {
      body = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: items.length,
        itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _ComplaintCard(c: items[i])),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('الشكاوى')),
      body: SafeArea(child: RefreshIndicator(onRefresh: _load, child: body)),
      floatingActionButton: FloatingActionButton.extended(onPressed: _new, icon: const Icon(Icons.add), label: const Text('شكوى جديدة')),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.c});
  final MyComplaint c;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = isDark(context);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(c.subject, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          const SizedBox(width: 8),
          StatusChip(label: complaintStatusAr(c.status), status: complaintChipKey(c.status)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [ArTag(complaintCategoryAr(c.category)), ArTag(fmtDate(c.createdAt.toLocal()))]),
        const SizedBox(height: 10),
        Text(c.message),
        if (c.adminReply != null && c.adminReply!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: dark ? const Color(0xFF12322C) : const Color(0xFFE3F6F1), borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('رد الإدارة', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.primary)),
              const SizedBox(height: 4),
              Text(c.adminReply!),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// نموذج شكوى جديدة. الأنواع بتختلف حسب نوع الحساب (مستخدم / صيدلية).
class NewComplaintScreen extends StatefulWidget {
  const NewComplaintScreen({super.key});
  @override
  State<NewComplaintScreen> createState() => _NewComplaintScreenState();
}

class _NewComplaintScreenState extends State<NewComplaintScreen> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _category = 'Request';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final subject = _subject.text.trim();
    final message = _message.text.trim();
    if (subject.length < 3) {
      setState(() => _error = 'اكتب عنوان للشكوى (3 حروف على الأقل)');
      return;
    }
    if (message.length < 10) {
      setState(() => _error = 'اشرح المشكلة بتفصيل أكتر (10 حروف على الأقل)');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Api>().createComplaint(_category, subject, message);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pharmacy = context.read<AuthState>().isPharmacy;
    final cats = pharmacy ? ['Request', 'User', 'App', 'Other'] : ['Request', 'Pharmacy', 'App', 'Other'];

    return Scaffold(
      appBar: AppBar(title: const Text('شكوى جديدة')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('نوع الشكوى', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in cats)
              ChoiceChip(label: Text(complaintCategoryAr(c)), selected: _category == c, onSelected: _busy ? null : (_) => setState(() => _category = c)),
          ]),
          const SizedBox(height: 18),
          TextField(
            controller: _subject,
            maxLength: 150,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder(), counterText: ''),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _message,
            maxLength: 2000,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(labelText: 'اشرح المشكلة', alignLabelWithHint: true, border: OutlineInputBorder()),
          ),
          if (_error != null)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: cs.error, fontWeight: FontWeight.w600))),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: _busy ? null : _send,
            child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Text('إرسال للإدارة'),
          ),
        ]),
      ),
    );
  }
}
