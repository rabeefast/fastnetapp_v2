import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class RouterApiException implements Exception {
  final String message;
  RouterApiException(this.message);

  @override
  String toString() => message;
}

/// Read-only RouterOS API v6 client over TCP.
///
/// Port 8728 is unencrypted: only use it on a trusted LAN/VPN and restrict
/// access to the manager device in the router firewall.
class RouterApiClient {
  final String host;
  final int port;
  final String username;
  final String password;
  Socket? _socket;
  final List<int> _buffer = [];
  final List<Completer<int>> _waiters = [];

  RouterApiClient({
    required this.host,
    this.port = 8728,
    required this.username,
    required this.password,
  });

  static Future<void> saveCredentials(
    String host,
    String port,
    String user,
    String pass,
  ) async {
    final parsedPort = int.tryParse(port.trim());
    if (host.trim().isEmpty ||
        parsedPort == null ||
        parsedPort < 1 ||
        parsedPort > 65535 ||
        user.trim().isEmpty ||
        pass.isEmpty) {
      throw ArgumentError('تحقق من عنوان الراوتر والمنفذ وبيانات المستخدم');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rt_host', host.trim());
    await prefs.setString('rt_port', parsedPort.toString());
    await prefs.setString('rt_user', user.trim());
    await prefs.setString('rt_pass', pass);
  }

  static Future<RouterApiClient?> fromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('rt_host') ?? '';
    if (host.isEmpty) return null;
    return RouterApiClient(
      host: host,
      port: int.tryParse(prefs.getString('rt_port') ?? '8728') ?? 8728,
      username: prefs.getString('rt_user') ?? '',
      password: prefs.getString('rt_pass') ?? '',
    );
  }

  Future<void> connect() async {
    if (host.trim().isEmpty || port < 1 || port > 65535) {
      throw RouterApiException('عنوان الراوتر أو المنفذ غير صالح');
    }
    try {
      final socket = await Socket.connect(
        host.trim(),
        port,
        timeout: const Duration(seconds: 8),
      );
      _socket = socket;
      socket.listen(
        (data) {
          _buffer.addAll(data);
          while (_waiters.isNotEmpty && _buffer.isNotEmpty) {
            final waiter = _waiters.removeAt(0);
            if (!waiter.isCompleted) waiter.complete(_buffer.removeAt(0));
          }
        },
        onError: (Object error, StackTrace stack) {
          _failWaiters(RouterApiException('انقطع الاتصال بالراوتر'));
        },
        onDone: () => _failWaiters(null),
        cancelOnError: true,
      );
    } on RouterApiException {
      rethrow;
    } catch (_) {
      throw RouterApiException(
        'تعذر الاتصال بالراوتر. تحقق من الشبكة والعنوان $host والمنفذ $port',
      );
    }
  }

  void _failWaiters(Object? error) {
    for (final waiter in _waiters) {
      if (waiter.isCompleted) continue;
      if (error == null) {
        waiter.complete(-1);
      } else {
        waiter.completeError(error);
      }
    }
    _waiters.clear();
  }

  Future<void> close() async {
    final socket = _socket;
    _socket = null;
    _failWaiters(null);
    _buffer.clear();
    await socket?.close();
  }

  Future<int> _byte() async {
    if (_buffer.isNotEmpty) return _buffer.removeAt(0);
    if (_socket == null) throw RouterApiException('لا يوجد اتصال بالراوتر');
    final waiter = Completer<int>();
    _waiters.add(waiter);
    try {
      return await waiter.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          // Remove the abandoned waiter, otherwise it would consume a future
          // response byte and desynchronize the protocol stream.
          _waiters.remove(waiter);
          throw RouterApiException('انتهت مهلة انتظار الرد من الراوتر');
        },
      );
    } on RouterApiException {
      rethrow;
    } catch (_) {
      throw RouterApiException('انقطع الاتصال بالراوتر أثناء قراءة الرد');
    }
  }

  static List<int> _encodeLength(int length) {
    if (length < 0x80) return [length];
    if (length < 0x4000) {
      return [0x80 | (length >> 8), length & 0xff];
    }
    if (length < 0x200000) {
      return [0xC0 | (length >> 16), (length >> 8) & 0xff, length & 0xff];
    }
    if (length < 0x10000000) {
      return [
        0xE0 | (length >> 24),
        (length >> 16) & 0xff,
        (length >> 8) & 0xff,
        length & 0xff,
      ];
    }
    return [
      0xF0,
      (length >> 24) & 0xff,
      (length >> 16) & 0xff,
      (length >> 8) & 0xff,
      length & 0xff,
    ];
  }

  void _send(List<String> words) {
    final socket = _socket;
    if (socket == null) throw RouterApiException('لا يوجد اتصال بالراوتر');
    for (final word in words) {
      final bytes = utf8.encode(word);
      socket.add(_encodeLength(bytes.length));
      socket.add(bytes);
    }
    socket.add([0]);
  }

  Future<int> _readLength() async {
    final first = await _byte();
    if (first < 0) return -1;
    if (first < 0x80) return first;

    var length = 0;
    if (first < 0xC0) {
      length = first & 0x3F;
      final next = await _byte();
      return next < 0 ? -1 : (length << 8) | next;
    }
    if (first < 0xE0) {
      length = first & 0x1F;
      for (var i = 0; i < 2; i++) {
        final next = await _byte();
        if (next < 0) return -1;
        length = (length << 8) | next;
      }
      return length;
    }
    if (first < 0xF0) {
      length = first & 0x0F;
      for (var i = 0; i < 3; i++) {
        final next = await _byte();
        if (next < 0) return -1;
        length = (length << 8) | next;
      }
      return length;
    }
    for (var i = 0; i < 4; i++) {
      final next = await _byte();
      if (next < 0) return -1;
      length = (length << 8) | next;
    }
    return length;
  }

  Future<String?> _readWord() async {
    final length = await _readLength();
    if (length < 0) return null;
    if (length == 0) return '';
    if (length > 4 * 1024 * 1024) {
      throw RouterApiException('رد الراوتر أكبر من الحد المسموح');
    }
    final bytes = <int>[];
    for (var i = 0; i < length; i++) {
      final byte = await _byte();
      if (byte < 0) return null;
      bytes.add(byte);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<List<List<String>>> _talk(List<String> words) async {
    _send(words);
    final sentences = <List<String>>[];
    var current = <String>[];
    while (true) {
      final word = await _readWord();
      if (word == null) {
        if (current.isNotEmpty) sentences.add(current);
        break;
      }
      if (word.isEmpty) {
        if (current.isNotEmpty) sentences.add(current);
        final terminal = sentences.any(
          (sentence) =>
              sentence.isNotEmpty &&
              (sentence.first == '!done' ||
                  sentence.first == '!fatal' ||
                  sentence.first == '!trap'),
        );
        current = [];
        if (terminal) break;
      } else {
        current.add(word);
      }
    }
    return sentences;
  }

  String? _routerMessage(List<List<String>> sentences) {
    for (final sentence in sentences) {
      for (final word in sentence) {
        if (word.startsWith('=message=')) return word.substring(9);
      }
    }
    return null;
  }

  bool _hasRouterError(List<List<String>> sentences) => sentences.any(
        (sentence) =>
            sentence.isNotEmpty &&
            (sentence.first == '!fatal' || sentence.first == '!trap'),
      );

  bool _hasDone(List<List<String>> sentences) => sentences.any(
        (sentence) => sentence.isNotEmpty && sentence.first == '!done',
      );

  /// RouterOS 6.43+ supports explicit username/password API login.
  Future<void> login() async {
    final response = await _talk([
      '/login',
      '=name=$username',
      '=password=$password',
    ]);
    if (_hasRouterError(response)) {
      throw RouterApiException(
        _routerMessage(response) ??
            'رفض الراوتر الدخول؛ تحقق من بيانات حساب read-only',
      );
    }
    if (!_hasDone(response)) {
      throw RouterApiException('لم يؤكد الراوتر نجاح تسجيل الدخول');
    }
  }

  Future<String> testConnection() async {
    final response = await _talk(['/system/resource/print']);
    if (_hasRouterError(response)) {
      throw RouterApiException(
        _routerMessage(response) ?? 'رفض الراوتر أمر فحص الاتصال',
      );
    }
    if (!_hasDone(response)) {
      throw RouterApiException('لم يكتمل أمر فحص الاتصال بالراوتر');
    }
    for (final sentence in response) {
      if (sentence.isEmpty || sentence.first != '!re') continue;
      for (final word in sentence) {
        if (word.startsWith('=version=')) return word.substring(9);
      }
    }
    throw RouterApiException('الراوتر متصل لكن لم يرجع رقم الإصدار');
  }

  Future<Map<String, Map<String, String>>> fetchUmUsers() async {
    final response = await _talk(['/tool/user-manager/user/print']);
    if (_hasRouterError(response)) {
      throw RouterApiException(
        _routerMessage(response) ??
            'رفض الراوتر الأمر؛ الحساب يحتاج صلاحيتي read و api',
      );
    }
    if (!_hasDone(response)) {
      throw RouterApiException('لم يكتمل طلب قراءة مستخدمي User Manager');
    }
    final users = <String, Map<String, String>>{};
    for (final sentence in response) {
      if (sentence.isEmpty || sentence.first != '!re') continue;
      final attributes = <String, String>{};
      for (final word in sentence.skip(1)) {
        if (!word.startsWith('=')) continue;
        final separator = word.indexOf('=', 1);
        if (separator > 1) {
          attributes[word.substring(1, separator)] = word.substring(
            separator + 1,
          );
        }
      }
      final username = attributes['username'];
      if (username != null && username.isNotEmpty) {
        users[username] = attributes;
      }
    }
    return users;
  }
}
