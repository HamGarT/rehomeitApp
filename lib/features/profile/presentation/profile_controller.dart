import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/domain/publication.dart';
import '../data/profile_repository.dart';
import '../domain/profile_summary.dart';

/// Publicaciones de [userId] en cualquier estado, de la más reciente a la más
/// antigua.
///
/// Se declara como familia por uid y no como un provider del usuario actual
/// porque el perfil público de otra persona necesita la misma consulta. Ambas
/// pantallas comparten el provider, así que el Firestore no se duplica al ir y
/// volver entre el detalle y el perfil.
final profilePublicationsProvider =
    StreamProvider.family<List<Publication>, String>((ref, userId) {
      return ref
          .watch(profileRepositoryProvider)
          .watchPublicationsByAuthor(userId);
    });

/// Publicaciones ajenas en las que [userId] participó como voluntario. No se
/// listan en el perfil; solo suman a los contadores y al impacto.
final volunteerPublicationsProvider =
    StreamProvider.family<List<Publication>, String>((ref, userId) {
      return ref
          .watch(profileRepositoryProvider)
          .watchPublicationsAsVolunteer(userId);
    });

/// Resumen de la actividad de [userId]: contadores y residuos evitados.
///
/// Sale de los mismos streams que la lista y los compromisos, así que los
/// números y las filas que los justifican nunca pueden contradecirse.
final profileSummaryProvider = Provider.family<ProfileSummary, String>((
  ref,
  userId,
) {
  final publications = ref.watch(profilePublicationsProvider(userId)).value;
  final volunteered = ref.watch(volunteerPublicationsProvider(userId)).value;
  // Sin datos todavía se devuelve el resumen vacío, no `null`: la pantalla
  // muestra ceros mientras carga y no necesita un estado aparte para eso.
  return ProfileSummary.fromPublications(
    publications ?? const [],
    volunteered: volunteered ?? const [],
  );
});
