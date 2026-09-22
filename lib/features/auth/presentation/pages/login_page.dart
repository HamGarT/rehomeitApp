import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/auth_validators.dart';
import '../auth_controller.dart';
import '../widgets/auth_widgets.dart';
import 'register_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool get _submitting => ref.watch(authControllerProvider).isLoading;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final error = await ref
        .read(authControllerProvider.notifier)
        .signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (!mounted) return;
    if (error != null && error.isNotEmpty) {
      _showError(error);
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _continueWithGoogle() async {
    final error = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();
    if (!mounted) return;
    if (error != null && error.isNotEmpty) {
      _showError(error);
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
  }

  void _goToRegister() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const RegisterPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: authBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AuthHeader(
                        title: '¡Hola de nuevo!',
                        subtitle: 'Inicia sesión para seguir compartiendo y descubriendo cosas útiles.',
                      ),
                      const SizedBox(height: 28),
                      AuthTextField(
                        controller: _emailController,
                        label: 'Correo electrónico',
                        validator: validateEmail,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        prefixIcon: const Icon(Icons.alternate_email, size: 20),
                      ),
                      const SizedBox(height: 14),
                      AuthPasswordField(
                        controller: _passwordController,
                        label: 'Contraseña',
                        validator: validatePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 26),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          disabledBackgroundColor: Colors.white.withValues(
                            alpha: 0.75,
                          ),
                          disabledForegroundColor: AppColors.primary.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : const Text(
                                'Iniciar sesión',
                                style: TextStyle(
                                  fontFamily: 'HostGrotesk',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      const SizedBox(height: 22),
                      const OrDivider(),
                      const SizedBox(height: 22),
                      GoogleSignInButton(
                        onPressed: _submitting ? null : _continueWithGoogle,
                        loading: _submitting,
                      ),
                      const SizedBox(height: 26),
                      TextButton(
                        onPressed: _submitting ? null : _goToRegister,
                        child: const Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '¿No tienes una cuenta? ',
                                style: TextStyle(
                                  fontFamily: 'HostGrotesk',
                                  color: Colors.black,
                                ),
                              ),
                              TextSpan(
                                text: 'Regístrate',
                                style: TextStyle(
                                  fontFamily: 'HostGrotesk',
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
