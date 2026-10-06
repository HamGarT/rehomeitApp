import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reacción de una persona a una publicación, tal como se ve hoy en el feed.
///
/// Esto es estado local de la sesión, no un dato guardado. No hay nada de esto
/// en Firestore todavía: las reglas de `publicaciones` usan
/// `keys().hasOnly([...])`, así que añadir `votos` o `contadores` a la
/// publicación está denegado. Persistirlo pide una colección aparte con su
/// bloque de reglas; cuando exista, este notifier es el único punto a cambiar.
@immutable
class PostReaction {
  const PostReaction({this.loved = false});

  static const none = PostReaction();

  final bool loved;

  PostReaction withLoved(bool next) => PostReaction(loved: next);
}

/// Reacciones locales, indexadas por id de publicación.
///
/// El mapa vive aquí y no en el `State` de la tarjeta a propósito:
/// `SliverList.builder` destruye las tarjetas al salir de la pantalla, y con
/// estado en la tarjeta la marca se perdería al hacer scroll.
///
/// Es por sesión: al reiniciar la app vuelve a estar vacío.
class PostReactionsNotifier extends Notifier<Map<String, PostReaction>> {
  @override
  Map<String, PostReaction> build() => const {};

  PostReaction of(String publicationId) =>
      state[publicationId] ?? PostReaction.none;

  /// Marca "me encanta". Un segundo toque la retira.
  void toggleLoved(String publicationId) {
    final current = of(publicationId);
    _put(publicationId, current.withLoved(!current.loved));
  }

  void _put(String publicationId, PostReaction reaction) {
    state = {...state, publicationId: reaction};
  }
}

final postReactionsProvider =
    NotifierProvider<PostReactionsNotifier, Map<String, PostReaction>>(
      PostReactionsNotifier.new,
    );
