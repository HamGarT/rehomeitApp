import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  void applyAiSuggestion({
    required String title,
    required String category,
    required String condition,
    required String description,
    required List<ItemDetail> details,
  }) {
    state = state.copyWith(
      title: title,
      category: category,
      condition: condition,
      description: description,
      details: details.take(PublishDraft.maxDetails).toList(),
      aiFields: AiField.values.toSet(),
    );
  }

  Set<AiField> _withoutAi(AiField field) {
    return state.aiFields.where((it) => it != field).toSet();
  }
}
