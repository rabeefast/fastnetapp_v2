import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!DefaultFirebaseOptions.isConfigured) {
    runApp(const _ConfigNeededApp());
    return;
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const FastNetApp());
}

/// يظهر إذا لم تُملأ قيم Firebase بعد — بدلًا من تعطل التطبيق بخطأ غامض
class _ConfigNeededApp extends StatelessWidget {
  const _ConfigNeededApp();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'لم يتم إعداد Firebase بعد.\n\n'
              'افتح ملف lib/firebase_options.dart والصق القيم الخمسة من:\n'
              'Firebase Console -> Project settings -> Your apps -> SDK setup',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
          ),
        ),
      ),
    );
  }
}

class FastNetApp extends StatefulWidget {
  const FastNetApp({super.key});
  @override
  State<FastNetApp> createState() => _FastNetAppState();
}

class _FastNetAppState extends State<FastNetApp> {
  final AuthService _auth = AuthService();
  final AppState _appState = AppState();
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    _auth.restore();
  }

  @override
  Widget build(BuildContext context) {
    _router ??= createRouter(_auth);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _appState),
      ],
      child: MaterialApp.router(
        title: 'Fast Net',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router!,
      ),
    );
  }
}
