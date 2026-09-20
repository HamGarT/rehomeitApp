import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/step_app_bar.dart';
import '../domain/publish_draft.dart';
import 'analyzing_step.dart';
import 'publish_draft_notifier.dart';

class PhotosStep extends ConsumerStatefulWidget {
  const PhotosStep({super.key});

  @override
  ConsumerState<PhotosStep> createState() => _PhotosStepState();
}

class _PhotosStepState extends ConsumerState<PhotosStep> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(publishDraftProvider);
    final texts = Theme.of(context).textTheme;
    final selected = _selectedIndex < draft.photos.length
        ? draft.photos[_selectedIndex]
        : null;

    return Scaffold(
      appBar: StepAppBar(
        title: 'Nuevo bien',
        step: 1,
        onClose: () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Preview(photo: selected)),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fotografías',
                    style: texts.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${draft.photos.length} de ${PublishDraft.maxPhotos}',
                    style: texts.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                spacing: 10,
                children: [
                  for (var index = 0; index < PublishDraft.maxPhotos; index++)
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: index < draft.photos.length
                            ? _Thumbnail(
                                photo: draft.photos[index],
                                selected: index == _selectedIndex,
                                onTap: () =>
                                    setState(() => _selectedIndex = index),
                                onRemove: () => _remove(index),
                              )
                            : const _EmptySlot(),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: draft.canAddPhoto
                    ? () => _pick(ImageSource.camera)
                    : null,
                icon: const Icon(Icons.photo_camera_outlined, size: 20),
                label: const Text('Tomar fotografía'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: draft.canAddPhoto
                    ? () => _pick(ImageSource.gallery)
                    : null,
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text('Elegir de la galería'),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: draft.photosCompleted ? _continue : null,
                child: const Text('Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _continue() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AnalyzingStep()),
    );
  }

  void _remove(int index) {
    ref.read(publishDraftProvider.notifier).removePhoto(index);
    final remaining = ref.read(publishDraftProvider).photos.length;
    setState(() {
      _selectedIndex = _selectedIndex >= remaining ? 0 : _selectedIndex;
    });
  }

  Future<void> _pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    ref.read(publishDraftProvider.notifier).addPhoto(File(picked.path));
    final photos = ref.read(publishDraftProvider).photos;
    setState(() => _selectedIndex = photos.length - 1);
  }
}

class _Preview extends StatelessWidget {
  const _Preview({this.photo});

  final File? photo;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: photo == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_a_photo_outlined,
                  size: 44,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 14),
                Text(
                  'Agrega hasta 4 fotografías del bien',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Mientras mejor se vea, mejor se describe solo',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            )
          : Image.file(photo!, fit: BoxFit.cover, cacheWidth: 1000),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.photo,
    required this.selected,
    required this.onTap,
    required this.onRemove,
  });

  final File photo;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.file(photo, fit: BoxFit.cover, cacheWidth: 300),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
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
        ],
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Icon(Icons.add, color: AppColors.textSecondary, size: 20),
    );
  }
}
