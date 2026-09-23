import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/cajamarca_districts.dart';
import '../../../core/constants/item_categories.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/choice_sheet.dart';
import '../../../shared/widgets/missing_fields_dialog.dart';
import '../../../shared/widgets/step_app_bar.dart';
import '../domain/publish_draft.dart';
import 'mode_step.dart';
import 'publish_draft_notifier.dart';

const _detailGap = 10.0;

class FormStep extends ConsumerStatefulWidget {
  const FormStep({super.key});

  @override
  ConsumerState<FormStep> createState() => _FormStepState();
}

class _FormStepState extends ConsumerState<FormStep> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(publishDraftProvider);
    _titleController = TextEditingController(text: draft.title);
    _descriptionController = TextEditingController(text: draft.description);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(publishDraftProvider, (previous, next) {
      if (_titleController.text != next.title) {
        _titleController.text = next.title;
      }
      if (_descriptionController.text != next.description) {
        _descriptionController.text = next.description;
      }
    });

    final draft = ref.watch(publishDraftProvider);
    final notifier = ref.read(publishDraftProvider.notifier);

    return Scaffold(
      appBar: const StepAppBar(title: 'Datos del bien', step: 2),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (draft.aiFields.isNotEmpty) ...[
              const _AiBanner(),
              const SizedBox(height: 20),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel(
                  text: 'Título',
                  fromAi: draft.aiFields.contains(AiField.title),
                ),
                TextField(
                  controller: _titleController,
                  onChanged: notifier.updateTitle,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Por ejemplo: casaca de niño',
                  ),
                ),
                const SizedBox(height: 20),
                _FieldLabel(
                  text: 'Categoría',
                  fromAi: draft.aiFields.contains(AiField.category),
                ),
                _ChoiceField(
                  value: draft.category,
                  hint: 'Selecciona una categoría',
                  sheetTitle: 'Categoría',
                  options: ItemCategories.all,
                  onChanged: notifier.selectCategory,
                  icon: Icons.category_outlined,
                ),
                const SizedBox(height: 20),
                _FieldLabel(
                  text: 'Estado del bien',
                  fromAi: draft.aiFields.contains(AiField.condition),
                ),
                Row(
                  spacing: 10,
                  children: [
                    for (final condition in ItemConditions.all)
                      Expanded(
                        child: AppChip(
                          label: condition,
                          expand: true,
                          selected: draft.condition == condition,
                          onTap: () => notifier.selectCondition(condition),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _FieldLabel(
                  text: 'Descripción',
                  fromAi: draft.aiFields.contains(AiField.description),
                ),
                TextField(
                  controller: _descriptionController,
                  onChanged: notifier.updateDescription,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Cuenta cómo está el bien y por qué lo entregas',
                  ),
                ),
                const SizedBox(height: 20),
                const _FieldLabel(text: 'Distrito de publicación'),
                _ChoiceField(
                  value: draft.district,
                  hint: 'Selecciona el distrito',
                  sheetTitle: 'Distrito de publicación',
                  options: CajamarcaDistricts.all,
                  onChanged: notifier.selectDistrict,
                  icon: Icons.location_on_outlined,
                ),
              ],
            ),
            const SizedBox(height: 28),
            _SectionTitle(
              icon: Icons.tune,
              title: 'Detalles',
              trailing: '${draft.details.length} de ${PublishDraft.maxDetails}',
            ),
            const SizedBox(height: 6),
            Text(
              'Agrega lo que ayude a reconocerlo: talla, marca, material, medidas. Son opcionales.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            if (draft.details.isNotEmpty) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - _detailGap) / 2;
                  return Wrap(
                    spacing: _detailGap,
                    runSpacing: _detailGap,
                    children: [
                      for (var index = 0; index < draft.details.length; index++)
                        SizedBox(
                          width: width,
                          child: _DetailCard(
                            detail: draft.details[index],
                            onEdit: () =>
                                _editDetail(index, draft.details[index]),
                            onRemove: () => notifier.removeDetail(index),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              onPressed: draft.canAddDetail
                  ? () => _editDetail(null, null)
                  : null,
              icon: const Icon(Icons.add, size: 20),
              label: Text(
                draft.canAddDetail
                    ? 'Agregar detalle'
                    : 'Llegaste al máximo de ${PublishDraft.maxDetails}',
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => _continue(draft),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }

  void _continue(PublishDraft draft) {
    if (!draft.formCompleted) {
      showMissingFieldsDialog(context, fields: draft.missingFormFields);
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ModeStep()));
  }

  Future<void> _editDetail(int? index, ItemDetail? current) async {
    final result = await showDialog<ItemDetail>(
      context: context,
      builder: (_) => _DetailDialog(detail: current),
    );
    if (result == null) return;

    final notifier = ref.read(publishDraftProvider.notifier);
    if (index == null) {
      notifier.addDetail(result);
    } else {
      notifier.updateDetail(index, result);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text, this.fromAi = false});

  final String text;
  final bool fromAi;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            text,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: AppColors.textSecondary),
          ),
          if (fromAi) ...[const SizedBox(width: 8), const AiBadge()],
        ],
      ),
    );
  }
}

class AiBadge extends StatelessWidget {
  const AiBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome,
            size: 11,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 4),
          Text(
            'IA',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiBanner extends StatelessWidget {
  const _AiBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF1DE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, size: 20, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Completamos estos datos a partir de tus fotos. Revísalos y edita lo que necesites.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceField extends StatelessWidget {
  const _ChoiceField({
    required this.value,
    required this.hint,
    required this.sheetTitle,
    required this.options,
    required this.onChanged,
    this.icon,
  });

  final String? value;
  final String hint;
  final String sheetTitle;
  final List<String> options;
  final void Function(String) onChanged;
  final IconData? icon;

  Future<void> _open(BuildContext context) async {
    final chosen = await showChoiceSheet<String>(
      context,
      title: sheetTitle,
      selected: value,
      options: [
        for (final option in options)
          ChoiceOption(value: option, label: option),
      ],
    );
    if (chosen != null) onChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    return SelectorField(
      value: value,
      hint: hint,
      icon: icon,
      onTap: () => _open(context),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.detail,
    required this.onEdit,
    required this.onRemove,
  });

  final ItemDetail detail;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  static final _shape = BorderRadius.circular(14);

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;

    return Stack(
      children: [
        Material(
          color: AppColors.surface,
          borderRadius: _shape,
          child: InkWell(
            onTap: onEdit,
            borderRadius: _shape,
            child: Ink(
              padding: const EdgeInsets.fromLTRB(14, 10, 34, 12),
              decoration: BoxDecoration(
                borderRadius: _shape,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          detail.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: texts.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (detail.generatedByAi) ...[
                        const SizedBox(width: 6),
                        const AiBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: texts.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 13, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailDialog extends StatefulWidget {
  const _DetailDialog({this.detail});

  final ItemDetail? detail;

  @override
  State<_DetailDialog> createState() => _DetailDialogState();
}

class _DetailDialogState extends State<_DetailDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.detail?.name ?? '');
    _valueController = TextEditingController(text: widget.detail?.value ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  static const _fieldDecoration = InputDecoration(
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    final labelStyle = texts.labelMedium?.copyWith(
      color: AppColors.textSecondary,
    );

    return AppDialog(
      title: widget.detail == null ? 'Nuevo detalle' : 'Editar detalle',
      subtitle: 'Una característica del bien y su valor',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nombre del campo', style: labelStyle),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            style: texts.bodyMedium,
            decoration: _fieldDecoration.copyWith(hintText: 'Talla'),
          ),
          const SizedBox(height: 14),
          Text('Valor', style: labelStyle),
          const SizedBox(height: 6),
          TextField(
            controller: _valueController,
            textCapitalization: TextCapitalization.sentences,
            style: texts.bodyMedium,
            decoration: _fieldDecoration.copyWith(hintText: 'M'),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    final value = _valueController.text.trim();
    if (name.isEmpty || value.isEmpty) return;
    Navigator.of(context).pop(ItemDetail(name: name, value: value));
  }
}
