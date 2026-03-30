



import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../providers/auth_controller_provider.dart';
import '../../providers/auth_state_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Валидация полей
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Введите email';
      });
      return;
    }
    
    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Введите пароль';
      });
      return;
    }
    
    if (password.length < 6) {
      setState(() {
        _errorMessage = 'Пароль должен содержать минимум 6 символов';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authController = ref.read(authControllerProvider);
      if (authController == null) {
        throw Exception('AuthController is null');
      }

      final error = await authController.login(
        email: email,
        password: password,
      );

      setState(() => _isLoading = false);

      if (error == null && mounted) {
        final authState = ref.read(authStateProvider);
        final username = authState?.username ?? '';
        // TODO: switch back to home screen later
        //context.go(RouteNames.home);
        context.go(RouteNames.profile);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Добро пожаловать, $username!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Неверный email или пароль';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Произошла ошибка при входе: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: 412,
        height: 892,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: _isLoading
            ? const LoadingWidget()
            : Stack(
                children: [
                  // Белая карточка
                  Positioned(
                    left: 0,
                    top: 214,
                    child: Container(
                      width: 412,
                      height: 678,
                      decoration: ShapeDecoration(
                        color: AppColors.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(25),
                            topRight: Radius.circular(25),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Сообщение об ошибке (над кнопкой)
                  if (_errorMessage != null)
                    Positioned(
                      left: 106,
                      top: 610,
                      child: Container(
                        width: 201,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Кнопка "Это я!"
                  Positioned(
                    left: 106,
                    top: 766,
                    child: CustomButton(
                      text: 'Это я!',
                      onPressed: _handleLogin,
                      width: 201,
                      fontSize: 20,
                      backgroundColor: AppColors.secondary,
                      textColor: AppColors.textLight,
                    ),
                  ),
                  
                  // Заголовок "Скоро начнём"
                  Positioned(
                    left: 14,
                    top: 234,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        'Скоро начнём',
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 36,
                          height: 0.61,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ),
                  
                  // Подзаголовок
                  Positioned(
                    left: 14,
                    top: 280,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      child: SizedBox(
                        width: 349,
                        child: Text(
                          'Помоги мне удостовериться, что это действительно ты',
                          style: AppTextStyles.headlineMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 24,
                            height: 0.92,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),
                  ),
                  
                  // Поле "Email"
                  Positioned(
                    left: 16,
                    top: 406,
                    child: Container(
                      width: 349,
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: ShapeDecoration(
                        color: AppColors.inputBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: TextField(
                        controller: _emailController,
                        style: const TextStyle(
                          color: AppColors.inputText,
                          fontSize: 20,
                          fontFamily: 'Instrument Sans',
                          fontWeight: FontWeight.w400,
                          height: 1.0,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Email',
                          hintStyle: TextStyle(
                            color: AppColors.inputText,
                            fontSize: 20,
                            fontFamily: 'Instrument Sans',
                            fontWeight: FontWeight.w400,
                            height: 1.0,
                          ),
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  ),
                  
                  // Поле "Пароль"
                  Positioned(
                    left: 16,
                    top: 470,
                    child: Container(
                      width: 349,
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: ShapeDecoration(
                        color: AppColors.inputBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(
                          color: AppColors.inputText,
                          fontSize: 20,
                          fontFamily: 'Instrument Sans',
                          fontWeight: FontWeight.w400,
                          height: 1.0,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Пароль',
                          hintStyle: const TextStyle(
                            color: AppColors.inputText,
                            fontSize: 20,
                            fontFamily: 'Instrument Sans',
                            fontWeight: FontWeight.w400,
                            height: 1.0,
                          ),
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.inputText,
                              size: 24,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Текст "Зарегистрироваться"
                  Positioned(
                    left: 126,
                    top: 820,
                    child: GestureDetector(
                      onTap: () {
                        context.go(RouteNames.register);
                      },
                      child: Column(
                        children: [
                          Text(
                            'Зарегистрироваться',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontFamily: 'Instrument Sans',
                              fontWeight: FontWeight.w400,
                              height: 1.38,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 163,
                            height: 1,
                            color: AppColors.textPrimary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}