import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/cajamarca_districts.dart';
import '../../../shared/domain/person_name.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/button_spinner.dart';
import '../../../shared/widgets/choice_sheet.dart';
import '../../../shared/widgets/image_picking.dart';
import '../../../shared/widgets/image_source_sheet.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../explore/domain/public_profile.dart';
import '../../explore/presentation/explore_controller.dart';
import '../data/profile_repository.dart';
import 'profile_controller.dart';

/// Edición del perfil propio (HU20-9): foto, nombres, apellidos y distrito.
/// El correo no aparece porque no es editable (HU20-10).
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNamesController = TextEditingController();
  final _lastNamesController = TextEditingController();

  /// Valor sin distrito. Se guarda como cadena vacía, que las reglas admiten.
  static const _noDistrict = '';
  static const _photoMaxWidth = 1024.0;
  static const _photoQuality = 85;

  String _district = _noDistrict;
  File? _newPhoto;
  bool _removePhoto = false;
  bool _prefilled = false;
  bool _saving = false;

  @override
  void dispose() {
    _firstNamesController.dispose();
    _lastNamesController.dispose();
    super.dispose();
  }

  /// Los campos se rellenan una sola vez con lo guardado; después manda lo
  /// que la persona escribe, aunque el stream vuelva a emitir.
  void _prefill(PersonName? name, PublicProfile? profile) {
    if (_prefilled || name == null || profile == null) return;
    _prefilled = true;
    _firstNamesController.text = name.firstNames;
    _lastNamesController.text = name.lastNames;
    _district = profile.district;
  }

  Future<void> _choosePhoto() async {
    final source = await showImageSourceSheet(context);
    if (source == null || !mounted) return;
    final picked = await pickImageOrExplain(
      context,
      source: source,
      maxWidth: _photoMaxWidth,
      imageQuality: _photoQuality,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _newPhoto = File(picked.path);
      _removePhoto = false;
    });
  }

  void _clearPhoto() {
    setState(() {
      _newPhoto = null;
      _removePhoto = true;
    });
  }

  Future<void> _chooseDistrict() async {
    final chosen = await showChoiceSheet<String>(
      context,
      title: 'Tu distrito',
      selected: _district,
      options: [
        const ChoiceOption(value: _noDistrict, label: 'Prefiero no indicarlo'),
        for (final district in CajamarcaDistricts.all)
          ChoiceOption(value: district, label: district),
      ],
    );
    if (chosen != null && mounted) setState(() => _district = chosen);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(
            userId: widget.userId,
            names: PersonName(
              firstNames: _firstNamesController.text.trim(),
              lastNames: _lastNamesController.text.trim(),
            ),
            district: _district,
            newPhoto: _newPhoto,
            removePhoto: _removePhoto,
          );
      if (!mounted) return;
      // El perfil público es un stream y se actualiza solo; se invalida igual
      // por si la lectura venía de caché.
      ref.invalidate(publicProfileProvider(widget.userId));
      Navigator.of(context).pop(true);
    } on ProfileFailure catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.message, kind: AppSnackBarKind.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateName(String? value, String label) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$label es obligatorio.';
    if (text.length > PersonName.maxLength) {
      return '$label admite hasta ${PersonName.maxLength} caracteres.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;
    final name = ref.watch(ownNameProvider(widget.userId)).value;
    final profile = ref.watch(publicProfileProvider(widget.userId)).value;
    _prefill(name, profile);

    final currentPhotoUrl = _removePhoto ? null : profile?.photoUrl;
    final hasPhoto = _newPhoto != null || currentPhotoUrl != null;
    final previewName = _firstNamesController.text.isEmpty
        ? (profile?.shortName ?? '')
        : _firstNamesController.text;

    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _saving ? null : _choosePhoto,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          _newPhoto != null
                              ? CircleAvatar(
                                  radius: 48,
                                  backgroundImage: FileImage(_newPhoto!),
                                )
                              : UserAvatar(
                                  name: previewName,
                                  radius: 48,
                                  photoUrl: currentPhotoUrl,
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.black,
                                  textStyle: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: palette.primary,
                            child: Icon(
                              Icons.photo_camera_outlined,
                              size: 18,
                              color: palette.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _saving ? null : _choosePhoto,
                      child: Text(hasPhoto ? 'Cambiar foto' : 'Agregar foto'),
                    ),
                    if (hasPhoto)
                      TextButton(
                        onPressed: _saving ? null : _clearPhoto,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                        child: const Text('Quitar foto'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _firstNamesController,
                decoration: const InputDecoration(
                  labelText: 'Nombres',
                  prefixIcon: Icon(Icons.person_outline, size: 20),
                ),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (value) => _validateName(value, 'El nombre'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _lastNamesController,
                decoration: const InputDecoration(
                  labelText: 'Apellidos',
                  prefixIcon: Icon(Icons.badge_outlined, size: 20),
                ),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                validator: (value) => _validateName(value, 'El apellido'),
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 14),
              SelectorField(
                value: _district == _noDistrict ? null : _district,
                hint: 'Distrito',
                icon: Icons.location_on_outlined,
                onTap: _saving ? () {} : _chooseDistrict,
              ),
              const SizedBox(height: 10),
              Text(
                'Los demás te verán como "${PersonName(firstNames: _firstNamesController.text.trim(), lastNames: _lastNamesController.text.trim()).short}". '
                'Tu correo no se muestra ni se puede cambiar desde aquí.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.textSecondary, height: 1.35),
              ),
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving ? const ButtonSpinner() : const Icon(Icons.check),
                label: const Text('Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
