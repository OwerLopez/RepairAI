# Pruebas de ReparaAI

Ejecuta estas comprobaciones desde `apps/mobile`.

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug --target-platform android-x64 --split-per-abi
```

La prueba integral usa un emulador Android dedicado con sistema en inglés, app en español y una sola foto en el selector. Abre la galería nativa, analiza una imagen de CISUTAC, verifica la alternancia de idiomas, confirma el contexto, recupera una guía y guarda el progreso. Después de detener el proceso reabre la sesión, completa los pasos, adjunta una foto de prueba y comprueba el resultado almacenado en SQLite. El material seleccionado y la foto del resultado ejercitan las rutas de software.

```sh
python scripts/android_smoke.py --serial emulator-5554 \
  --apk apps/mobile/build/app/outputs/flutter-apk/app-x86_64-debug.apk \
  --photo RUTA_A_FOTO_CISUTAC --report output/android_smoke.json \
  --screenshots .data/android-screens
```

El archivo de referencia aparece en el [resultado de la ejecución](../research/experiments/android_smoke.json). Se obtiene con `python ml/acquire.py`. La lectura de SQLite usa `run-as` y requiere una compilación de depuración.

| Verificación | Resultado de la sesión |
| --- | --- |
| Análisis estático de Flutter | Sin hallazgos |
| Pruebas unitarias | 4 aprobadas |
| Android 16 x86_64, modo avión | Galería, inferencia, idioma, reanudación, 3 pasos, foto adjunta y resultado guardado |
| APK optimizado x86_64 | Instalación y lanzamiento en el emulador, historial conservado y apertura y cancelación de la cámara nativa |
| APK ARM64 | Compilado, firma local verificada y `zipalign -c -P 16` aprobado |
| App Bundle | Compilado, validado con `bundletool` y configurado con `PAGE_ALIGNMENT_16K` |

La alineación ELF de los segmentos de carga se comprobó para bibliotecas ARM64 y x86_64. Falta repetir la prueba en equipos físicos y en un sistema de páginas de 16 KB. La prueba de integración verifica el software y el paper presenta las métricas sobre todo el conjunto de prueba.
