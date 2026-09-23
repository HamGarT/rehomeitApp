# Decisiones técnicas

Decisiones que condicionan la implementación y que no se deducen leyendo las historias de usuario. Cada una registra el problema que resuelve y lo que implica asumirla.

Última actualización: 23 de setiembre de 2026.

---

## D01 – Las notificaciones son internas a la aplicación

**Problema.** Once criterios indican que un usuario "recibe una notificación" (HU07-17, HU09-09, HU10-06, HU10-10, HU11-05, HU12-09, HU13-05, HU16-11, HU17-08, HU19-13, HU19-14). Enviar una notificación push a otro usuario mediante Firebase Cloud Messaging requiere una clave de servidor. Incluirla en la aplicación la deja al alcance de cualquiera que inspeccione el paquete, lo que permitiría emitir notificaciones falsas a todos los usuarios. No existe forma segura de enviarlas desde el cliente.

**Decisión.** Las notificaciones se implementan dentro de la aplicación. Quien ejecuta la acción escribe un documento en la colección `notificaciones` dirigido al destinatario, y este lo recibe en tiempo real mientras usa la aplicación.

**Consecuencias.** No se requiere plan de pago ni componentes de servidor. El usuario se entera al abrir la aplicación, no con el teléfono bloqueado. Si más adelante se incorporan notificaciones push, se apoyan sobre la misma colección sin rehacer lo existente.

---

## D02 – Los estados por vencimiento de plazo se derivan al consultar

**Problema.** Varias historias describen cambios de estado que ocurren por el paso del tiempo: los plazos de 48 y 72 horas para confirmar (HU13-12, HU13-13, HU07-18, HU07-19), el cierre automático de una campaña en su fecha (HU15-12) y la publicación de su resumen (HU17-01). Firestore es una base de datos pasiva: ningún proceso despierta a las 48 horas a modificar documentos. Programar tareas requiere Cloud Functions y, con ello, plan de pago.

**Decisión.** Ningún proceso programado modifica estados. El documento conserva la fecha del hito alcanzado y el estado vigente se obtiene comparando esa fecha con la hora actual, tanto al mostrarlo como en las reglas de seguridad que autorizan o bloquean cada escritura.

**Consecuencias.** El estado mostrado siempre es correcto, incluso si nadie abrió la aplicación durante días, y se evita la inconsistencia típica de una tarea programada que falla. A cambio, la lógica de vencimiento vive en un único lugar del código del que dependen cuatro historias, por lo que debe estar cubierto por pruebas.

---

## D03 – Las operaciones con fotografía requieren conexión

**Problema.** HU03-19 y HU12-12 planteaban originalmente que la publicación y el registro de entrega se guardaran localmente y se enviaran solos al recuperar la conexión. Firestore sincroniza sus datos sin conexión de forma automática, pero Cloud Storage no: una subida de archivo sin red falla y no existe cola de reintento.

**Decisión.** Las operaciones que incluyen fotografías exigen conexión. La aplicación lo informa, conserva los datos ingresados y las fotografías capturadas, y permite completar la operación al restablecerse la red.

**Consecuencias.** No se pierde el trabajo del usuario, solo se pospone el envío bajo su control, y se evita programar y mantener una cola de subida propia. La consulta sin conexión se mantiene intacta (HU08-12, HU09-11, HU14-16), igual que las operaciones sin fotografía que sí admiten envío diferido (HU11-10, HU16-16).

---

## D04 – La búsqueda por texto se resuelve en el cliente

**Problema.** HU08-08 pide buscar contrastando el término ingresado con el título del bien. Firestore no dispone de un operador que busque texto contenido dentro de un campo: solo permite igualdad y rangos. Buscar "casaca" no encontraría "Casaca de niño abrigada".

**Decisión.** La consulta a Firestore aplica los filtros de estado, modalidad y distrito. El filtro por texto se aplica en memoria sobre ese conjunto ya reducido.

**Consecuencias.** La búsqueda funciona con cualquier fragmento del título y no agrega costo ni servicios externos. Es adecuada para el volumen esperado del proyecto. Si el catálogo creciera a varios miles de publicaciones activas por distrito, habría que migrar a un servicio de búsqueda dedicado.

---

## D05 – HU04 y HU05 se resuelven con una única llamada al servicio de IA

**Problema.** Ambas historias analizan exactamente las mismas fotografías: HU04 pide título, categoría, estado y descripción; HU05 pide hasta cuatro detalles con su nombre y su valor. Resolverlas por separado implica enviar las imágenes dos veces, pagar el doble de tokens de entrada y sumar dos latencias, contra un presupuesto total de 10 segundos (HU04-06).

**Decisión.** Una sola llamada a Gemini devuelve la ficha principal y los detalles en una respuesta estructurada. Las imágenes se reducen de tamaño antes de enviarse.

**Consecuencias.** La separación en dos historias responde a dos necesidades distintas del usuario, no a dos llamadas. Al pedir una respuesta con estructura definida, la categoría llega garantizada dentro de la lista prevista por la aplicación (HU04-09) en lugar de tener que validarse sobre texto libre. Si una de las dos historias cambia, la llamada debe revisarse en conjunto.

---

## D06 – Los roles son tres, acumulativos, en un solo campo

**Problema.** El wireframe del perfil muestra los distintivos "Voluntaria" y "Donante" sobre la misma persona, lo que sugiere roles simultáneos. HU01-09 establece en cambio que toda cuenta nueva accede a las mismas funciones.

**Decisión.** Existen tres niveles acumulativos: usuario, organización y administrador. El usuario puede donar, intercambiar y actuar como voluntario. La organización suma la creación y administración de campañas. El administrador accede a todas las funciones, incluida la moderación de publicaciones reportadas. El nivel se guarda en un único campo del documento del usuario. "Donante" y "voluntaria" no son roles: son actividades que se derivan de lo que la persona hizo.

**Consecuencias.** Las reglas de seguridad deben impedir que un usuario modifique su propio nivel. Sin esa restricción, cualquiera puede ascenderse a administrador escribiendo directamente contra Firestore, sin pasar por la aplicación. Organización y administrador se habilitan manualmente desde el backend (HU01-10, HU15-15).

---

## D07 – Los usuarios se identifican ante terceros con su nombre abreviado

**Problema.** El perfil público sostiene la consulta del recorrido de los bienes (HU14-11), de modo que cualquiera puede llegar a él. El diseño mostraba el nombre completo en el perfil y un formato abreviado en el detalle de la publicación, dos criterios distintos para el mismo dato. Resultaba incoherente proteger la identidad del destinatario hasta sus iniciales (HU12-05) y exponer en cambio el nombre completo de quien dona.

**Decisión.** Ante terceros, todo usuario se identifica con su nombre de pila y la inicial de su primer apellido. El nombre completo solo se muestra en el perfil propio.

**Consecuencias.** Un mismo criterio de identificación en el detalle de la publicación, el recorrido, las conversaciones y el perfil público. Las reglas de seguridad de Firestore autorizan o deniegan documentos completos y no permiten ocultar campos concretos, de modo que no basta con guardar el nombre completo y no mostrarlo: viajaría igual al cliente. Los datos del usuario se reparten por eso en dos documentos:

| Colección | Contiene | Quién puede leerla |
|-----------|----------|--------------------|
| `usuarios/{uid}` | Nombre completo, correo y rol | Solo el propio usuario |
| `perfiles/{uid}` | Nombre abreviado, distrito, fecha de ingreso y contadores | Cualquier usuario |

El rol permanece en el documento privado y las reglas pueden consultarlo igual, porque se evalúan del lado del servidor sin estar sujetas a los permisos de lectura del cliente. Al crearse la cuenta, ambos documentos se escriben en una sola operación para que no quede una cuenta sin perfil público.

---

## D08 – El avance de las campañas se lleva en un mapa de contadores

**Problema.** HU16-12 establece que el avance de cada necesidad se actualiza al confirmarse un aporte. Firestore ofrece una operación de incremento atómica, pero no funciona sobre elementos de un arreglo: para modificar una necesidad habría que leer el arreglo completo, cambiarlo en el cliente y reescribirlo. Si dos aportes se confirman a la vez, la segunda escritura pisa a la primera y un aporte desaparece del contador.

**Decisión.** El arreglo de necesidades conserva su definición (nombre, cantidad requerida, unidad). El avance se lleva en un campo aparte del documento de la campaña, con forma de mapa, donde cada necesidad tiene su propio contador. Ese contador se incrementa de forma atómica al confirmarse un aporte.

**Consecuencias.** Ningún aporte se pierde, cada campaña se lee en un solo documento y la pantalla de campañas no multiplica sus lecturas. Cada necesidad requiere un identificador estable que no cambie al editarse la campaña (HU15-11). La colección `aportes` sigue siendo el registro que respalda cada incremento y permite recalcular el avance si fuera necesario.

---

## D09 – El estado de la aplicación se gestiona con Riverpod

**Problema.** Firestore entrega los datos como flujos que emiten cada vez que algo cambia en la nube, y cada pantalla que los consume tiene que contemplar tres situaciones: que el dato esté cargando, que la consulta falle y que el dato haya llegado. Omitir el caso de error rompe la aplicación justamente sin conexión, que es un escenario previsto en HU08-12, HU09-11 y HU14-16.

**Decisión.** Se usa Riverpod como gestor de estado.

**Consecuencias.** Los tres estados de un dato remoto se representan en un solo objeto y el compilador obliga a cubrirlos, de modo que el caso de error no puede omitirse por descuido. El equipo asume una curva de aprendizaje de conceptos propios de la herramienta. Riverpod se incorpora como dependencia del proyecto.

---

## D10 – El código se organiza por funcionalidad

**Problema.** Organizar el código por capas (todos los modelos juntos, todos los repositorios juntos) hace que tres personas trabajando en historias distintas editen los mismos archivos al mismo tiempo, lo que genera conflictos constantes al integrar el trabajo.

**Decisión.** El código se organiza por funcionalidad. Cada carpeta de `lib/features/` contiene sus tres capas: `data`, `domain` y `presentation`. Lo transversal vive en `lib/core/` (constantes, errores, utilidades), `lib/shared/` (componentes reutilizables) y `lib/app/` (widget raíz, rutas y tema).

| Carpeta | Historias |
|---------|-----------|
| `auth` | HU01, HU02 |
| `explore` | HU08 |
| `publishing` | HU03, HU04, HU05, HU06 |
| `exchange` | HU07 |
| `delivery` | HU10, HU11, HU12, HU13, HU14 |
| `campaigns` | HU15, HU16, HU17 |
| `messaging` | HU09 |
| `profile` | HU18, HU20 |
| `moderation` | HU19 |
| `notifications` | Transversal, según D01 |

**Consecuencias.** Cada integrante trabaja dentro de su propia carpeta y los conflictos al integrar se reducen al mínimo. A cambio se acepta cierta duplicación entre funcionalidades: cuando algo se necesita en dos o más, se promueve a `core` o a `shared` en lugar de referenciarlo de una carpeta a otra.

---

## D11 – El equipo trabaja sobre Flutter 3.47.5

**Problema.** El proyecto se generó con una plantilla que exige Dart `^3.13.3` y trae AGP 9.1 y Gradle 9.3. Una versión de Flutter anterior no puede siquiera resolver las dependencias, y versiones distintas entre los integrantes producen errores de compilación difíciles de atribuir.

**Decisión.** Los tres integrantes usan Flutter 3.47.5 del canal estable, que incorpora Dart 3.13.4. La versión queda declarada como restricción exacta en el bloque `environment` de `pubspec.yaml`.

**Consecuencias.** Quien no esté en esa versión recibe un error explícito al ejecutar `flutter pub get`, con el número de versión requerido, en lugar de descubrir el problema al compilar. Subir de versión pasa a ser una decisión deliberada del equipo: se edita esa línea y todos actualizan a la vez.

---

## D13 – Dos superficies de color: marca y contenido

**Problema.** Los paneles de inicio y el acceso usaban el amarillo `#F3CA20`, tipografías propias y la mascota, mientras el resto de la aplicación seguía la paleta verde original con la fuente por defecto. Eran dos identidades. Extender el amarillo pleno a toda la aplicación compite con las fotografías de los bienes, deslumbra sobre tarjetas blancas y cansa en sesiones largas.

**Decisión.** La paleta se unifica alrededor de los paneles, con dos superficies. La de marca, amarillo pleno, se reserva a momentos con carga emocional: onboarding, acceso, carga, análisis de fotografías, estados vacíos y el éxito al publicar; ahí aparece el cuy. La de contenido, crema `#FFF6D9`, sostiene explorar, detalle, formulario y perfil. El marrón del cuy es el color primario, el amarillo el acento y el verde queda para donación y éxito. HostGrotesk es la fuente de toda la aplicación y FreckleFace solo de los titulares de marca. Una única transición entre pantallas, fundido con leve ascenso, y un único diálogo (`AppDialog`), chip (`AppChip`) y hoja de selección (`showChoiceSheet`) en `shared/widgets`.

**Consecuencias.** Los colores entran por los tokens de `AppColors`, de modo que un ajuste de paleta no toca pantallas. Ningún texto va sobre amarillo salvo en marrón oscuro. La mascota no decora: si aparece en más lugares, pierde el efecto. Los assets del cuy se recortaron de las ilustraciones del onboarding y viven en `assets/images/mascot_*.webp`.

---

## D12 – El acceso a la IA se protege con App Check

**Problema.** HU04-11 exige que las credenciales del servicio de IA no residan en la aplicación, lo que Firebase AI Logic resuelve por sí mismo. Pero cualquiera que extraiga la configuración del paquete podría invocar el servicio desde fuera de la aplicación y consumir la cuota, que se cobra al proyecto.

**Decisión.** App Check queda en modo obligatorio para AI Logic. En release la aplicación se acredita con Play Integrity, que valida la firma registrada en la consola. En compilaciones de depuración se usa el proveedor de depuración: cada instalación genera un token que un integrante autoriza una sola vez en la consola. La elección la hace `kDebugMode` al arrancar, sin configuración adicional por máquina.

**Consecuencias.** Firestore y Authentication permanecen en modo supervisión, así una falla de App Check nunca deja a un usuario sin sesión ni sin datos; solo la IA queda cerrada. Cada integrante debe registrar su token de depuración antes de probar la sugerencia automática, y al publicar en Play Store hay que registrar la huella SHA-256 de la firma de release.
