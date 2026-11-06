import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../data/auth_exception.dart';
import '../auth_controller.dart';
import '../widgets/auth_widgets.dart';

/// Pantalla en la que se queda una cuenta de correo hasta abrir el enlace de
/// verificación. No hay nada que adivinar aquí: Auth es quien sabe si el
/// correo ya se verificó, por eso el botón principal solo vuelve a consultar.
class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  static const _resendCooldown = Duration(seconds: 60);

  bool _checking = false;
  bool _resending = false;
  int _secondsUntilResend = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() => _checking = true);
    try {
      final verified = await ref
          .read(authControllerProvider.notifier)
          .refreshEmailVerification();
      if (!mounted) return;
      // Si ya verificó, la sesión reenruta sola; no hay nada que mostrar.
      if (!verified) {
        showAppSnackBar(
          context,
          'Todavía no vemos la verificación. Abre el enlace del correo y vuelve a intentarlo.',
          kind: AppSnackBarKind.info,
        );
      }
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      showAppSnackBar(context, failure.message, kind: AppSnackBarKind.error);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ref.read(authControllerProvider.notifier).sendVerificationEmail();
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Correo reenviado. Revisa también la carpeta de spam.',
      );
      _startCooldown();
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      showAppSnackBar(context, failure.message, kind: AppSnackBarKind.error);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  // La espera evita que Auth bloquee la cuenta por demasiados envíos.
  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _secondsUntilResend = _resendCooldown.inSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsUntilResend -= 1);
      if (_secondsUntilResend <= 0) timer.cancel();
    });
  }

  Future<void> _useAnotherAccount() async {
    await ref.read(authControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authStateProvider).value?.email ?? 'tu correo';
    final busy = _checking || _resending;
    final canResend = !busy && _secondsUntilResend <= 0;
    final linkStyle = TextStyle(
      fontFamily: 'HostGrotesk',
      color: context.appColors.textPrimary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
    );

    return Scaffold(
      backgroundColor: authBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthHeader(
                    title: 'Verifica tu correo',
                    subtitle:
                        'Te enviamos un enlace a $email. Ábrelo desde este teléfono o desde cualquier otro y luego vuelve aquí.',
                  ),
                  const SizedBox(height: 28),
                  AuthPrimaryButton(
                    label: 'Ya lo verifiqué',
                    loading: _checking,
                    onPressed: busy ? null : _confirm,
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: canResend ? _resend : null,
                    child: Text(
                      _secondsUntilResend > 0
                          ? 'Reenviar en $_secondsUntilResend s'
                          : 'Reenviar correo',
                      style: linkStyle.copyWith(
                        color: canResend
                            ? context.appColors.textPrimary
                            : context.appColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  TextButton(
                    onPressed: busy ? null : _useAnotherAccount,
                    child: Text('Usar otra cuenta', style: linkStyle),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
