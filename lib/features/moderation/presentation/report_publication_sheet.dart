import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/domain/publication.dart';
import '../../../shared/widgets/choice_sheet.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/publication_report.dart';
import 'report_controller.dart';

/// Hoja de reporte de una publicación (HU19). Devuelve `true` si el reporte
/// quedó registrado: la confirmación la muestra quien la abre, para que el
/// aviso salga en la pantalla de la que se salió y no sobre la hoja.
Future<bool> showReportPublicationSheet(
  BuildContext context, {
  required Publication publication,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => _ReportPublicationSheet(publication: publication),
  );
  return sent ?? false;
}

/// Abre la hoja de reporte y confirma el registro con un `SnackBar` (HU19,
/// criterio 5).
///
/// El aviso sale desde la pantalla de la que se salió la hoja: lanzado desde
/// dentro quedaría tapado por la propia hoja. Vive aquí y no en las pantallas
/// que llaman a [showReportPublicationSheet] porque las dos necesitan lo mismo,
/// y D10 manda promover a un lugar común lo que se repite.
Future<void> reportPublication(
  BuildContext context, {
  required Publication publication,
}) async {
  final reported = await showReportPublicationSheet(
    context,
    publication: publication,
  );
  if (!reported || !context.mounted) return;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(content: Text('Reporte enviado. Lo revisaremos.')),
    );
}

class _ReportPublicationSheet extends ConsumerStatefulWidget {
  const _ReportPublicationSheet({required this.publication});

  final Publication publication;

  @override
  ConsumerState<_ReportPublicationSheet> createState() =>
      _ReportPublicationSheetState();
}

class _ReportPublicationSheetState
    extends ConsumerState<_ReportPublicationSheet> {
  /// Sin motivo no se envía: la lista es corta y obligatoria (criterio 2).
  static const _reasons = ReportReason.values;

  final TextEditingController _commentController = TextEditingController();

  ReportReason? _reason;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sending = ref.watch(reportControllerProvider).isLoading;
    // La sesión se observa y no se lee al enviar: con `ref.read` una hoja
    // abierta sin nadie mirando la sesión recibiría `null` y rechazaría el
    // reporte sin que el usuario hubiera hecho nada.
    final reporterId = ref.watch(
      authStateProvider.select((auth) => auth.value?.uid),
    );

    return Padding(
      // Con el teclado abierto la hoja sin este relleno deja el botón de
      // enviar debajo del teclado, y el comentario es justo el campo que lo
      // abre.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.appColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reportar publicación',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      // El título va en la hoja para que se sepa qué se está
                      // reportando sin tener que volver al feed.
                      'El equipo revisa «${widget.publication.title}». La publicación sigue visible mientras tanto.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Column(
                  children: [
                    for (final reason in _reasons)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SelectableRow(
                          key: Key('report-reason-${reason.name}'),
                          label: reason.label,
                          selected: reason == _reason,
                          onTap: sending
                              ? null
                              : () => setState(() {
                                  _reason = reason;
                                  _error = null;
                                }),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comentario (opcional)',
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: context.appColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _commentController,
                      enabled: !sending,
                      maxLines: 3,
                      maxLength: PublicationReport.maxCommentLength,
                      // El límite lo pone el repositorio y la regla, pero
                      // también el campo: así se ve que el comentario tiene
                      // tope en lugar de fallar al enviar.
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(
                          PublicationReport.maxCommentLength,
                        ),
                      ],
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Cuéntanos qué viste',
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.error),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: FilledButton(
                  key: const Key('report-submit'),
                  // Sin motivo no hay nada que enviar: el botón sale apagado en
                  // vez de avisar con un error después del toque.
                  onPressed: _reason == null || sending
                      ? null
                      : () => _submit(reporterId),
                  child: sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enviar reporte'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(String? reporterId) async {
    final reason = _reason;
    if (reason == null) return;

    if (reporterId == null) {
      setState(
        () =>
            _error = 'Tu sesión no permite reportar. Vuelve a iniciar sesión.',
      );
      return;
    }

    final error = await ref
        .read(reportControllerProvider.notifier)
        .report(
          publication: widget.publication,
          reporterId: reporterId,
          reason: reason,
          comment: _commentController.text,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(true);
  }
}
