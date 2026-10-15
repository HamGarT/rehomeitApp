import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_dialog.dart';

/// Pide el motivo del rechazo de un aporte. Devuelve el texto o `null` si se
/// cancela.
Future<String?> showRejectContributionDialog(BuildContext context) =>
    showDialog<String>(
      context: context,
      builder: (_) => const _RejectContributionDialog(),
    );

class _RejectContributionDialog extends StatefulWidget {
  const _RejectContributionDialog();

  @override
  State<_RejectContributionDialog> createState() =>
      _RejectContributionDialogState();
}

class _RejectContributionDialogState extends State<_RejectContributionDialog> {
  static const _maxLength = 300;

  final TextEditingController _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: '¿Rechazar este aporte?',
    subtitle: 'Indica por qué no llegó o no corresponde a lo declarado.',
    header: const AppDialogIcon(
      icon: Icons.close,
      color: AppColors.error,
    ),
    content: TextField(
      key: const Key('reject-contribution-reason'),
      controller: _reason,
      autofocus: true,
      maxLines: 3,
      maxLength: _maxLength,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: 'Motivo del rechazo',
        errorText: _error,
      ),
    ),
    actions: [
      OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const Key('reject-contribution-submit'),
        style: FilledButton.styleFrom(backgroundColor: AppColors.error),
        onPressed: () {
          final reason = _reason.text.trim();
          if (reason.isEmpty) {
            setState(() => _error = 'Escribe el motivo.');
            return;
          }
          Navigator.of(context).pop(reason);
        },
        child: const Text('Rechazar'),
      ),
    ],
  );
}
