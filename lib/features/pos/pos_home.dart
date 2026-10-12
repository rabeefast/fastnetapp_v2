import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';

class PosHome extends StatelessWidget {
  const PosHome({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AuthService>().profile;
    return Scaffold(
      appBar: AppBar(
        title: Text('فاست نت — ${p?.name ?? 'نقطة بيع'}'),
        actions: [
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => context.read<AuthService>().signOut()),
        ],
      ),
      body: const Center(
        child: Text('مخزونك ومديونيتك\n— تُفعّل في المرحلة الثانية'),
      ),
    );
  }
}
