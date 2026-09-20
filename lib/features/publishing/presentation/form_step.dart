import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/cajamarca_districts.dart';
import '../../../core/constants/item_categories.dart';
import '../../../shared/widgets/missing_fields_dialog.dart';
import '../../../shared/widgets/step_app_bar.dart';
import '../domain/publish_draft.dart';
import 'mode_step.dart';
import 'publish_draft_notifier.dart';

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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (draft.aiFields.isNotEmpty) ...[
              const _AiBanner(),
              const SizedBox(height: 20),
            ],
            const _SectionTitle(
              icon: Icons.inventory_2_outlined,
              title: 'Ficha del bien',
            ),
            const SizedBox(height: 12),
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
                _Dropdown(
                  value: draft.category,
                  hint: 'Selecciona una categoría',
                  options: ItemCategories.all,
                  onChanged: notifier.selectCategory,
                ),
                const SizedBox(height: 20),
                _FieldLabel(
                  text: 'Estado del bien',
                  fromAi: draft.aiFields.contains(AiField.condition),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final condition in ItemConditions.all)
                      ChoiceChip(
                        label: Text(condition),
                        selected: draft.condition == condition,
                        onSelected: (_) => notifier.selectCondition(condition),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < draft.details.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DetailRow(
                  detail: draft.details[index],
                  onEdit: () => _editDetail(index, draft.details[index]),
                  onRemove: () => notifier.removeDetail(index),
                ),
              ),
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
            const _SectionTitle(
              icon: Icons.location_on_outlined,
              title: 'Ubicación',
            ),
            const SizedBox(height: 12),
            _Dropdown(
              value: draft.district,
              hint: 'Selecciona el distrito',
              options: CajamarcaDistricts.all,
              onChanged: notifier.selectDistrict,
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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ModeStep()),
    );
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
  const _SectionTitle({
    required this.icon,
    required this.title,
    this.trailing,
  });

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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
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
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
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
          const Icon(Icons.auto_awesome, size: 11, color: AppColors.textPrimary),
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

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.hint,
    required this.options,
    required this.onChanged,
  });

  final String? value;
  final String hint;
  final List<String> options;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      hint: Text(hint),
      isExpanded: true,
      borderRadius: BorderRadius.circular(14),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.detail,
    required this.onEdit,
    required this.onRemove,
  });

  final ItemDetail detail;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      detail.name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (detail.generatedByAi) ...[
                      const SizedBox(width: 8),
                      const AiBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  detail.value,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: AppColors.textSecondary,
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline, size: 20),
            color: AppColors.textSecondary,
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                widget.detail == null ? 'Nuevo detalle' : 'Editar detalle',
                style: texts.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Una característica del bien y su valor',
                style: texts.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Nombre del campo',
              style: texts.labelLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Talla'),
            ),
            const SizedBox(height: 16),
            Text(
              'Valor',
              style: texts.labelLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _valueController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'M'),
            ),
            const SizedBox(height: 24),
            Row(
              spacing: 12,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    final value = _valueController.text.trim();
    if (name.isEmpty || value.isEmpty) return;
    Navigator.of(context).pop(ItemDetail(name: name, value: value));
  }
}
