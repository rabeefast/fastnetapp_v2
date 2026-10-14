import 'package:flutter/material.dart';

import '../../../services/router_api_service.dart';
import '../../../services/router_sync_service.dart';

/// Manager-only screen for a read-only connection to the local router.
class RouterSettingsPage extends StatefulWidget {
  final String managerUid;
  const RouterSettingsPage({super.key, required this.managerUid});

  @override
  State<RouterSettingsPage> createState() => _RouterSettingsPageState();
}

class _RouterSettingsPageState extends State<RouterSettingsPage> {
  final _host = TextEditingController();
  final _port = TextEditingController(text: '8728');
  final _user = TextEditingController(text: 'fastnetapi');
  final _pass = TextEditingController();
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = await RouterApiClient.fromPrefs();
      if (client != null && mounted) {
        setState(() {
          _host.text = client.host;
          _port.text = client.port.toString();
          _user.text = client.username;
          _pass.text = client.password;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _status = 'تعذر قراءة الإعدادات المحفوظة');
    }
  }

  RouterApiClient _client() {
    final host = _host.text.trim();
    final port = int.tryParse(_port.text.trim());
    final username = _user.text.trim();
    final password = _pass.text;
    if (host.isEmpty ||
        port == null ||
        port < 1 ||
        port > 65535 ||
        username.isEmpty ||
        password.isEmpty) {
      throw RouterApiException(
        'أدخل عنوان IP والمنفذ الصحيح واسم مستخدم وكلمة مرور الراوتر',
      );
    }
    return RouterApiClient(
      host: host,
      port: port,
      username: username,
      password: password,
    );
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _status = '';
    });
    try {
      await RouterApiClient.saveCredentials(
        _host.text,
        _port.text,
        _user.text,
        _pass.text,
      );
      if (mounted) {
        setState(() => _status = 'تم حفظ الإعدادات محليًا على هذا الجهاز');
      }
    } catch (e) {
      if (mounted) setState(() => _status = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect({required bool sync}) async {
    setState(() {
      _busy = true;
      _status =
          sync ? 'جارٍ مزامنة بيانات User Manager...' : 'جارٍ فحص الاتصال...';
    });
    RouterApiClient? client;
    try {
      client = _client();
      await client.connect();
      await client.login();
      if (sync) {
        final result = await RouterSyncService().sync(
          widget.managerUid,
          client,
        );
        if (mounted) {
          setState(() {
            _status = 'اكتملت المزامنة: ${result.used} مستخدم من '
                '${result.matched} كرت مطابق (إجمالي المخزون: '
                '${result.totalCards})';
          });
        }
      } else {
        final version = await client.testConnection();
        if (mounted) setState(() => _status = 'متصل بنجاح — RouterOS $version');
      }
    } catch (e) {
      if (mounted) setState(() => _status = e.toString());
    } finally {
      await client?.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اتصال الراوتر (قراءة فقط)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.warning_amber),
              title: Text('اتصال محلي غير مشفر'),
              subtitle: Text(
                'منفذ RouterOS API 8728 يرسل البيانات دون تشفير. '
                'استخدم شبكة موثوقة أو VPN، ولا تفتح المنفذ للإنترنت.',
              ),
            ),
          ),
          TextField(
            controller: _host,
            decoration: const InputDecoration(labelText: 'عنوان الراوتر (IP)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _port,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'منفذ API (8728)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _user,
            decoration: const InputDecoration(labelText: 'اسم مستخدم API'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pass,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'كلمة مرور API',
              helperText:
                  'تُحفظ في تفضيلات التطبيق على هذا الجهاز؛ ليست مخزنًا مشفرًا.',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('حفظ الإعدادات'),
            onPressed: _busy ? null : _save,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.wifi_tethering),
            label: const Text('فحص الاتصال'),
            onPressed: _busy ? null : () => _connect(sync: false),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.sync),
            label: const Text('مزامنة حالة الكروت من User Manager'),
            onPressed: _busy ? null : () => _connect(sync: true),
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_status, style: const TextStyle(height: 1.5)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
