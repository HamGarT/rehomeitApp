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

  AuthAction? _pending;

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

    setState(() => _pending = AuthAction.email);
    final error = await ref
        .read(authControllerProvider.notifier)
        .signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (!mounted) return;
    setState(() => _pending = null);
    if (error != null && error.isNotEmpty) {
      _showError(error);
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _continueWithGoogle() async {
    setState(() => _pending = AuthAction.google);
    final error = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();
    if (!mounted) return;
    setState(() => _pending = null);
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

  // Usa la transición del tema, la misma que el resto de la app.
  void _goToRegister() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RegisterPage()));
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
                      AuthPrimaryButton(
                        label: 'Iniciar sesión',
                        loading: _pending == AuthAction.email,
                        onPressed: _submitting ? null : _submit,
                      ),
                      const SizedBox(height: 22),
                      const OrDivider(),
                      const SizedBox(height: 22),
                      GoogleSignInButton(
                        onPressed: _submitting ? null : _continueWithGoogle,
                        loading: _pending == AuthAction.google,
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
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              TextSpan(
                                text: 'Regístrate',
                                style: TextStyle(
                                  fontFamily: 'HostGrotesk',
                                  color: AppColors.textPrimary,
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
