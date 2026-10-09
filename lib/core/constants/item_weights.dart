import 'item_categories.dart';

/// Peso referencial por categoría de bien, en kilogramos (HU18, criterio 1).
///
/// Son órdenes de magnitud, no mediciones. El objetivo es que la persona vea una
/// cifra con sentido ("evitaste unos 8 kg de residuos"), no que la aplicación
/// haga un balance de residuos. Por eso el indicador se muestra siempre
/// acompañado del aviso del criterio 6.
///
/// La tabla cubre todas las entradas de [ItemCategories.all]. Si se añade una
/// categoría allí, [weightFor] cae a [fallbackKg] en vez de fallar, para que el
/// cálculo del indicador nunca se rompa por una categoría nueva.
///
/// ## Fuente de los valores (HU18, criterio 7)
///
/// La tabla y su fuente están también en D15 de `docs/decisiones-tecnicas.md`;
/// si cambia un peso aquí, cambia allá. Cada valor redondea el rango habitual que dan las caracterizaciones de
/// composición de residuos sólidos domésticos publicadas por organismos de
/// gestión de residuos (EPA WARM en Estados Unidos y los Global Waste
/// Management Outlook del PNUE) al separar ropa, mobiliario y electrodomésticos
/// dentro del flujo de reutilización. Esas caracterizaciones trabajan con
/// rangos, no con un peso único por producto, así que aquí se toma un valor
/// representativo por categoría en lugar del extremo del rango.
///
/// La tabla vive en el código y no en Firestore a propósito: es una constante
/// del dominio, auditable junto al resto de la lógica y sin coste de lectura.
abstract final class ItemWeights {
  /// Peso con el que se cuenta una categoría que no está en la tabla. Vale lo
  /// que pesa un objeto doméstico típico, para que el acumulado no salte de
  /// golpe si mañana aparece una categoría nueva.
  static const double fallbackKg = 1.0;

  /// Peso referencial en kg por categoría, con las etiquetas exactas de
  /// [ItemCategories.all].
  static const Map<String, double> byCategory = <String, double>{
    // Lotes de ropa, no una sola prenda: la categoría es "Ropa infantil" y
    // quien publica suele donar todo lo que ya no le cabe.
    'Ropa infantil': 0.6,
    'Ropa de adulto': 1.8,
    'Calzado': 0.9,
    'Muebles': 30,
    'Electrodomésticos': 18,
    'Enseres de cocina': 2.5,
    'Ropa de cama y abrigo': 3.5,
    'Libros y útiles escolares': 3,
    'Juguetes': 1.2,
    'Tecnología': 2.5,
  };

  /// Peso referencial de [category], con [fallbackKg] como red de seguridad.
  static double weightFor(String category) =>
      byCategory[category.trim()] ?? fallbackKg;
}
