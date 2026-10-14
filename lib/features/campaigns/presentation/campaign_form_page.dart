import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../../core/constants/cajamarca_districts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/button_spinner.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/campaign.dart';
import '../domain/campaign_draft.dart';
import 'campaign_controller.dart';

class CampaignFormPage extends ConsumerWidget {
  const CampaignFormPage({super.key, this.initial});

  final Campaign? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authStateProvider).value?.uid ?? '';
    if (userId.isEmpty) {
      return const _AccessDenied(message: 'Inicia sesión para continuar.');
    }
    final access = ref.watch(campaignAccessProvider(userId));
    return access.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const _AccessDenied(
        message: 'No pudimos verificar los permisos de tu cuenta.',
      ),
      data: (value) {
        final now =
            ref.watch(campaignClockProvider).value ?? DateTime.now().toUtc();
        final ownsInitial =
            initial == null || initial!.organizationId == userId;
        final isEditable = initial == null || !initial!.isClosedAt(now);
        if (!value.isOrganization || !ownsInitial || !isEditable) {
          return const _AccessDenied(
            message: 'No tienes permiso para administrar esta campaña.',
          );
        }
        return _CampaignForm(
          key: ValueKey(initial?.id ?? 'new-campaign'),
          initial: initial,
          userId: userId,
          organizationName: value.organizationName,
        );
      },
    );
  }
}

class _CampaignForm extends ConsumerStatefulWidget {
  const _CampaignForm({
    super.key,
    required this.initial,
    required this.userId,
    required this.organizationName,
  });

  final Campaign? initial;
  final String userId;
  final String organizationName;

  @override
  ConsumerState<_CampaignForm> createState() => _CampaignFormState();
}

class _CampaignFormState extends ConsumerState<_CampaignForm> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _pointName;
  late final TextEditingController _pointAddress;
  late final TextEditingController _pointHours;
  final ImagePicker _picker = ImagePicker();
  final List<_EditableNeed> _needs = [];
  String? _district;
  DateTime? _closeAt;
  File? _newImage;
  bool _removeExistingImage = false;
  String? _validationMessage;
  int _needSequence = 0;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final campaign = widget.initial;
    _title = TextEditingController(text: campaign?.title ?? '');
    _description = TextEditingController(text: campaign?.description ?? '');
    _pointName = TextEditingController(
      text: campaign?.collectionPoint.name ?? '',
    );
    _pointAddress = TextEditingController(
      text: campaign?.collectionPoint.address ?? '',
    );
    _pointHours = TextEditingController(
      text: campaign?.collectionPoint.openingHours ?? '',
    );
    _district = campaign?.district;
    _closeAt = campaign?.closeAt;
    if (campaign != null) {
      _needs.addAll(
        campaign.needs.map(
          (need) => _EditableNeed(
            id: need.id,
            name: need.name,
            quantity: need.requiredQuantity.toString(),
            contributedQuantity: need.contributedQuantity,
            persisted: true,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _pointName.dispose();
    _pointAddress.dispose();
    _pointHours.dispose();
    for (final need in _needs) {
      need.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(campaignControllerProvider).isLoading;
    final existingImage = widget.initial?.imageUrl;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar campaña' : 'Crear campaña'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            const _SectionTitle('Información principal'),
            const SizedBox(height: 10),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Título de campaña'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: widget.organizationName,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Organización responsable',
                prefixIcon: Icon(Icons.verified_user_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción de la situación',
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _district,
              decoration: const InputDecoration(
                labelText: 'Distrito de alcance',
              ),
              items: [
                for (final district in CajamarcaDistricts.all)
                  DropdownMenuItem(value: district, child: Text(district)),
              ],
              onChanged: (value) => setState(() => _district = value),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _pickCloseDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _closeAt == null
                    ? 'Seleccionar fecha de cierre'
                    : 'Cierre: ${_dateLabel(_closeAt!)}',
              ),
            ),
            const SizedBox(height: 22),
            const _SectionTitle('Imagen representativa (opcional)'),
            const SizedBox(height: 10),
            if (_newImage != null)
              _ImagePreview(image: FileImage(_newImage!))
            else if (existingImage != null && !_removeExistingImage)
              _ImagePreview(image: NetworkImage(existingImage)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _pickImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      _newImage == null && existingImage == null
                          ? 'Elegir imagen'
                          : 'Cambiar imagen',
                    ),
                  ),
                ),
                if (_newImage != null ||
                    (existingImage != null && !_removeExistingImage)) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Quitar imagen',
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            _newImage = null;
                            _removeExistingImage = true;
                          }),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: _SectionTitle('Necesidades')),
                Text('${_needs.length}/${CampaignDraft.maxNeeds}'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Las necesidades cubiertas seguirán admitiendo aportes en la siguiente etapa.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: context.appColors.textSecondary),
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < _needs.length; index++)
              _NeedEditor(
                key: ValueKey(_needs[index].id),
                need: _needs[index],
                onRemove: _needs[index].persisted
                    ? null
                    : () => _removeNeed(index),
              ),
            OutlinedButton.icon(
              key: const Key('add-campaign-need'),
              onPressed: _needs.length >= CampaignDraft.maxNeeds
                  ? null
                  : _addNeed,
              icon: const Icon(Icons.add),
              label: const Text('Agregar necesidad'),
            ),
            const SizedBox(height: 22),
            const _SectionTitle('Punto de acopio'),
            const SizedBox(height: 10),
            TextField(
              controller: _pointName,
              decoration: const InputDecoration(labelText: 'Nombre del punto'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pointAddress,
              decoration: const InputDecoration(labelText: 'Dirección'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pointHours,
              decoration: const InputDecoration(
                labelText: 'Horario de atención',
              ),
            ),
            if (_validationMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _validationMessage!,
                key: const Key('campaign-form-error'),
                style: const TextStyle(color: AppColors.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('campaign-form-submit'),
              onPressed: busy ? null : _submit,
              child: busy
                  ? const ButtonSpinner()
                  : Text(_editing ? 'Guardar cambios' : 'Publicar campaña'),
            ),
          ],
        ),
      ),
    );
  }

  void _addNeed() {
    final id =
        'need_${DateTime.now().microsecondsSinceEpoch}_${_needSequence++}';
    setState(() => _needs.add(_EditableNeed(id: id)));
  }

  void _removeNeed(int index) {
    final need = _needs.removeAt(index);
    need.dispose();
    setState(() {});
  }

  Future<void> _pickImage() async {
    final selected = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _newImage = File(selected.path);
      _removeExistingImage = false;
    });
  }

  Future<void> _pickCloseDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _closeAt?.toLocal() ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (selected == null) return;
    setState(() {
      _closeAt = DateTime(selected.year, selected.month, selected.day, 23, 59);
    });
  }

  CampaignDraft _draft() => CampaignDraft(
    title: _title.text,
    description: _description.text,
    district: _district ?? '',
    closeAt: _closeAt,
    collectionPointName: _pointName.text,
    collectionPointAddress: _pointAddress.text,
    collectionPointOpeningHours: _pointHours.text,
    needs: _needs
        .map(
          (need) => CampaignNeedDraft(
            id: need.id,
            name: need.name.text,
            requiredQuantity: int.tryParse(need.quantity.text.trim()) ?? 0,
            contributedQuantity: need.contributedQuantity,
          ),
        )
        .toList(growable: false),
    newImage: _newImage,
    existingImageUrl: widget.initial?.imageUrl,
    existingImageStoragePath: widget.initial?.imageStoragePath,
    removeExistingImage: _removeExistingImage,
  );

  Future<void> _submit() async {
    final draft = _draft();
    final errors = draft.validationErrors(DateTime.now());
    if (errors.isNotEmpty) {
      setState(() => _validationMessage = errors.first);
      return;
    }
    setState(() => _validationMessage = null);

    final controller = ref.read(campaignControllerProvider.notifier);
    String? error;
    if (widget.initial case final campaign?) {
      error = await controller.update(campaign: campaign, draft: draft);
    } else {
      final result = await controller.create(
        draft: draft,
        organizationId: widget.userId,
        organizationName: widget.organizationName,
      );
      error = result.error;
    }
    if (!mounted) return;
    if (error != null) {
      setState(() => _validationMessage = error);
      return;
    }
    Navigator.of(context).pop(true);
  }
}

class _EditableNeed {
  _EditableNeed({
    required this.id,
    String name = '',
    String quantity = '',
    this.contributedQuantity = 0,
    this.persisted = false,
  }) : name = TextEditingController(text: name),
       quantity = TextEditingController(text: quantity);

  final String id;
  final TextEditingController name;
  final TextEditingController quantity;
  final int contributedQuantity;
  final bool persisted;

  void dispose() {
    name.dispose();
    quantity.dispose();
  }
}

class _NeedEditor extends StatelessWidget {
  const _NeedEditor({super.key, required this.need, required this.onRemove});

  final _EditableNeed need;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: need.name,
              decoration: const InputDecoration(labelText: 'Necesidad'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: need.quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad'),
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Quitar necesidad',
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    ),
  );
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.image});

  final ImageProvider image;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image(image: image, fit: BoxFit.cover),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w700),
  );
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Campañas')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    ),
  );
}

String _dateLabel(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}
