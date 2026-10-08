import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/cajamarca_districts.dart';
import '../../../shared/domain/publication.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/button_spinner.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/delivery_draft.dart';
import 'delivery_controller.dart';

class RegisterDeliveryPage extends ConsumerStatefulWidget {
  const RegisterDeliveryPage({super.key, required this.publication});

  final Publication publication;

  @override
  ConsumerState<RegisterDeliveryPage> createState() =>
      _RegisterDeliveryPageState();
}

class _RegisterDeliveryPageState extends ConsumerState<RegisterDeliveryPage> {
  final _initialsController = TextEditingController();
  File? _photo;
  String? _district;

  @override
  void dispose() {
    _initialsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(deliveryControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar entrega')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const _PrivacyNotice(),
            const SizedBox(height: 16),
            Text(
              'Fotografía de evidencia *',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _EvidencePreview(photo: _photo),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Tomar fotografía'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Elegir de la galería'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _initialsController,
              maxLength: 12,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Iniciales del destinatario *',
                hintText: 'Ejemplo: M. R.',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _district,
              decoration: const InputDecoration(
                labelText: 'Distrito *',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              items: [
                for (final district in CajamarcaDistricts.all)
                  DropdownMenuItem(value: district, child: Text(district)),
              ],
              onChanged: busy
                  ? null
                  : (value) => setState(() => _district = value),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: busy ? null : _submit,
              icon: busy
                  ? const ButtonSpinner()
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                widget.publication.deliveryType == DeliveryType.owner
                    ? 'Registrar y cerrar donación'
                    : 'Registrar entrega al destinatario',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(ImageSource source) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Protege la privacidad'),
        content: const Text(
          'La foto no debe mostrar el rostro, documentos, dirección, fachada, número domiciliario ni otros elementos que identifiquen a la persona o permitan localizar su domicilio. El recorrido del bien puede consultarse públicamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    final selected = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (selected != null && mounted) {
      setState(() => _photo = File(selected.path));
    }
  }

  Future<void> _submit() async {
    final userId = ref.read(authStateProvider).value?.uid;
    if (userId == null) {
      showAppSnackBar(
        context,
        'Inicia sesión para registrar la entrega.',
        kind: AppSnackBarKind.error,
      );
      return;
    }
    final draft = DeliveryDraft(
      photo: _photo,
      recipientInitials: _initialsController.text,
      district: _district,
    );
    final validation = draft.validate();
    if (validation != null) {
      showAppSnackBar(context, validation, kind: AppSnackBarKind.error);
      return;
    }
    final response = await ref
        .read(deliveryControllerProvider.notifier)
        .register(
          publication: widget.publication,
          userId: userId,
          draft: draft,
        );
    if (!mounted) return;
    if (response.error != null) {
      showAppSnackBar(context, response.error!, kind: AppSnackBarKind.error);
      return;
    }
    final pending = response.result == DeliverySubmissionResult.pending;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          pending
              ? 'Sin conexión: los datos y la foto quedaron guardados. Se sincronizarán automáticamente.'
              : 'Entrega registrada correctamente.',
        ),
        backgroundColor: pending ? AppColors.warning : AppColors.success,
      ),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Solo se registran las iniciales y el distrito; no se solicitan datos que permitan identificar al destinatario.',
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidencePreview extends StatelessWidget {
  const _EvidencePreview({required this.photo});

  final File? photo;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: photo == null
          ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_a_photo_outlined,
                  size: 44,
                  color: AppColors.textSecondary,
                ),
                SizedBox(height: 8),
                Text('La fotografía es obligatoria'),
              ],
            )
          : Image.file(photo!, fit: BoxFit.cover, cacheWidth: 1000),
    );
  }
}
