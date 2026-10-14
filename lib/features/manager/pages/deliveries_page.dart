import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/auth_service.dart';
import '../../delivery/delivery_wizard.dart';

class DeliveriesPage extends StatelessWidget {
  const DeliveriesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().user!.uid;
    return DeliveryWizard(side: 'mg', fromUid: uid, managerUid: uid);
  }
}
