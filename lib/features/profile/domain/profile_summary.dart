import '../../../core/constants/item_weights.dart';
import '../../../shared/domain/publication.dart';

/// Lo que el perfil muestra sobre una persona: sus contadores y su acumulado de
/// residuos evitados (HU20, criterios 3, 6 y 8).
///
/// Todo se deriva de la lista de publicaciones en lugar de leer el campo
/// `contadores` de `perfiles/{uid}`. Ese campo lleva `donaciones`,
/// `intercambios` y `voluntariados`, que no son lo que pide el perfil, y es una
/// copia que puede quedar desfasada. Calcular aquí significa que el feed, el
/// detalle y el perfil no pueden discrepar: leen las mismas publicaciones.
class ProfileSummary {
  const ProfileSummary({
    required this.publishedCount,
    required this.deliveriesRegistered,
    required this.deliveriesConfirmed,
    required this.avoidedKg,
  });

  const ProfileSummary.empty()
    : publishedCount = 0,
      deliveriesRegistered = 0,
      deliveriesConfirmed = 0,
      avoidedKg = 0;

  /// Publicaciones que cuentan como tales: ni anuladas ni retiradas.
  ///
  /// Una publicación anulada o retirada no llegó a tener un hogar, así que
  /// inflaría el contador de trabajo de la persona. Es el mismo criterio que
  /// aplica [publicPublications] (HU20, criterio 17).
  final int publishedCount;

  /// Entregas registradas: el bien llegó a destino, se haya confirmado o no
  /// (HU20, criterio 3). Suman los estados desde "entregada" en adelante.
  final int deliveriesRegistered;

  /// Entregas confirmadas por la otra parte (HU20, criterio 3 y 6). Es un
  /// subconjunto de [deliveriesRegistered], y la diferencia entre ambos es
  /// justo lo que queda pendiente de confirmar.
  final int deliveriesConfirmed;

  /// Kilogramos estimados de residuos evitados (HU20, criterio 8).
  final double avoidedKg;

  /// Entregas que aún no tienen confirmación de la otra parte. Es la
  /// diferencia entre lo registrado y lo confirmado, calculada aquí para que
  /// la pantalla no tenga que restar (HU20, criterio 6).
  int get pendingConfirmation => deliveriesRegistered - deliveriesConfirmed;

  /// Resumen a partir de [items]. [now] se recibe en vez de llamar a
  /// [DateTime.now] dentro para que sea determinista en pruebas.
  factory ProfileSummary.fromPublications(
    List<Publication> items, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();

    var published = 0;
    var registered = 0;
    var confirmed = 0;
    var kg = 0.0;

    for (final item in items) {
      // `effectiveStatus` porque "entregada" avanza sola a pendiente de
      // confirmación y luego a cerrada sin confirmación: el estado guardado en
      // Firestore se queda atrás y el perfil contaría de más.
      final status = item.effectiveStatus(clock);

      if (!isCountedAsPublished(status)) continue;
      published++;

      if (countsAsDelivery(status)) registered++;
      if (status == PublicationStatus.confirmed) confirmed++;
      // Solo el ciclo cerrado suma residuos evitados (HU18, criterio 5): las
      // publicadas, comprometidas, anuladas y retiradas no cuentan.
      if (countsAsAvoidedWaste(status)) {
        kg += ItemWeights.weightFor(item.category);
      }
    }

    return ProfileSummary(
      publishedCount: published,
      deliveriesRegistered: registered,
      deliveriesConfirmed: confirmed,
      avoidedKg: kg,
    );
  }

  /// Publicaciones que el perfil propio muestra tal cual, incluidas anuladas y
  /// retiradas: quien las retiró tiene derecho a verlas en su historial.
  ///
  /// Devuelve la lista sin ordenar porque la consulta ya llega ordenada por
  /// fecha de publicación.
  static List<Publication> ownPublications(List<Publication> items) => items;

  /// Publicaciones que el perfil público de otra persona puede ver (HU20,
  /// criterio 17): todas menos las anuladas y las retiradas, que el criterio 7
  /// de HU19 retira del listado, de la búsqueda y del detalle.
  static List<Publication> publicPublications(List<Publication> items) => items
      .where(
        (item) =>
            item.status != PublicationStatus.cancelled &&
            item.status != PublicationStatus.removed,
      )
      .toList(growable: false);

  static bool isCountedAsPublished(PublicationStatus status) =>
      status != PublicationStatus.cancelled &&
      status != PublicationStatus.removed;

  /// El bien ya está en manos de quien lo recibiría: cuenta como entrega
  /// registrada aunque nadie haya confirmado todavía.
  static bool countsAsDelivery(PublicationStatus status) => switch (status) {
    PublicationStatus.delivered ||
    PublicationStatus.pendingConfirmation ||
    PublicationStatus.closedWithoutConfirmation ||
    PublicationStatus.confirmed => true,
    _ => false,
  };

  static bool countsAsAvoidedWaste(PublicationStatus status) =>
      status == PublicationStatus.confirmed ||
      status == PublicationStatus.closedWithoutConfirmation;
}
