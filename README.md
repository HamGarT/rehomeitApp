# ReHomeIt

Aplicación Flutter sobre Firebase para donar, intercambiar y reutilizar bienes en Cajamarca. Las historias de usuario están en `docs/historias-usuario.md` y las decisiones técnicas en `docs/decisiones-tecnicas.md`.

## Compilar y correr

Los mensajes se cifran con una clave que no está en el repositorio (D20). Copia `secrets.example.json` a `secrets.json`, pon la clave real que comparte el equipo y pásala en cada comando:

```bash
flutter run --dart-define-from-file=secrets.json
flutter build apk --release --dart-define-from-file=secrets.json
```

Sin la clave la app compila, pero no envía mensajes y muestra los existentes como no disponibles.

## Pruebas

```bash
flutter analyze
flutter test
cd firebase_rules_tests && npm test
```

Las pruebas de reglas levantan el emulador de Firestore y Storage y necesitan JDK 21.
