import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'app_dialog.dart';

Future<void> showMissingFieldsDialog(
  BuildContext context, {
  required List<String> fields,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AppDialog(
      header: const AppDialogIcon(
        icon: Icons.edit_note,
        color: AppColors.warning,
      ),
      title: fields.length == 1 ? 'Falta un dato' : 'Faltan algunos datos',
      subtitle: 'Complétalos para continuar con la publicación.',
      content: _MissingFieldsList(fields: fields),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Completar ahora'),
        ),
      ],
    ),
  );
}

class _MissingFieldsList extends StatelessWidget {
  const _MissingFieldsList({required this.fields});

  final List<String> fields;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final field in fields)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.radio_button_unchecked,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(field, style: texts.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
