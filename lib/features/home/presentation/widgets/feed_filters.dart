import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/cajamarca_districts.dart';
import '../../../../shared/domain/publication.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../../../shared/widgets/choice_sheet.dart';
import '../../../explore/domain/explore_filters.dart';

OutlineInputBorder _searchBorder(Color color, double width) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: color, width: width),
  );
}

/// Campo de búsqueda por título (HU08-8). Solo se monta mientras la lupa de la
/// cabecera está activa, por eso toma el foco al aparecer.
class FeedSearchField extends StatelessWidget {
  const FeedSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;
    // `TextField` exige un `Material` ancestro y el feed no trae uno propio:
    // como pestaña lo sostiene el `Scaffold` del shell, pero montado solo
    // (en pruebas) no hay ninguno.
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: TextField(
          key: const Key('feed-search-field'),
          controller: controller,
          autofocus: true,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: '¿Qué necesitas? Ropa, muebles, libros...',
            hintStyle: TextStyle(color: palette.textSecondary),
            prefixIcon: Icon(Icons.search, color: palette.primary),
            border: _searchBorder(palette.primary, 1),
            enabledBorder: _searchBorder(palette.primary, 1),
            focusedBorder: _searchBorder(palette.primary, 2),
          ),
        ),
      ),
    );
  }
}

/// Filtros rápidos de modalidad y distrito (HU08-5 a HU08-7). Van en un
/// `Wrap` y no en una fila desplazable: con un distrito de nombre largo el
/// chip saltaba fuera de la pantalla y había que desplazar para verlo; aquí
/// baja a una segunda línea y el nombre se lee entero.
class FeedFilterChips extends StatelessWidget {
  const FeedFilterChips({
    super.key,
    required this.filters,
    required this.onModeSelected,
    required this.onDistrictSelected,
  });

  final ExploreFilters filters;
  final ValueChanged<PublicationMode?> onModeSelected;
  final ValueChanged<String?> onDistrictSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          AppChip(
            label: 'Todo',
            selected: filters.mode == null,
            onTap: () => onModeSelected(null),
          ),
          AppChip(
            label: 'Donación',
            selected: filters.mode == PublicationMode.donation,
            onTap: () => onModeSelected(PublicationMode.donation),
          ),
          AppChip(
            label: 'Intercambio',
            selected: filters.mode == PublicationMode.exchange,
            onTap: () => onModeSelected(PublicationMode.exchange),
          ),
          _DistrictChip(
            district: filters.district,
            onSelect: onDistrictSelected,
          ),
        ],
      ),
    );
  }
}

/// Tocar el chip abre la hoja de distritos; con uno elegido, la X lo limpia
/// sin abrirla.
class _DistrictChip extends StatelessWidget {
  const _DistrictChip({required this.district, required this.onSelect});

  static const _all = '';

  final String? district;
  final ValueChanged<String?> onSelect;

  Future<void> _open(BuildContext context) async {
    final chosen = await showChoiceSheet<String>(
      context,
      title: 'Distrito',
      selected: district ?? _all,
      options: [
        const ChoiceOption(value: _all, label: 'Todos los distritos'),
        for (final name in CajamarcaDistricts.all)
          ChoiceOption(value: name, label: name),
      ],
    );
    if (chosen == null) return;
    onSelect(chosen == _all ? null : chosen);
  }

  @override
  Widget build(BuildContext context) {
    final selected = district != null;
    return AppChip(
      label: district ?? 'Distrito',
      icon: Icons.location_on_outlined,
      selected: selected,
      onTap: () => _open(context),
      trailing: selected
          ? GestureDetector(
              onTap: () => onSelect(null),
              child: const Icon(
                Icons.close,
                size: 16,
                // Sobre el amarillo del chip seleccionado va siempre oscuro;
                // el texto del tema sería blanco en oscuro.
                color: AppColors.onAccent,
              ),
            )
          : Icon(
              Icons.expand_more,
              size: 18,
              color: context.appColors.textSecondary,
            ),
    );
  }
}
