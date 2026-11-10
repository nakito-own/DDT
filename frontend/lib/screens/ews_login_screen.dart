import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/ddt_icons.dart';

import '../blocs/auth/auth_bloc.dart';
import '../services/api_client.dart';
import '../theme/ddt_theme.dart';
import '../utils/ddt_toast.dart';
import '../utils/ews_login.dart';
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _rememberMe = true;
  String? _validationMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    final username = usernameFromEmail(email);
    final errors = [
      if (email.isEmpty) 'Введите почту',
      if (email.isNotEmpty && username == null) 'Почта должна содержать логин до @',
      if (_passwordController.text.isEmpty) 'Введите пароль',
    ];

    if (errors.isNotEmpty) {
      setState(() => _validationMessage = errors.join('\n'));
      DdtToast.show(
        title: 'Проверьте данные',
        message: errors.join('\n'),
        type: ToastType.error,
      );
      return;
    }
    setState(() => _validationMessage = null);
    FocusManager.instance.primaryFocus?.unfocus();
    context.read<AuthBloc>().add(
      AuthLoginRequested(
        email: email,
        password: _passwordController.text,
        rememberMe: _rememberMe,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const LoginBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
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
                      final isBusy = state is AuthLoading;

                      return DdtTheme.glass(
                        context: context,
                        padding: EdgeInsets.all(28.w),
                        child: AutofillGroup(
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
                              if (kDebugMode && apiUrl.isEmpty) ...[
                                Text(
                                  'Не задан API_URL. Запускайте с '
                                  '--dart-define=API_URL=http://localhost:3000',
                                  style: DdtTheme.style(
                                    fontSize: DdtTypography.labelSize,
                                    color: AppColors.error,
                                  ),
                                ),
                                SizedBox(height: 12.h),
                              ],
                              if (_validationMessage != null) ...[
                                Text(
                                  _validationMessage!,
                                  style: DdtTheme.style(
                                    fontSize: DdtTypography.labelSize,
                                    color: AppColors.error,
                                  ),
                                ),
                                SizedBox(height: 12.h),
                              ],
                              DdtAppInput(
                                hint: 'Почта',
                                prefixIcon: DdtIcons.mail,
                                controller: _emailController,
                                focusNode: _emailFocus,
                                enabled: !isBusy,
                                type: InputType.email,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.email,
                                  AutofillHints.username,
                                ],
                                onSubmitted: (_) =>
                                    _passwordFocus.requestFocus(),
                              ),
                              SizedBox(height: 12.h),
                              DdtAppInput(
                                hint: 'Пароль',
                                prefixIcon: DdtIcons.lock,
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                enabled: !isBusy,
                                type: InputType.password,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onSubmitted: (_) {
                                  if (!isBusy) _submit();
                                },
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
                              SizedBox(height: 16.h),
                              Button(
                                text: isBusy ? 'Подключение...' : 'Войти',
                                isLoading: isBusy,
                                onPressed: isBusy ? null : _submit,
                                borderRadius: DdtTheme.inputControlBorderRadius,
                              ),
                            ],
                          ),
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
