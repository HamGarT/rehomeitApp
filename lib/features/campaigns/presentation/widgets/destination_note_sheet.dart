import 'package:flutter/material.dart';

import '../../../../shared/widgets/sheet_handle.dart';
import '../../data/campaign_repository.dart';

/// Hoja para describir el destino de lo recibido (HU17-6). Devuelve el texto
/// o `null` si se cerró sin guardar.
Future<String?> showDestinationNoteSheet(
  BuildContext context, {
  String? initial,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _DestinationNoteSheet(initial: initial),
  );
}

class _DestinationNoteSheet extends StatefulWidget {
  const _DestinationNoteSheet({this.initial});

  final String? initial;

  @override
  State<_DestinationNoteSheet> createState() => _DestinationNoteSheetState();
}

class _DestinationNoteSheetState extends State<_DestinationNoteSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Sube la hoja con el teclado para que el botón no quede tapado.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: SheetHandle()),
              const SizedBox(height: 16),
              Text(
                'Destino de lo recibido',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Cuenta a quienes aportaron en qué terminó lo que entregaron. No incluyas datos que identifiquen a las personas que lo recibieron.',
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('destination-note-field'),
                controller: _controller,
                maxLines: 5,
                maxLength: CampaignRepository.destinationNoteMaxLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText:
                      'Ejemplo: la ropa se entregó a 12 familias del caserío.',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('save-destination-button'),
                onPressed: () =>
                    Navigator.of(context).pop(_controller.text.trim()),
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
