import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/ews_auth_controller.dart';
import '../screens/ews_login_screen.dart';

class EwsAuthGate extends StatelessWidget {
  const EwsAuthGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<EwsAuthController>();

    return Obx(() {
      if (auth.isAuthenticated) {
        return child;
      }

      return const EwsLoginScreen();
    });
  }
}
