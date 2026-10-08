import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/domain/publication.dart';
import '../../../shared/widgets/button_spinner.dart';
import '../../../shared/widgets/publication_image.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../publishing/presentation/photos_step.dart';
import '../../publishing/presentation/publish_draft_notifier.dart';
import 'exchange_controller.dart';

Future<bool?> showProposeExchangeSheet(
  BuildContext context, {
  required Publication requestedPublication,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _ProposeExchangeSheet(requestedPublication: requestedPublication),
  );
}

class _ProposeExchangeSheet extends ConsumerStatefulWidget {
  const _ProposeExchangeSheet({required this.requestedPublication});

  final Publication requestedPublication;

  @override
  ConsumerState<_ProposeExchangeSheet> createState() =>
      _ProposeExchangeSheetState();
}

class _ProposeExchangeSheetState extends ConsumerState<_ProposeExchangeSheet> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      return const _SheetMessage(
        icon: Icons.lock_outline,
        message: 'Inicia sesión para proponer un intercambio.',
      );
    }

    final publications = ref.watch(
      eligibleExchangePublicationsProvider(user.uid),
    );
    final isSubmitting = ref.watch(exchangeControllerProvider).isLoading;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Qué bien quieres ofrecer?',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Solo aparecen tus publicaciones de intercambio disponibles.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.appColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: publications.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => const _SheetMessage(
                icon: Icons.error_outline,
                message: 'No pudimos cargar tus publicaciones.',
              ),
              data: (items) => items.isEmpty
                  ? _SheetMessage(
                      icon: Icons.inventory_2_outlined,
                      message: 'No tienes una publicación de intercambio disponible. Publica un bien para poder proponer un canje.',
                      actionLabel: 'Publicar un bien',
                      onAction: () {
                        ref.read(publishDraftProvider.notifier).reset();
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PhotosStep()),
                        );
                      },
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final publication = items[index];
                        return _OfferedPublicationTile(
                          publication: publication,
                          selected: publication.id == _selectedId,
                          onTap: () =>
                              setState(() => _selectedId = publication.id),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _selectedId == null || isSubmitting
                ? null
                : () => _submit(user.uid),
            child: isSubmitting
                ? const ButtonSpinner()
                : const Text('Enviar propuesta'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(String userId) async {
    final error = await ref
        .read(exchangeControllerProvider.notifier)
        .propose(
          requestedPublicationId: widget.requestedPublication.id,
          offeredPublicationId: _selectedId!,
          proposerId: userId,
        );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error)));
  }
}

class _OfferedPublicationTile extends StatelessWidget {
  const _OfferedPublicationTile({
    required this.publication,
    required this.selected,
    required this.onTap,
  });

  final Publication publication;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? context.appColors.primary
                  : context.appColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox.square(
                  dimension: 58,
                  child: PublicationImage(
                    url: publication.images.isEmpty
                        ? null
                        : publication.images.first,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      publication.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      publication.district,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: context.appColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected
                    ? context.appColors.primary
                    : context.appColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: context.appColors.textSecondary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel ?? 'Continuar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
