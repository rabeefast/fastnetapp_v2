import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});
  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  bool _stuck = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(
      const Duration(seconds: 15),
      () => setState(() => _stuck = true),
    );
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _stuck
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'تعذر تحميل الحساب. تحقق من الإنترنت وإعدادات Firestore.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.read<AuthService>().signOut(),
                    child: const Text('تسجيل الخروج والمحاولة مجددًا'),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
