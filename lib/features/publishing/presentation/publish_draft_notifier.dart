import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/item_analysis_service.dart';
import '../domain/item_suggestion.dart';
import '../domain/publish_draft.dart';

final publishDraftProvider =
    NotifierProvider<PublishDraftNotifier, PublishDraft>(
      PublishDraftNotifier.new,
    );

class PublishDraftNotifier extends Notifier<PublishDraft> {
  @override
  PublishDraft build() => const PublishDraft();

  void reset() => state = const PublishDraft();

  void addPhoto(File photo) {
    if (!state.canAddPhoto) return;
    state = state.copyWith(photos: [...state.photos, photo]);
  }

  void removePhoto(int index) {
    final photos = [...state.photos]..removeAt(index);
    state = state.copyWith(photos: photos);
  }

  void updateTitle(String value) {
    state = state.copyWith(title: value, aiFields: _withoutAi(AiField.title));
  }

  void updateDescription(String value) {
    state = state.copyWith(
      description: value,
      aiFields: _withoutAi(AiField.description),
    );
  }

  void selectCategory(String value) {
    state = state.copyWith(
      category: value,
      aiFields: _withoutAi(AiField.category),
    );
  }

  void selectCondition(String value) {
    state = state.copyWith(
      condition: value,
      aiFields: _withoutAi(AiField.condition),
    );
  }

  void selectDistrict(String value) {
    state = state.copyWith(district: value);
  }

  void selectMode(PublishMode value) {
    state = state.copyWith(mode: value);
  }

  void selectDeliveryMethod(DeliveryMethod value) {
    state = state.copyWith(deliveryMethod: value);
  }

  void addDetail(ItemDetail detail) {
    if (!state.canAddDetail) return;
    state = state.copyWith(details: [...state.details, detail]);
  }

  void updateDetail(int index, ItemDetail detail) {
    final details = [...state.details];
    details[index] = detail;
    state = state.copyWith(details: details);
  }

  void removeDetail(int index) {
    final details = [...state.details]..removeAt(index);
    state = state.copyWith(details: details);
  }

  /// Analiza las fotografías del borrador y aplica la sugerencia. Devuelve
  /// `null` si se aplicó, o el mensaje a mostrar si no hubo sugerencia; en
  /// ese caso los campos sugeridos se presentan vacíos para el ingreso manual
  /// (HU04-7 y HU05-8) y lo que la persona ya escribió se conserva.
  Future<String?> analyzePhotos() async {
    try {
      final suggestion = await ref
          .read(itemAnalysisServiceProvider)
          .analyze(state.photos);
      applyAiSuggestion(suggestion);
      return null;
    } on ItemAnalysisException catch (error) {
      discardAiSuggestion();
      return error.message;
    }
  }

  /// Vacía lo que vino de la IA y nada más: en un segundo análisis fallido la
  /// sugerencia anterior ya no responde a estas fotografías, pero lo editado a
  /// mano sigue siendo de la persona.
  void discardAiSuggestion() {
    final ai = state.aiFields;
    state = PublishDraft(
      photos: state.photos,
      title: ai.contains(AiField.title) ? '' : state.title,
      category: ai.contains(AiField.category) ? null : state.category,
      condition: ai.contains(AiField.condition) ? null : state.condition,
      description: ai.contains(AiField.description) ? '' : state.description,
      details: state.details
          .where((detail) => !detail.generatedByAi)
          .toList(growable: false),
      district: state.district,
      mode: state.mode,
      deliveryMethod: state.deliveryMethod,
    );
  }

  void applyAiSuggestion(ItemSuggestion suggestion) {
    state = state.copyWith(
      title: suggestion.title,
      category: suggestion.category,
      condition: suggestion.condition,
      description: suggestion.description,
      details: suggestion.details.take(PublishDraft.maxDetails).toList(),
      aiFields: {
        if (suggestion.title.isNotEmpty) AiField.title,
        if (suggestion.category != null) AiField.category,
        if (suggestion.condition != null) AiField.condition,
        if (suggestion.description.isNotEmpty) AiField.description,
      },
    );
  }

  Set<AiField> _withoutAi(AiField field) {
    return state.aiFields.where((it) => it != field).toSet();
  }
}
