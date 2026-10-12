import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// إرسال إشعارات تليجرام من جهاز المدير فقط.
/// التوكن يُخزن محليا على أجهزة المدير ولا يذهب لأي سيرفر.
class TelegramService {
  static const String _kToken = 'tg_bot_token';
  static const String _kChat = 'tg_chat_id';

  static Future<void> saveCredentials(String token, String chatId) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, token);
    await p.setString(_kChat, chatId);
  }

  static Future<String?> get token async =>
      (await SharedPreferences.getInstance()).getString(_kToken);

  static Future<String?> get chatId async =>
      (await SharedPreferences.getInstance()).getString(_kChat);

  static Future<bool> send(String text) async {
    final t = await token;
    final c = await chatId;
    if (t == null || t.isEmpty || c == null || c.isEmpty) return false;
    try {
      final res = await http.post(
        Uri.parse('https://api.telegram.org/bot$t/sendMessage'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'chat_id': c, 'text': text, 'parse_mode': 'HTML'}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> sendTest() => send('✅ <b>Fast Net</b>\nتم ربط التليجرام بنجاح.');
}
