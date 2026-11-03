import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/auth/auth_bloc.dart';
import '../screens/ews_login_screen.dart';

class EwsAuthGate extends StatelessWidget {
  const EwsAuthGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) =>
          (previous is AuthAuthenticated) != (current is AuthAuthenticated),
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return child;
        }
        return const EwsLoginScreen();
      },
    );
  }
}
