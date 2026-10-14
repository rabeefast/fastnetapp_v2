import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';

/// Reusable device-local security option shown in account settings.
class BiometricSettingsCard extends StatefulWidget {
  final String uid;

  const BiometricSettingsCard({super.key, required this.uid});

  @override
  State<BiometricSettingsCard> createState() => _BiometricSettingsCardState();
}

class _BiometricSettingsCardState extends State<BiometricSettingsCard> {
  bool _enabled = false;
  bool _available = false;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        BiometricService.isEnabled(widget.uid),
        BiometricService.canUseBiometrics(),
      ]);
      if (!mounted) return;
      setState(() {
        _enabled = values[0];
        _available = values[1];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _enabled = false;
        _available = false;
        _loading = false;
      });
    }
  }

  Future<void> _change(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (value) {
        final available = await BiometricService.canUseBiometrics();
        if (!available) {
          _showMessage(
            'هذا الجهاز لا يحتوي على بصمة مسجلة أو دعم للمصادقة الحيوية.',
          );
          return;
        }
        final verified = await BiometricService.authenticate(
          'أكد هويتك لتفعيل الدخول بالبصمة',
        );
        if (!verified) return;
      } else if (_available) {
        final verified = await BiometricService.authenticate(
          'أكد هويتك لإيقاف الدخول بالبصمة',
        );
        if (!verified) return;
      }

      await BiometricService.setEnabled(widget.uid, value);
      if (mounted) setState(() => _enabled = value);
      _showMessage(
        value
            ? 'تم تفعيل قفل التطبيق بالبصمة على هذا الجهاز.'
            : 'تم إيقاف قفل التطبيق بالبصمة.',
      );
    } catch (_) {
      _showMessage('تعذر حفظ إعداد البصمة؛ حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _loading
        ? 'جارٍ فحص دعم الجهاز...'
        : !_available && !_enabled
            ? 'يتطلب بصمة أو مصادقة حيوية مسجلة على الهاتف.'
            : 'يطلب البصمة عند استعادة جلسة الحساب. لا تُحفظ كلمة المرور.';
    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.fingerprint),
        title: const Text('الدخول بالبصمة'),
        subtitle: Text(subtitle),
        value: _enabled,
        onChanged:
            _loading || _busy || (!_available && !_enabled) ? null : _change,
      ),
    );
  }
}

class BiometricSettingsPage extends StatelessWidget {
  const BiometricSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().user!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('الأمان والبصمة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BiometricSettingsCard(uid: uid),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'تُخزّن حالة التفعيل على هذا الجهاز فقط. إذا ألغيت البصمة عند فتح التطبيق، '
              'سيعود التطبيق إلى شاشة تسجيل الدخول بالبريد وكلمة المرور.',
              style: TextStyle(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
