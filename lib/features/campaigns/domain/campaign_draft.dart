import 'dart:io';

import 'campaign.dart';

class CampaignNeedDraft {
  const CampaignNeedDraft({
    required this.id,
    this.name = '',
    this.requiredQuantity = 0,
    this.contributedQuantity = 0,
  });

  final String id;
  final String name;
  final int requiredQuantity;
  final int contributedQuantity;

  bool get isValid => name.trim().isNotEmpty && requiredQuantity > 0;

  CampaignNeed toNeed() => CampaignNeed(
    id: id,
    name: name.trim(),
    requiredQuantity: requiredQuantity,
    contributedQuantity: contributedQuantity,
  );
}

class CampaignDraft {
  const CampaignDraft({
    this.title = '',
    this.description = '',
    this.district = '',
    this.closeAt,
    this.collectionPointName = '',
    this.collectionPointAddress = '',
    this.collectionPointOpeningHours = '',
    this.needs = const [],
    this.newImage,
    this.existingImageUrl,
    this.existingImageStoragePath,
    this.removeExistingImage = false,
  });

  static const maxNeeds = 10;

  final String title;
  final String description;
  final String district;
  final DateTime? closeAt;
  final String collectionPointName;
  final String collectionPointAddress;
  final String collectionPointOpeningHours;
  final List<CampaignNeedDraft> needs;
  final File? newImage;
  final String? existingImageUrl;
  final String? existingImageStoragePath;
  final bool removeExistingImage;

  List<String> validationErrors(DateTime now) => [
    if (needs.isEmpty) 'Agrega al menos una necesidad.',
    if (title.trim().isEmpty) 'Escribe el título de la campaña.',
    if (description.trim().isEmpty) 'Describe la situación.',
    if (district.trim().isEmpty) 'Selecciona el distrito.',
    if (closeAt == null || !closeAt!.toUtc().isAfter(now.toUtc()))
      'Selecciona una fecha de cierre futura.',
    if (needs.length > maxNeeds) 'Puedes agregar hasta $maxNeeds necesidades.',
    if (needs.any((need) => need.name.trim().isEmpty))
      'Cada necesidad debe tener un nombre.',
    if (needs.any((need) => need.requiredQuantity <= 0))
      'Cada cantidad requerida debe ser mayor que cero.',
    if (collectionPointName.trim().isEmpty ||
        collectionPointAddress.trim().isEmpty ||
        collectionPointOpeningHours.trim().isEmpty)
      'Completa todos los datos del punto de acopio.',
  ];

  bool isValidAt(DateTime now) => validationErrors(now).isEmpty;

  factory CampaignDraft.fromCampaign(Campaign campaign) => CampaignDraft(
    title: campaign.title,
    description: campaign.description,
    district: campaign.district,
    closeAt: campaign.closeAt,
    collectionPointName: campaign.collectionPoint.name,
    collectionPointAddress: campaign.collectionPoint.address,
    collectionPointOpeningHours: campaign.collectionPoint.openingHours,
    needs: campaign.needs
        .map(
          (need) => CampaignNeedDraft(
            id: need.id,
            name: need.name,
            requiredQuantity: need.requiredQuantity,
            contributedQuantity: need.contributedQuantity,
          ),
        )
        .toList(growable: false),
    existingImageUrl: campaign.imageUrl,
    existingImageStoragePath: campaign.imageStoragePath,
  );
}

class CampaignAccess {
  const CampaignAccess({required this.role, required this.organizationName});

  static const userRole = 'usuario';
  static const organizationRole = 'organizacion';
  static const adminRole = 'administrador';

  final String role;
  final String organizationName;

  bool get isOrganization => role == organizationRole;
  bool get isAdmin => role == adminRole;
}
