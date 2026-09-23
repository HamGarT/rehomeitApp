# Historias de usuario

## HU01 – Registro de usuario

Como persona interesada en donar, intercambiar o apoyar como voluntario, quiero crear una cuenta en la aplicación, para acceder a sus funciones.

### Criterios de aceptación

1. El formulario de registro solicita nombre completo, correo electrónico y contraseña.
2. Todos los campos son obligatorios; si falta alguno, el sistema impide continuar e indica cuál falta.
3. El sistema valida que el correo tenga un formato válido antes de permitir el envío.
4. La contraseña debe tener como mínimo 8 caracteres.
5. Si el correo ya se encuentra registrado, el sistema muestra un mensaje indicándolo y no crea la cuenta.
6. El registro ofrece también la opción "Continuar con Google", que crea la cuenta a partir de los datos de la cuenta de Google sin solicitar contraseña.
7. Si el correo de la cuenta de Google ya existe en el sistema, se inicia sesión en la cuenta existente sin crear una duplicada.
8. Creada la cuenta, el sistema muestra un mensaje de confirmación e inicia la sesión del usuario.
9. El registro no solicita seleccionar un rol; toda cuenta nueva accede a las mismas funciones y puede donar, intercambiar o actuar como voluntaria según lo que realice dentro de la aplicación.
10. Las cuentas con permisos de organización o de administrador no se obtienen desde el registro; el equipo las habilita directamente en el backend.
11. La contraseña no se almacena en texto plano; su gestión queda a cargo del servicio de autenticación.
12. Si no hay conexión a internet, el sistema informa que el registro requiere conexión y no deja la operación en estado indeterminado.

---

## HU02 – Inicio de sesión

Como usuario registrado, quiero iniciar sesión con mis credenciales, para retomar mi actividad y acceder a mis publicaciones y entregas.

### Criterios de aceptación

1. La pantalla de inicio de sesión solicita correo electrónico y contraseña.
2. Ofrece también la opción "Continuar con Google" para acceder sin ingresar contraseña.
3. Si las credenciales son correctas, el sistema inicia la sesión y muestra la pantalla principal de la aplicación.
4. Si las credenciales son incorrectas, el sistema deniega el acceso y muestra un mensaje de error, sin precisar si el error está en el correo o en la contraseña.
5. La sesión permanece activa al cerrar y volver a abrir la aplicación, hasta que el usuario cierre sesión.
6. La aplicación permite cerrar sesión desde el perfil del usuario.
7. Un usuario sin sesión iniciada no puede acceder a publicar, intercambiar, registrar entregas ni consultar el recorrido de un bien.
8. Las funciones de administración no son accesibles para un usuario sin permisos de administrador, aunque intente acceder directamente a ellas.
9. Si no hay conexión a internet al intentar iniciar sesión, el sistema informa que la operación requiere conexión.

---

## HU03 – Publicar un bien

Como persona que tiene un bien que ya no utiliza, quiero publicarlo con sus fotografías y sus características, para que otras personas puedan conocerlo y solicitarlo.

### Criterios de aceptación

1. La publicación se completa en tres pasos: captura de fotografías, datos del bien y modalidad de entrega.
2. En el primer paso el usuario adjunta entre 1 y 4 fotografías del bien, tomadas con la cámara o seleccionadas de la galería.
3. El segundo paso presenta dos secciones: la ficha principal y los detalles sugeridos.
4. La ficha principal contiene cuatro campos obligatorios: título, categoría, estado del bien y descripción.
5. La sección de detalles sugeridos permite consignar características propias del bien que no aplican a todos por igual, como talla, marca, material o dimensiones.
6. La sección de detalles sugeridos es opcional en su totalidad; la publicación puede confirmarse sin ningún detalle.
7. Cada detalle está compuesto por un nombre de campo y su valor, y ambos son editables por el usuario.
8. La sección admite un máximo de 6 detalles, con independencia de si fueron generados automáticamente o agregados por el usuario.
9. Mediante la opción "Agregar detalle" el usuario puede incorporar detalles propios definiendo el nombre del campo y su valor, hasta alcanzar el máximo de 6.
10. La opción "Agregar detalle" se deshabilita al alcanzar los 6 detalles.
11. El usuario puede editar o eliminar cualquier detalle antes de confirmar la publicación, lo que vuelve a habilitar la opción de agregar.
12. El segundo paso incluye además el distrito de publicación, seleccionado de una lista con los distritos de la provincia de Cajamarca, y es obligatorio.
13. En el tercer paso el usuario selecciona la modalidad, entre donación e intercambio, y es obligatoria.
14. Si falta algún campo obligatorio, el sistema impide avanzar e indica cuál falta.
15. Todos los campos son editables por el usuario antes de confirmar, con independencia de que hayan sido completados automáticamente.
16. Confirmada la publicación, el bien queda en estado "Publicada" y visible para los demás usuarios.
17. La publicación registra automáticamente la fecha y el usuario que la creó.
18. El usuario puede retirar una publicación propia mientras no tenga un compromiso asociado, con lo que esta pasa al estado "Anulada".
19. La confirmación de la publicación requiere conexión a internet; si no hay conexión, la aplicación lo informa, conserva los datos y las fotografías ya ingresados, y permite confirmar al restablecerse la conexión.

---

## HU04 – Sugerencia automática de la ficha

Como persona que publica un bien, quiero que la aplicación complete automáticamente los datos de la ficha a partir de las fotografías, para no tener que escribirlos y publicar en menos tiempo.

### Criterios de aceptación

1. Al pasar del primer al segundo paso, la aplicación envía las fotografías adjuntadas al servicio de inteligencia artificial para su análisis.
2. El servicio devuelve una sugerencia para los cuatro campos de la ficha principal: título, categoría, estado del bien y descripción.
3. Los campos se presentan ya completados con la sugerencia recibida, y cada uno indica visualmente que su contenido fue generado automáticamente.
4. Todos los campos sugeridos son editables; el usuario puede aceptarlos, modificarlos o borrarlos.
5. Mientras se realiza el análisis, la aplicación muestra una pantalla de espera que informa que las fotografías se están analizando.
6. La sugerencia se devuelve en un tiempo máximo de 10 segundos, durante los cuales se mantiene la pantalla de espera.
7. Si el análisis falla, se agota el tiempo de espera o no hay conexión, la aplicación informa la situación y presenta los campos vacíos para su ingreso manual, sin interrumpir la publicación.
8. Si el servicio no reconoce el contenido de las fotografías, la aplicación lo informa y presenta los campos vacíos para su ingreso manual.
9. La categoría sugerida corresponde a una de las categorías previstas por la aplicación.
10. La sugerencia no se confirma automáticamente: la publicación solo se registra cuando el usuario la confirma de forma expresa.
11. Las credenciales de acceso al servicio de inteligencia artificial no residen en el código de la aplicación.

---

## HU05 – Campos de detalle según el tipo de bien

Como persona que publica un bien, quiero que la aplicación me proponga los campos de detalle que corresponden al tipo de bien, para describirlo mejor sin tener que decidir qué información agregar.

### Criterios de aceptación

1. A partir del análisis de las fotografías, el servicio de inteligencia artificial genera hasta 4 detalles en la sección de detalles sugeridos.
2. Cada detalle generado incluye tanto el nombre del campo como su valor.
3. Los nombres de los campos corresponden al tipo de bien identificado; por ejemplo, talla y marca para una prenda de vestir, o material y dimensiones para un mueble.
4. Los 4 detalles generados se presentan ya completados y cada uno indica visualmente que su contenido fue generado automáticamente.
5. Al generarse 4 detalles, la sección conserva 2 espacios disponibles para que el usuario agregue detalles propios hasta el máximo de 6.
6. Si el servicio identifica menos de 4 detalles pertinentes, genera solo los que correspondan y deja disponibles los espacios restantes.
7. Tanto el nombre como el valor de cada detalle generado son editables por el usuario, quien también puede eliminarlos.
8. Si el análisis falla, se agota el tiempo de espera o no hay conexión, la sección se presenta vacía y el usuario puede agregar hasta 6 detalles propios.
9. La sección permanece opcional: la publicación puede confirmarse sin detalles, aunque el servicio haya generado sugerencias.

---

## HU06 – Publicar como donación

Como persona que quiere donar un bien, quiero publicarlo bajo la modalidad de donación, para entregarlo yo mismo a quien lo necesite o para que un voluntario lo recoja y se lo lleve a una persona que lo necesita.

### Criterios de aceptación

1. Al seleccionar la modalidad de donación, la aplicación muestra una pregunta adicional para definir la forma de entrega, con dos opciones: que el propio donante entregue el bien, o que un voluntario lo recoja y lo traslade.
2. La forma de entrega es obligatoria; si no se selecciona, el sistema impide publicar.
3. Si el donante elige entregarlo él mismo, la publicación queda registrada bajo esa forma de entrega y el donante es quien registra posteriormente la entrega.
4. Si el donante elige que lo recoja un voluntario, la publicación queda disponible para que cualquier usuario asuma el compromiso de recogerla.
5. El sistema no habilita ningún campo de precio, monto ni contraprestación para las publicaciones bajo esta modalidad.
6. Las publicaciones en modalidad de donación se distinguen visualmente de las de intercambio en el listado y en el detalle.
7. La modalidad y la forma de entrega no pueden modificarse una vez que la publicación tiene un compromiso asociado.
8. Confirmada la publicación, el bien queda en estado "Publicada" en ambas formas de entrega.

---

## HU07 – Publicar como intercambio

Como persona que quiere intercambiar un bien, quiero publicarlo bajo la modalidad de intercambio, para acordar directamente con otro usuario un canje que nos convenga a ambos.

### Criterios de aceptación

1. Al seleccionar la modalidad de intercambio, la aplicación no solicita definir la forma de entrega, ya que esta se coordina directamente entre las partes.
2. La publicación queda en estado "Publicada" y disponible para que otros usuarios propongan un intercambio.
3. Otro usuario puede proponer un intercambio desde el detalle de la publicación, ofreciendo a cambio una publicación propia que se encuentre en modalidad de intercambio y en estado "Publicada".
4. El propietario de la publicación recibe la propuesta y puede aceptarla o rechazarla.
5. Aceptada una propuesta, la publicación pasa al estado "Comprometida" y queda vinculada al usuario proponente.
6. Rechazada una propuesta, la publicación permanece en estado "Publicada" y disponible para otras propuestas.
7. La coordinación de lugar, fecha y condiciones del intercambio se realiza mediante la mensajería interna, sin intervención de un voluntario.
8. El sistema no habilita ningún campo de precio ni monto para las publicaciones bajo esta modalidad.
9. Las publicaciones en modalidad de intercambio se distinguen visualmente de las de donación en el listado y en el detalle.
10. La modalidad no puede modificarse una vez que la publicación tiene una propuesta aceptada.
11. El sistema registra la fecha de la propuesta, la fecha de la respuesta y el estado de cada intercambio.
12. Aceptada una propuesta, ambas publicaciones, la solicitada y la ofrecida, pasan al estado "Comprometida".
13. El recorrido de una publicación en modalidad de intercambio es visible para cualquier usuario, mostrando únicamente los estados alcanzados y sus fechas, sin exponer el lugar ni las condiciones acordadas, que permanecen en la conversación privada entre las partes.
14. Concretado el intercambio, cada parte confirma por separado que recibió el bien acordado.
15. La publicación pasa al estado "Confirmada" únicamente cuando ambas partes han confirmado; mientras solo una lo haya hecho, permanece en estado "Entregada" y el recorrido indica qué confirmación falta.
16. El sistema registra la fecha y hora de cada confirmación por separado.
17. Al confirmar una parte, la otra recibe una notificación indicándole que debe confirmar para cerrar el ciclo.
18. Si la parte que falta no confirma dentro de las 48 horas siguientes a la confirmación de la otra, la publicación pasa al estado "Pendiente de confirmación", sin impedir que confirme posteriormente.
19. Si tampoco confirma dentro de las 72 horas siguientes, la publicación pasa al estado "Cerrada sin confirmación", dejando constancia de qué confirmación faltó.

---

## HU08 – Explorar y filtrar por distrito

Como usuario, quiero explorar las publicaciones y filtrarlas por distrito, para encontrar bienes que estén cerca de donde me puedo desplazar.

### Criterios de aceptación

1. La pantalla principal muestra las publicaciones disponibles en una cuadrícula, con su fotografía, título y distrito.
2. Cada publicación indica visualmente su modalidad, donación o intercambio.
3. Las publicaciones se ordenan de la más reciente a la más antigua.
4. Solo se muestran las publicaciones en estado "Publicada"; las comprometidas, entregadas o anuladas no aparecen en el listado, sin perjuicio de que sigan siendo consultables según lo previsto en HU14.
5. El listado incluye filtros rápidos por modalidad: todo, donación e intercambio.
6. El listado incluye un filtro por distrito, que permite seleccionar uno de los distritos de la provincia de Cajamarca.
7. Los filtros de modalidad y distrito pueden combinarse entre sí.
8. La aplicación permite buscar publicaciones por texto, contrastando el término ingresado con el título del bien.
9. Si ningún resultado coincide con los filtros o la búsqueda, la aplicación muestra un mensaje indicándolo, en lugar de una pantalla vacía.
10. Al seleccionar una publicación se abre su detalle, con las fotografías, la ficha principal, los detalles del bien, la modalidad de entrega y los datos del donante.
11. El detalle presenta las acciones que corresponden a la modalidad de la publicación.
12. Sin conexión, la aplicación muestra las publicaciones consultadas previamente e informa que el listado puede no estar actualizado.

---

## HU09 – Mensajería privada

Como usuario interesado en una publicación, quiero comunicarme con la otra parte dentro de la aplicación, para coordinar el recojo o el intercambio sin compartir mi número telefónico.

### Criterios de aceptación

1. Desde el detalle de una publicación, el usuario puede iniciar una conversación privada con su propietario.
2. La conversación queda asociada a la publicación que la originó y muestra su título, fotografía y modalidad en la parte superior.
3. Desde la conversación se puede acceder al detalle de la publicación vinculada.
4. La conversación es privada entre ambas partes; ningún otro usuario puede acceder a su contenido.
5. Cada mensaje registra su fecha y hora de envío, y estas se muestran junto al mensaje.
6. Los mensajes propios se distinguen visualmente de los de la otra parte.
7. La aplicación no expone el número telefónico ni el correo electrónico de los usuarios en ningún momento de la conversación.
8. La sección de mensajes reúne todas las conversaciones del usuario, indicando el bien asociado y el último mensaje recibido.
9. El usuario recibe una notificación cuando le llega un mensaje nuevo.
10. Al proponer un intercambio, si el usuario no cuenta con ninguna publicación propia en modalidad de intercambio y en estado "Publicada", la aplicación se lo informa y le ofrece publicar un bien.
11. Sin conexión, la aplicación muestra las conversaciones consultadas previamente; los mensajes escritos quedan pendientes y se envían al restablecerse la conexión.
12. En una publicación de donación, la conversación también permite la coordinación del recojo entre el donante y el voluntario que asumió el compromiso.

---

## HU10 – Asumir el recojo de un bien donado

Como usuario dispuesto a apoyar como voluntario, quiero asumir el compromiso de recoger un bien donado, para trasladarlo hasta una persona que lo necesite.

### Criterios de aceptación

1. En el detalle de una publicación en donación cuya forma de entrega sea mediante voluntario, la aplicación ofrece la opción de asumir el recojo.
2. Cualquier usuario registrado puede asumir el recojo, sin requerir una habilitación previa.
3. El propietario de la publicación no puede asumir el recojo de su propio bien.
4. Al asumir el recojo, la publicación pasa al estado "Comprometida" y queda vinculada al usuario que lo asumió.
5. Una publicación comprometida deja de aparecer en el listado de publicaciones disponibles y no admite que otro usuario asuma su recojo.
6. El donante recibe una notificación indicando que un usuario asumió el recojo de su bien.
7. Al asumir el recojo se habilita la conversación entre el donante y el voluntario para coordinar el lugar y la hora.
8. Mientras la publicación se mantenga en estado "Comprometida", el voluntario puede desistir del compromiso, con lo que la publicación regresa al estado "Publicada" y vuelve a estar disponible.
9. Mientras la publicación se mantenga en estado "Comprometida", el donante puede cancelar el compromiso si el voluntario no concreta el recojo, con lo que la publicación regresa al estado "Publicada".
10. Cancelado o desistido el compromiso, la otra parte recibe una notificación indicando que la publicación volvió a estar disponible.
11. El sistema registra la fecha y hora en que se asumió el compromiso, dato que forma parte del recorrido del bien.
12. El voluntario visualiza en su perfil los compromisos que tiene pendientes.
13. El donante puede retirar su publicación solo si no tiene un compromiso activo.

---

## HU11 – Confirmar la entrega del bien al voluntario

Como persona que donó un bien, quiero confirmar que ya se lo entregué al voluntario, para dejar registrado que el bien salió de mis manos y que el traslado está en curso.

### Criterios de aceptación

1. Mientras la publicación se encuentre en estado "Comprometida", el donante dispone de la opción para confirmar que entregó el bien al voluntario.
2. Solo el donante puede realizar esta confirmación; el voluntario no puede hacerlo por él.
3. Confirmada la entrega, la publicación pasa al estado "Recogida".
4. A partir del estado "Recogida", ni el donante ni el voluntario pueden cancelar el compromiso ni devolver la publicación a estado disponible.
5. El voluntario recibe una notificación indicando que el donante confirmó la entrega del bien.
6. Alcanzado el estado "Recogida", se habilita para el voluntario la opción de registrar la entrega al destinatario final.
7. El sistema registra la fecha y hora de la confirmación, dato que forma parte del recorrido del bien.
8. Antes de confirmar, la aplicación advierte al donante que la operación no puede revertirse.
9. La publicación en estado "Recogida" se muestra al donante como una entrega en curso.
10. Si no hay conexión al confirmar, la operación se guarda localmente y se sincroniza al restablecerse la conexión.

---

## HU12 – Registrar la entrega al destinatario

Como voluntario que entregó un bien, quiero registrar la entrega con su evidencia y los datos mínimos del destinatario, para dejar constancia de que el bien llegó a su destino.

### Criterios de aceptación

1. La opción de registrar la entrega se habilita únicamente cuando la publicación se encuentra en estado "Recogida".
2. El formulario solicita una fotografía de la evidencia de la entrega, las iniciales del destinatario y su distrito.
3. La fotografía de evidencia es obligatoria y se captura desde la cámara de la aplicación.
4. El distrito se selecciona de una lista con los distritos de la provincia de Cajamarca.
5. El formulario expone únicamente los campos de iniciales y distrito; no dispone de campos para nombre completo, documento de identidad, dirección ni número telefónico del destinatario.
6. La aplicación informa al voluntario que solo se registran las iniciales y el distrito, y que no se solicitan datos que permitan identificar a la persona que recibe el bien.
7. El sistema registra automáticamente la fecha y hora de la entrega, sin que el voluntario pueda modificarlas.
8. Registrada la entrega, la publicación pasa al estado "Entregada".
9. El donante recibe una notificación indicando que la entrega fue registrada y que debe confirmar el cierre.
10. En la ruta de entrega directa, el donante registra la entrega con los mismos campos, y la publicación pasa directamente al estado "Confirmada".
11. Si falta algún campo obligatorio, el sistema impide registrar la entrega e indica cuál falta.
12. El registro de la entrega requiere conexión a internet; si no hay conexión, la aplicación lo informa, conserva los datos ingresados y la fotografía capturada, y permite registrar al restablecerse la conexión.
13. Antes de capturar la evidencia, la aplicación advierte al voluntario que la fotografía no debe mostrar el rostro del destinatario ni elementos que permitan identificarlo o ubicar su domicilio, dado que el recorrido del bien es de consulta pública.

---

## HU13 – Confirmar el cierre de la entrega

Como persona que donó un bien, quiero revisar la evidencia de la entrega y confirmar su cierre, para dar por concluida la operación sabiendo que llegó a su destino.

### Criterios de aceptación

1. Cuando la publicación se encuentra en estado "Entregada", el donante puede acceder al detalle de la entrega registrada.
2. El detalle muestra la fotografía de evidencia, la fecha y hora de la entrega, las iniciales y el distrito del destinatario, y el voluntario que la realizó.
3. Solo el donante puede confirmar el cierre; el voluntario no puede hacerlo por él.
4. Confirmado el cierre, la publicación pasa al estado "Confirmada" y el ciclo queda cerrado.
5. El voluntario recibe una notificación indicando que el donante confirmó el cierre.
6. El sistema registra la fecha y hora de la confirmación, dato que forma parte del recorrido del bien.
7. Si el donante no confirma dentro del plazo establecido, la publicación pasa al estado "Pendiente de confirmación", sin impedir que confirme posteriormente.
8. Si tampoco confirma dentro del segundo plazo, la publicación pasa al estado "Cerrada sin confirmación" y el recorrido del bien deja constancia de que el cierre no fue confirmado por el donante.
9. Una publicación en estado "Pendiente de confirmación" puede ser confirmada por el donante en cualquier momento, con lo que pasa al estado "Confirmada".
10. El perfil del donante distingue las entregas confirmadas de las pendientes de confirmación.
11. Confirmado el cierre, la operación queda disponible para consulta en el recorrido del bien.
12. El primer plazo para la confirmación del donante es de 48 horas contadas desde el registro de la entrega.
13. El segundo plazo es de 72 horas contadas desde que la publicación pasa a estado "Pendiente de confirmación".

---

## HU14 – Consultar el recorrido del bien

Como persona que donó un bien, quiero consultar el recorrido completo de mi donación, para saber en qué etapa se encuentra y quién la recibió.

### Criterios de aceptación

1. Desde el detalle de una publicación propia, el donante puede acceder al recorrido del bien.
2. El recorrido presenta en orden cronológico los hitos alcanzados. En una publicación de donación: publicación, compromiso del voluntario, recojo confirmado por el donante, entrega registrada y cierre confirmado. En una publicación de intercambio: publicación, propuesta aceptada e intercambio concretado.
3. Cada hito muestra su fecha, su hora y el usuario que lo generó.
4. El hito de entrega incluye la fotografía de evidencia y las iniciales y el distrito del destinatario.
5. El recorrido indica el estado actual de la publicación y distingue los hitos alcanzados de los pendientes.
6. Cuando el ciclo se cierra, el recorrido lo señala como completo y verificable.
7. Si la publicación quedó en estado "Cerrada sin confirmación", el recorrido lo indica expresamente.
8. En la ruta de entrega directa, el recorrido muestra únicamente los hitos que corresponden: publicación y entrega registrada por el donante.
9. El recorrido informa que del destinatario solo se conservan sus iniciales y su distrito.
10. El recorrido del bien es visible para cualquier usuario de la aplicación, no solo para el donante y el voluntario que participaron en la operación.
11. Cualquier usuario accede al recorrido desde el perfil público de quien publicó el bien, donde se listan sus publicaciones con su estado, incluidas las que ya no figuran en el listado principal.
12. Al abrir desde esa consulta una publicación cuyo ciclo ya se cerró, se muestran su ficha completa y su recorrido, sin las acciones propias de una publicación disponible.
13. Las publicaciones anuladas por su autor y las retiradas por el administrador no forman parte de la consulta pública.
14. En una publicación de intercambio, la consulta pública se limita a los estados alcanzados y sus fechas, conforme a HU07-13.
15. La aplicación permite compartir un comprobante del recorrido con la información de los hitos, sin exponer datos que identifiquen al destinatario.
16. Sin conexión, la aplicación muestra el recorrido consultado previamente e informa que puede no estar actualizado.

---

## HU15 – Crear y administrar campañas de acopio

Como organización que atiende una necesidad puntual, quiero publicar una campaña indicando qué se necesita y hasta cuándo, para que las personas puedan aportar bienes de forma organizada.

### Criterios de aceptación

1. Solo un usuario habilitado como organización puede crear campañas, y únicamente puede administrar las campañas que él mismo creó.
2. El formulario de creación solicita el título de la campaña, la organización responsable, una descripción de la situación, la fecha de cierre y el distrito de alcance.
3. La campaña permite adjuntar una imagen representativa.
4. La campaña registra las necesidades específicas que requiere, cada una con su nombre y la cantidad requerida.
5. Una campaña admite varias necesidades; al menos una es obligatoria.
6. La campaña registra un punto de acopio con su nombre, dirección y horario de atención.
7. Creada la campaña, esta queda en estado "Activa" y visible en el listado de campañas.
8. El listado de campañas distingue las activas de las cerradas.
9. Cada campaña del listado muestra su título, la organización responsable, los días restantes hasta el cierre, las necesidades requeridas y su porcentaje de avance.
10. El porcentaje de avance se calcula sobre el total de unidades requeridas frente al total de unidades aportadas.
11. La organización puede editar los datos de una campaña propia mientras esté activa, y agregar o modificar sus necesidades.
12. Al llegar la fecha de cierre, la campaña pasa automáticamente al estado "Cerrada" y deja de admitir aportes.
13. La organización responsable puede cerrar anticipadamente una campaña propia, y el administrador puede cerrar anticipadamente cualquier campaña.
14. El detalle de la campaña informa que al cerrarse se publicará un resumen con lo recibido y su destino.
15. La habilitación de una cuenta como organización la realiza el equipo desde el backend, previa coordinación con la entidad solicitante.
16. Un usuario no habilitado como organización no accede a la creación de campañas ni a la confirmación de aportes, aunque intente acceder directamente a esas funciones.
17. Las necesidades que ya alcanzaron la cantidad requerida se muestran señaladas como cubiertas, pero permanecen disponibles para recibir aportes adicionales.

---

## HU16 – Aportar a una campaña

Como persona que quiere apoyar una situación puntual, quiero aportar bienes a una campaña activa, para contribuir con lo que la organización realmente necesita.

### Criterios de aceptación

1. El detalle de una campaña activa muestra la descripción de la situación, las necesidades requeridas con su avance, el punto de acopio y los días restantes hasta el cierre.
2. Desde el detalle de una campaña activa, el usuario puede registrar su intención de aportar.
3. El aporte se realiza sobre las necesidades declaradas por la campaña; el usuario selecciona cuál de ellas atiende y la cantidad que aportará.
4. El usuario no puede aportar bienes ajenos a las necesidades declaradas.
5. Registrada la intención, el aporte queda en estado "Pendiente" y se muestra al usuario junto con los datos del punto de acopio y su horario.
6. La organización responsable de la campaña visualiza los aportes pendientes de su campaña.
7. Al recibir físicamente el bien en el punto de acopio, la organización confirma el aporte, que pasa al estado "Confirmado".
8. Solo la organización responsable de la campaña puede confirmar sus aportes.
9. Únicamente los aportes confirmados se contabilizan en el avance de la necesidad y de la campaña.
10. La organización puede rechazar un aporte que no llegó o que no corresponde a lo declarado, indicando el motivo.
11. El usuario recibe una notificación cuando su aporte es confirmado o rechazado.
12. El avance de cada necesidad se actualiza automáticamente al confirmarse un aporte y puede superar la cantidad requerida.
13. Cuando una necesidad supera la cantidad requerida, el detalle de la campaña muestra el total aportado junto a la cantidad solicitada, señalando visualmente que la necesidad fue cubierta.
14. Una campaña cerrada no admite nuevos aportes ni confirmaciones.
15. El usuario consulta sus aportes y su estado desde la sección correspondiente de su perfil.
16. Si no hay conexión al registrar la intención de aporte, la operación se guarda localmente y se sincroniza al restablecerse la conexión.

---

## HU17 – Resumen de cierre de campaña

Como persona que aportó a una campaña, quiero conocer el resumen de lo recibido y su destino al cerrarse, para saber en qué terminó lo que entregué.

### Criterios de aceptación

1. Al cerrarse una campaña, el sistema genera automáticamente su resumen de cierre.
2. El resumen consolida, por cada necesidad declarada, la cantidad requerida y la cantidad efectivamente aportada.
3. El resumen incluye el total de aportes confirmados y el número de personas que aportaron.
4. El resumen indica los distritos atendidos por la campaña.
5. El resumen se calcula únicamente sobre los aportes confirmados por la organización.
6. La organización responsable puede incorporar al resumen una descripción del destino que se dio a lo recibido.
7. El resumen es de consulta pública y queda accesible desde el detalle de la campaña cerrada.
8. Las personas que aportaron reciben una notificación cuando el resumen queda publicado.
9. El listado de campañas permite consultar las campañas cerradas y acceder a sus resúmenes.
10. El resumen no expone datos que permitan identificar a las personas destinatarias de los bienes.
11. Publicado el resumen, sus cifras no pueden modificarse.
12. El resumen se publica automáticamente al cerrarse la campaña, con independencia de que la organización haya incorporado o no la descripción del destino, la cual puede agregarse posteriormente.

---

## HU18 – Indicador de impacto ambiental

Como usuario que dona o intercambia bienes, quiero ver una estimación de los residuos que evité, para conocer el efecto de lo que hago.

### Criterios de aceptación

1. El sistema mantiene un peso referencial por cada categoría de bien, empleado para estimar el volumen de residuos evitado.
2. Al completarse una operación, el sistema calcula la estimación correspondiente al bien redistribuido.
3. La estimación se muestra en el detalle de la operación, expresada en kilogramos.
4. El perfil del usuario muestra el acumulado de residuos evitados por todas sus operaciones completadas.
5. Solo se contabilizan las operaciones cuyo ciclo se cerró; las publicadas, comprometidas o anuladas no suman al indicador.
6. La aplicación señala expresamente que se trata de una estimación referencial basada en el peso promedio de la categoría, y no de una medición del bien.
7. Los pesos referenciales por categoría quedan documentados con su fuente.
8. El indicador se recalcula automáticamente al completarse cada nueva operación.

---

## HU19 – Reportar una publicación inapropiada

Como usuario que encuentra una publicación con contenido indebido, quiero reportarla desde la aplicación, para que el equipo la revise y la retire si corresponde.

### Criterios de aceptación

1. Desde el detalle de una publicación que no sea propia, el usuario puede reportarla.
2. El formulario de reporte solicita un motivo seleccionado de una lista y permite agregar un comentario opcional.
3. Los motivos previstos son: contenido inapropiado, bien prohibido o ilegal, publicación engañosa, solicitud de dinero y otro.
4. Un mismo usuario no puede reportar más de una vez la misma publicación.
5. Registrado el reporte, la aplicación confirma su recepción e informa que será revisado por el equipo.
6. El reporte queda en estado "Pendiente" y registra la publicación reportada, el usuario que reportó, el motivo y la fecha.
7. La publicación permanece visible mientras su reporte no haya sido resuelto.
8. Solo un usuario con permisos de administrador accede al listado de reportes pendientes.
9. El administrador es quien determina si la publicación es inapropiada.
10. Si el administrador la resuelve como inapropiada, la publicación pasa al estado "Retirada" y deja de aparecer en el listado, en la búsqueda y en el detalle.
11. Si el administrador la resuelve como apropiada, el reporte pasa al estado "Desestimado" y la publicación permanece disponible.
12. El reporte registra la fecha de la resolución y el administrador que la realizó.
13. El autor de la publicación recibe una notificación cuando su publicación es retirada, indicando el motivo.
14. El usuario que reportó recibe una notificación cuando su reporte es resuelto.
15. Una publicación retirada no puede volver a publicarse ni editarse.
16. Si la publicación retirada tenía un compromiso o una propuesta de intercambio activa, esta queda cancelada y la otra parte recibe una notificación.

---

## HU20 – Perfil de usuario

Como usuario de la aplicación, quiero un perfil donde vea mi actividad y donde los demás vean lo que he donado, para llevar el control de mis operaciones y para que mi aporte quede a la vista sin exponer mis datos personales.

### Criterios de aceptación

1. El usuario accede a su perfil desde la navegación principal de la aplicación.
2. El perfil propio muestra el nombre completo del usuario, su distrito y la fecha en que se incorporó.
3. El perfil propio muestra los contadores de publicaciones realizadas, entregas registradas y entregas confirmadas.
4. El perfil propio lista las publicaciones del usuario con su estado, con acceso al detalle y al recorrido de cada una.
5. El perfil propio muestra los compromisos que el usuario tiene pendientes como voluntario.
6. El perfil propio distingue las entregas confirmadas de las pendientes de confirmación.
7. El perfil propio da acceso a los aportes a campañas del usuario con su estado.
8. El perfil propio muestra el acumulado estimado de residuos evitados por sus operaciones completadas.
9. El usuario puede editar su nombre, su distrito y su fotografía desde el perfil propio.
10. El correo electrónico no es editable desde el perfil.
11. El perfil propio permite cerrar sesión.
12. Cualquier usuario accede al perfil público de otro desde el detalle de una publicación o desde el recorrido de un bien.
13. El perfil público identifica al usuario con su nombre de pila y la inicial de su primer apellido, no con su nombre completo.
14. La aplicación emplea ese mismo formato abreviado en todo lugar donde identifica a un usuario ante terceros, incluidos el detalle de la publicación, el recorrido del bien y las conversaciones.
15. El perfil público muestra el distrito del usuario y la fecha en que se incorporó.
16. El perfil público no expone el correo electrónico ni el número telefónico del usuario.
17. El perfil público lista las publicaciones del usuario con su estado y el acceso a su recorrido, excluidas las anuladas y las retiradas.
18. El perfil público muestra los contadores de publicaciones realizadas y entregas confirmadas.
19. Los aportes a campañas y los compromisos pendientes se muestran únicamente en el perfil propio.
20. El perfil público no ofrece iniciar una conversación; esta se inicia desde el detalle de una publicación.
