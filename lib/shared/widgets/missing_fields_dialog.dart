import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

Future<void> showMissingFieldsDialog(
  BuildContext context, {
  required List<String> fields,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _MissingFieldsDialog(fields: fields),
  );
}

class _MissingFieldsDialog extends StatelessWidget {
  const _MissingFieldsDialog({required this.fields});

  final List<String> fields;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFDF1DE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_note,
                size: 34,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              fields.length == 1 ? 'Falta un dato' : 'Faltan algunos datos',
              style: texts.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Complétalos para continuar con la publicación.',
              textAlign: TextAlign.center,
              style: texts.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
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
                          Expanded(
                            child: Text(field, style: texts.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Completar ahora'),
            ),
          ],
        ),
      ),
    );
  }
}
