import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/auth_validators.dart';
import '../auth_controller.dart';
import '../widgets/auth_widgets.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  AuthAction? _pending;

  bool get _submitting => ref.watch(authControllerProvider).isLoading;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() => _pending = AuthAction.email);
    final error = await ref
        .read(authControllerProvider.notifier)
        .signUp(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (!mounted) return;
    setState(() => _pending = null);
    if (error != null && error.isNotEmpty) {
      _showError(error);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Tu cuenta está lista. ¡Bienvenido!')),
      );
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
                        title: 'Crea tu cuenta',
                        subtitle: 'Únete a la comunidad y dale una segunda vida a las cosas que ya no usas.',
                      ),
                      const SizedBox(height: 26),
                      AuthTextField(
                        controller: _nameController,
                        label: 'Nombre completo',
                        validator: (value) =>
                            validateRequired(value, 'Nombre completo'),
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        prefixIcon: const Icon(Icons.person_outline, size: 20),
                      ),
                      const SizedBox(height: 14),
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
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                      ),
                      const SizedBox(height: 14),
                      AuthPasswordField(
                        controller: _confirmPasswordController,
                        label: 'Confirmar contraseña',
                        validator: (value) => validatePasswordConfirmation(
                          value,
                          _passwordController.text,
                        ),
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 26),
                      AuthPrimaryButton(
                        label: 'Crear cuenta',
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
                        onPressed: _submitting
                            ? null
                            : Navigator.of(context).pop,
                        child: const Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '¿Ya tienes una cuenta? ',
                                style: TextStyle(
                                  fontFamily: 'HostGrotesk',
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              TextSpan(
                                text: 'Inicia sesión',
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
