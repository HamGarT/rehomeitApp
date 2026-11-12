import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehomeitapp/features/publishing/domain/publish_draft.dart';
import 'package:rehomeitapp/features/publishing/presentation/publish_draft_notifier.dart';

void main() {
  group('PublishDraft.photosScreened', () {
    test('empieza en false y copyWith lo conserva si no se indica', () {
      const draft = PublishDraft();
      expect(draft.photosScreened, isFalse);

      final screened = draft.copyWith(photosScreened: true);
      expect(screened.photosScreened, isTrue);
      expect(screened.copyWith(title: 'Mesa').photosScreened, isTrue);
    });

    ProviderContainer screenedContainer() {
      final container = ProviderContainer(
        overrides: [
          publishDraftProvider.overrideWith(_ScreenedDraftNotifier.new),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(publishDraftProvider).photosScreened, isTrue);
      return container;
    }

    test('agregar una foto invalida el veredicto', () {
      final container = screenedContainer();
      container.read(publishDraftProvider.notifier).addPhoto(File('nueva.jpg'));
      expect(container.read(publishDraftProvider).photosScreened, isFalse);
    });

    test('quitar una foto invalida el veredicto', () {
      final container = screenedContainer();
      container.read(publishDraftProvider.notifier).removePhoto(0);
      expect(container.read(publishDraftProvider).photosScreened, isFalse);
    });

    test('reordenar conserva el veredicto', () {
      final container = screenedContainer();
      container.read(publishDraftProvider.notifier).movePhoto(1, 0);
      final draft = container.read(publishDraftProvider);
      expect(draft.photos.first.path, 'revisada_1.jpg');
      expect(draft.photosScreened, isTrue);
    });
  });

  group('PublishDraftNotifier.movePhoto', () {
    List<String> pathsAfter(void Function(PublishDraftNotifier) action) {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(publishDraftProvider.notifier);
      for (final name in ['a', 'b', 'c', 'd']) {
        notifier.addPhoto(File('$name.jpg'));
      }
      action(notifier);
      return container
          .read(publishDraftProvider)
          .photos
          .map((photo) => photo.path)
          .toList();
    }

    test('la cuarta pasa a ser la portada y las demás se corren', () {
      expect(pathsAfter((notifier) => notifier.movePhoto(3, 0)), [
        'd.jpg',
        'a.jpg',
        'b.jpg',
        'c.jpg',
      ]);
    });

    test('la portada puede bajar a otra posición', () {
      expect(pathsAfter((notifier) => notifier.movePhoto(0, 2)), [
        'b.jpg',
        'c.jpg',
        'a.jpg',
        'd.jpg',
      ]);
    });

    test('un índice fuera de rango no cambia nada', () {
      expect(pathsAfter((notifier) => notifier.movePhoto(1, 7)), [
        'a.jpg',
        'b.jpg',
        'c.jpg',
        'd.jpg',
      ]);
    });
  });
}

/// Borrador que arranca con fotos ya revisadas, como queda tras HU04.
class _ScreenedDraftNotifier extends PublishDraftNotifier {
  @override
  PublishDraft build() => PublishDraft(
    photos: [File('revisada_0.jpg'), File('revisada_1.jpg')],
    photosScreened: true,
  );
}
