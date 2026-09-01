import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../blocs/auth/auth_bloc.dart';
import '../theme/ddt_theme.dart';
import '../utils/ddt_toast.dart';
import '../widgets/ddt_app_input.dart';
import '../widgets/ddt_checkbox.dart';
import '../widgets/login_background.dart';
import '../theme/ddt_typography.dart';

class EwsLoginScreen extends StatefulWidget {
  const EwsLoginScreen({super.key});

  @override
  State<EwsLoginScreen> createState() => _EwsLoginScreenState();
}

class _EwsLoginScreenState extends State<EwsLoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  bool _rememberMe = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    final errors = [
      if (_usernameController.text.trim().isEmpty) 'Введите логин',
      if (_emailController.text.trim().isEmpty) 'Введите email',
      if (_passwordController.text.isEmpty) 'Введите пароль',
    ];

    if (errors.isNotEmpty) {
      DdtToast.show(
        title: 'Проверьте данные',
        message: errors.join('\n'),
        type: ToastType.error,
      );
      return;
    }
    context.read<AuthBloc>().add(
      AuthLoginRequested(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        email: _emailController.text.trim(),
        rememberMe: _rememberMe,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const LoginBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 440.w),
                  child: BlocConsumer<AuthBloc, AuthState>(
                    listenWhen: (previous, current) =>
                        current is AuthFailure && previous != current,
                    listener: (context, state) {
                      if (state is! AuthFailure) return;
                      DdtToast.show(
                        title: 'Ошибка входа',
                        message: state.message,
                        type: ToastType.error,
                        duration: const Duration(seconds: 5),
                      );
                    },
                    builder: (context, state) {
                      final isInitializing = state is AuthInitial;
                      final isLoading = state is AuthLoading;
                      final isBusy = isInitializing || isLoading;

                      return DdtTheme.glass(
                        context: context,
                        padding: EdgeInsets.all(28.w),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Вход',
                              style: DdtTheme.style(
                                fontSize: DdtTypography.displaySize,
                                fontWeight: FontWeight.w700,
                                color: DdtTheme.loginTitleColor(context),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'Корпоративные учётные данные Exchange',
                              style: DdtTheme.style(
                                fontSize: DdtTypography.bodySize,
                                fontWeight: FontWeight.w500,
                                color: DdtTheme.textSecondary(context),
                              ),
                            ),
                            SizedBox(height: 24.h),
                            DdtAppInput(
                              hint: 'Login',
                              prefixIcon: Icons.person_outline_rounded,
                              controller: _usernameController,
                              enabled: !isBusy,
                            ),
                            SizedBox(height: 12.h),
                            DdtAppInput(
                              hint: 'Email',
                              prefixIcon: Icons.mail_outline_rounded,
                              controller: _emailController,
                              enabled: !isBusy,
                              type: InputType.email,
                            ),
                            SizedBox(height: 12.h),
                            DdtAppInput(
                              hint: 'Password',
                              prefixIcon: Icons.lock_outline_rounded,
                              controller: _passwordController,
                              enabled: !isBusy,
                              type: InputType.password,
                            ),
                            SizedBox(height: 12.h),
                            Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: DdtCheckbox(
                                value: _rememberMe,
                                enabled: !isBusy,
                                label: 'Запомнить меня',
                                onChanged: (value) =>
                                    setState(() => _rememberMe = value),
                              ),
                            ),

                            SizedBox(height: 12.h),
                            Button(
                              text: isBusy ? 'Подключение...' : 'Войти',
                              onPressed: isBusy ? null : _submit,
                              borderRadius: BorderRadius.circular(64),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
