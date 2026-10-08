import 'dart:io';

import '../../../core/constants/cajamarca_districts.dart';

class DeliveryDraft {
  const DeliveryDraft({this.photo, this.recipientInitials = '', this.district});

  final File? photo;
  final String recipientInitials;
  final String? district;

  List<String> get missingFields => [
    if (photo == null) 'fotografía de evidencia',
    if (recipientInitials.trim().isEmpty) 'iniciales del destinatario',
    if (district == null || district!.isEmpty) 'distrito',
  ];

  bool get isComplete => missingFields.isEmpty;

  String get normalizedInitials => recipientInitials
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-ZÁÉÍÓÚÜÑ.]'), '');

  String? validate() {
    if (missingFields.isNotEmpty) {
      return 'Falta: ${missingFields.join(', ')}.';
    }
    final initials = normalizedInitials;
    if (initials.isEmpty || initials.length > 12) {
      return 'Ingresa solo las iniciales del destinatario (máximo 12 caracteres).';
    }
    if (!CajamarcaDistricts.all.contains(district)) {
      return 'Selecciona un distrito válido de la provincia de Cajamarca.';
    }
    return null;
  }
}

enum DeliverySubmissionResult { synchronized, pending }
