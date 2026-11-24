# Preparación de Android para Google Play

ReparaAI apunta a Android 16 (API 36) y admite instalaciones desde Android 7.0 (API 24). La entrega de pruebas incluye un APK ARM64. Google Play distribuye aplicaciones nuevas mediante Android App Bundle y exige verificar la compatibilidad de bibliotecas nativas con páginas de 16 KB. [Nivel de API requerido](https://support.google.com/googleplay/android-developer/answer/11926878), [Guía de 16 KB](https://developer.android.com/guide/practices/page-sizes)

## Compilación y firma

1. Para una instalación local, ejecuta `flutter build apk --release --target-platform android-arm64 --split-per-abi` desde `apps/mobile`.
2. Para generar el paquete de Play Console, configura la clave de carga del equipo siguiendo la guía oficial. Copia `android/key.properties.example` a `android/key.properties` y apunta al almacén privado de claves. Guarda las credenciales fuera de Git.
3. Ejecuta `flutter build appbundle --release`. El AAB queda en `build/app/outputs/bundle/release/app-release.aab`. Conserva la firma de carga y el número de versión. Sin el archivo de propiedades, la compilación usa firma de desarrollo para pruebas locales.
4. Valida el AAB con `bundletool validate` y la firma con la llave de carga. Verifica páginas de 16 KB, instalación, captura, selector, accesibilidad, traducciones y uso sin conexión en teléfonos físicos. [Publicar Android con Flutter](https://docs.flutter.dev/deployment/android)

## Ficha propuesta

| Campo | Español | English |
| --- | --- | --- |
| Nombre | ReparaAI | ReparaAI |
| Descripción corta | Guías para reparar prendas y registrar el resultado sin conexión. | Repair guides and offline progress tracking for everyday garments. |
| Descripción | Analiza fotos para sugerir zonas que revisar, confirma el daño y el tejido, y sigue una guía con fuente. Guarda el progreso, las fotos y el resultado en tu teléfono. El detector de agujeros es experimental. | Scan a photo for a candidate area, confirm the damage and fabric, and follow a guide with a source. Keep repair progress, photos and outcomes on your phone. The hole detector is experimental. |

Los pasos de Play Console quedan bajo la cuenta del equipo. Antes de una prueba cerrada, se necesita una URL pública para la política aprobada, completar la declaración de datos, confirmar las licencias del material de la ficha, y verificar el APK o AAB en dispositivos físicos. Confirma los requisitos aplicables de Play Console con la cuenta de publicación.
