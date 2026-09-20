import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/missing_fields_dialog.dart';
import '../../../shared/widgets/step_app_bar.dart';
import '../domain/publish_draft.dart';
import 'publish_draft_notifier.dart';

class ModeStep extends ConsumerWidget {
  const ModeStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(publishDraftProvider);
    final notifier = ref.read(publishDraftProvider.notifier);

    return Scaffold(
      appBar: const StepAppBar(title: 'Modalidad', step: 3),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _DraftSummary(draft: draft),
            const Divider(height: 32),
            Text(
              '¿Qué quieres hacer con el bien?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SelectableCard(
              title: 'Donación',
              subtitle: 'Entregas el bien sin recibir nada a cambio',
              selected: draft.mode == PublishMode.donation,
              onTap: () => notifier.selectMode(PublishMode.donation),
            ),
            const SizedBox(height: 12),
            SelectableCard(
              title: 'Intercambio',
              subtitle: 'Propones intercambiarlo por otro bien publicado',
              selected: draft.mode == PublishMode.exchange,
              onTap: () => notifier.selectMode(PublishMode.exchange),
            ),
            if (draft.mode == PublishMode.donation) ...[
              const Divider(height: 32),
              Text(
                '¿Cómo se hará la entrega?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SelectableCard(
                title: 'La entrego yo',
                subtitle: 'A una persona que ya conozco',
                selected: draft.deliveryMethod == DeliveryMethod.owner,
                onTap: () => notifier.selectDeliveryMethod(DeliveryMethod.owner),
              ),
              const SizedBox(height: 12),
              SelectableCard(
                title: 'La recoge un voluntario',
                subtitle: 'Un voluntario la lleva a quien la necesite',
                selected: draft.deliveryMethod == DeliveryMethod.volunteer,
                onTap: () =>
                    notifier.selectDeliveryMethod(DeliveryMethod.volunteer),
              ),
              const SizedBox(height: 16),
              InfoNote(text: _deliveryNote(draft.deliveryMethod)),
            ],
            if (draft.mode == PublishMode.exchange) ...[
              const SizedBox(height: 16),
              const InfoNote(
                text:
                    'Los términos del intercambio se coordinan con la otra persona por la mensajería de la app.',
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _publish(context, ref, draft),
              child: const Text('Publicar'),
            ),
          ],
        ),
      ),
    );
  }

  String _deliveryNote(DeliveryMethod? method) {
    return switch (method) {
      null =>
        'Toda entrega queda registrada con una fotografía y las iniciales de quien recibe el bien.',
      DeliveryMethod.owner =>
        'Tú registrarás la entrega con una fotografía y las iniciales de quien reciba el bien. Con eso el ciclo queda cerrado.',
      DeliveryMethod.volunteer =>
        'El voluntario registrará la entrega con una fotografía y las iniciales de quien reciba el bien. Después tú confirmas el cierre desde tu perfil.',
    };
  }

  void _publish(BuildContext context, WidgetRef ref, PublishDraft draft) {
    if (!draft.modeCompleted) {
      showMissingFieldsDialog(context, fields: draft.missingModeFields);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    ref.read(publishDraftProvider.notifier).reset();
    Navigator.of(context).popUntil((route) => route.isFirst);
    messenger.showSnackBar(
      const SnackBar(content: Text('Publicación registrada')),
    );
  }
}

class _DraftSummary extends StatelessWidget {
  const _DraftSummary({required this.draft});

  final PublishDraft draft;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: draft.photos.isEmpty
              ? Container(width: 64, height: 64, color: colors.outline)
              : Image.file(
                  draft.photos.first,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                draft.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${draft.category} · ${draft.district}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
