import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/config.dart';
import '../widgets/logo.dart';

class _UserLoginForm extends StatefulWidget {
  const _UserLoginForm({super.key});
  @override
  State<_UserLoginForm> createState() => _UserLoginFormState();
}

class _UserLoginFormState extends State<_UserLoginForm> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _age = TextEditingController();
  bool _codeSent = false, _needProfile = false, _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final p = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (p.length < 10) {
      setState(() => _error = 'اكتب رقم موبايل صحيح');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Api>().sendOtp(p);
      if (mounted) setState(() => _codeSent = true);
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final age = int.tryParse(_age.text.trim());
    if (_needProfile && (_name.text.trim().length < 2 || age == null)) {
      setState(() => _error = 'اكتب اسمك وسنك');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Api>().verifyOtp(
            _phone.text.replaceAll(RegExp(r'\D'), ''),
            _code.text.trim(),
            name: _needProfile ? _name.text.trim() : null,
            age: _needProfile ? age : null,
          );
      // نجاح: AuthState بيغيّر الشاشة تلقائيًا
    } catch (e) {
      if (!mounted) return;
      final d = e is DioException ? e.response?.data : null;
      if (d is Map && d['error'] == 'profile_required') {
        setState(() {
          _needProfile = true;
          _error = _name.text.isEmpty ? null : apiError(e);
        });
      } else {
        setState(() => _error = apiError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: _phone,
          enabled: !_codeSent,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
          decoration: const InputDecoration(labelText: 'رقم الموبايل', hintText: '01xxxxxxxxx', border: OutlineInputBorder()),
        ),
        if (_codeSent) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            maxLength: 6,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'كود التحقق (وصلك SMS)', border: OutlineInputBorder(), counterText: ''),
          ),
        ],
        if (_needProfile) ...[
          const SizedBox(height: 14),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder())),
          const SizedBox(height: 14),
          TextField(
            controller: _age,
            keyboardType: TextInputType.number,
            maxLength: 3,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'السن', border: OutlineInputBorder(), counterText: ''),
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(_error!, style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
          ),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: _busy ? null : (_codeSent ? _verify : _send),
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Text(_codeSent ? (_needProfile ? 'إنشاء الحساب' : 'تأكيد') : 'إرسال كود التحقق'),
        ),
        if (_codeSent)
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _codeSent = false;
                      _needProfile = false;
                      _code.clear();
                      _error = null;
                    }),
            child: const Text('تغيير الرقم / إعادة الإرسال'),
          ),

    ]);
  }
}

/// دخول الصيدلية: إيميل + باسورد (زي الويب بالظبط)
class _PharmacyLoginForm extends StatefulWidget {
  const _PharmacyLoginForm({super.key});
  @override
  State<_PharmacyLoginForm> createState() => _PharmacyLoginFormState();
}

class _PharmacyLoginFormState extends State<_PharmacyLoginForm> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false, _hide = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    if (email.isEmpty || _pw.text.isEmpty) {
      setState(() => _error = 'اكتب البريد وكلمة المرور');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Api>().pharmacyLogin(email, _pw.text);
      // نجاح: AuthState بيحوّلنا لواجهة الصيدلية تلقائيًا
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e, fallback: 'البريد أو كلمة المرور غير صحيحة'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register() async {
    final ok = await launchUrl(Uri.parse(webRegisterUrl), mode: LaunchMode.externalApplication);
    if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط')));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        textDirection: TextDirection.ltr,
        autofillHints: const [AutofillHints.username],
        decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder()),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _pw,
        obscureText: _hide,
        textDirection: TextDirection.ltr,
        autofillHints: const [AutofillHints.password],
        onSubmitted: (_) => _busy ? null : _login(),
        decoration: InputDecoration(
          labelText: 'كلمة المرور',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _hide = !_hide)),
        ),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(_error!, style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
        ),
      const SizedBox(height: 20),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: _busy ? null : _login,
        child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Text('دخول'),
      ),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('صيدلية جديدة؟', style: TextStyle(color: cs.onSurfaceVariant)),
        TextButton(onPressed: _register, child: const Text('سجّل صيدليتك من الموقع', style: TextStyle(fontWeight: FontWeight.w800))),
      ]),
    ]);
  }
}

/// أول شاشة: تختار تدخل كمستخدم (بدور على دواء) ولا كصيدلية
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _pharmacy = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Center(child: AppLogo(size: 84, showName: true, stacked: true)),
                const SizedBox(height: 10),
                Text(_pharmacy ? 'استقبل طلبات الأدوية في صيدليتك لحظة بلحظة' : 'دوّر على دواءك في أقرب الصيدليات',
                    textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 24),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, icon: Icon(Icons.person_outline), label: Text('مستخدم')),
                    ButtonSegment(value: true, icon: Icon(Icons.local_pharmacy_outlined), label: Text('صيدلية')),
                  ],
                  selected: {_pharmacy},
                  onSelectionChanged: (v) => setState(() => _pharmacy = v.first),
                ),
                const SizedBox(height: 24),
                // key بيصفّر الفورم لما تبدّل بين النوعين
                _pharmacy ? const _PharmacyLoginForm(key: ValueKey('pharmacy')) : const _UserLoginForm(key: ValueKey('user')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
