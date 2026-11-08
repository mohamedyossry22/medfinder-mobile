import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('MedFinder',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: cs.primary)),
                const SizedBox(height: 6),
                Text('دوّر على دواءك في أقرب الصيدليات',
                    textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 32),
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
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
