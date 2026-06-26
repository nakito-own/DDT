import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../controllers/ews_auth_controller.dart';
import '../theme/ddt_theme.dart';
import '../widgets/login_background.dart';

class EwsLoginScreen extends StatefulWidget {
  const EwsLoginScreen({super.key});

  @override
  State<EwsLoginScreen> createState() => _EwsLoginScreenState();
}

class _EwsLoginScreenState extends State<EwsLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  bool _rememberMe = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final auth = Get.find<EwsAuthController>();
    await auth.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      email: _emailController.text.trim(),
      rememberMe: _rememberMe,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<EwsAuthController>();

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
                  child: Obx(() {
                    final isInitializing =
                        auth.status.value == EwsAuthStatus.unknown;

                    return DdtTheme.glass(
                      context: context,
                      padding: EdgeInsets.all(28.w),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Вход',
                              style: DdtTheme.style(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.w700,
                                color: DdtTheme.loginTitleColor(context),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'Корпоративные учётные данные Exchange',
                              style: DdtTheme.style(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color: DdtTheme.textSecondary(context),
                              ),
                            ),
                            SizedBox(height: 24.h),
                            TextFormField(
                              controller: _usernameController,
                              enabled: !isInitializing && !auth.isLoading.value,
                              decoration: DdtTheme.inputDecoration(
                                labelText: 'Логин',
                              ),
                              validator: (value) => value == null ||
                                      value.trim().isEmpty
                                  ? 'Введите логин'
                                  : null,
                            ),
                            SizedBox(height: 12.h),
                            TextFormField(
                              controller: _emailController,
                              enabled: !isInitializing && !auth.isLoading.value,
                              decoration: DdtTheme.inputDecoration(
                                labelText: 'Email',
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) => value == null ||
                                      value.trim().isEmpty
                                  ? 'Введите email'
                                  : null,
                            ),
                            SizedBox(height: 12.h),
                            TextFormField(
                              controller: _passwordController,
                              enabled: !isInitializing && !auth.isLoading.value,
                              decoration: DdtTheme.inputDecoration(
                                labelText: 'Пароль',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: isInitializing ||
                                          auth.isLoading.value
                                      ? null
                                      : () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                ),
                              ),
                              obscureText: _obscurePassword,
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Введите пароль'
                                  : null,
                            ),
                            SizedBox(height: 4.h),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _rememberMe,
                              onChanged: isInitializing || auth.isLoading.value
                                  ? null
                                  : (value) => setState(
                                      () => _rememberMe = value ?? true,
                                    ),
                              title: Text(
                                'Запомнить меня',
                                style: DdtTheme.style(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                  color: DdtTheme.textPrimary(context),
                                ),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            Obx(() {
                              final error = auth.errorMessage.value;
                              if (error == null || error.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: EdgeInsets.only(bottom: 12.h),
                                child: Text(
                                  error,
                                  style: DdtTheme.style(
                                    fontSize: 13.sp,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              );
                            }),
                            Obx(() {
                              final loading =
                                  isInitializing || auth.isLoading.value;
                              return Button(
                                text: loading ? 'Подключение...' : 'Войти',
                                onPressed: loading ? null : _submit,
                                borderRadius: DdtTheme.radius,
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
