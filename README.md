[![Pilot validation](https://github.com/OwerLopez/RepairAI/actions/workflows/pilot.yml/badge.svg)](https://github.com/OwerLopez/RepairAI/actions/workflows/pilot.yml)
[![Flutter 3.38.3](https://img.shields.io/badge/Flutter-3.38.3-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)

# ReparaAI

Aplicación Android para analizar una fotografía de una prenda, consultar una guía de reparación con fuente y guardar el progreso y el resultado sin conexión. La interfaz inicia en español y permite cambiar a inglés. El trabajo de investigación **UCRA** evalúa localización visual de agujeros y el efecto de la abstención.

[Abrir ReparaAI web](https://owerlopez.github.io/RepairAI/) · [Descargar APK ARM64](https://github.com/OwerLopez/RepairAI/releases/latest/download/ReparaAI-android-arm64.apk) · [Artículo IEEE en español](research/paper/dist/reparaai-ieee-es.pdf) · [Estado de los módulos](docs/PROJECT_STATUS.md)

## Flujo de una reparación

1. Toma una fotografía o selecciónala desde el dispositivo. La app verifica resolución, iluminación y enfoque.
2. Inspecciona la zona sugerida por el detector experimental. Puedes señalar un área para acotar la búsqueda o identificar el daño manualmente.
3. Confirma el daño, el tejido y las herramientas disponibles. El catálogo local ofrece procedimientos para agujeros, desgarros o costuras rectas abiertas según ese contexto.
4. Abre el procedimiento, revisa su fuente y marca los pasos completados. Si sales de la app, puedes continuar desde Historial.
5. Adjunta una foto del resultado, compárala con la inicial y registra el desenlace. El historial queda en el teléfono o navegador que uses. La guía original se abre en el navegador si hay conexión.

![Escáner, diagnóstico, reparación e historial en Android](research/paper/figures/flujo_android.png)

## Web e instalación local

La [app web publicada](https://owerlopez.github.io/RepairAI/) conserva el mismo flujo y ejecuta el modelo dentro del navegador. SQLite usa IndexedDB para persistir el historial web. La primera carga requiere descargar el sitio y el runtime web. El [APK de prueba ARM64](https://github.com/OwerLopez/RepairAI/releases/tag/v0.2.0) permite instalar la versión móvil en Android compatible.

**Requisitos** · Flutter 3.38.3, SDK Android con API 36 y JDK 17 o superior. Usa Android Studio Device Manager o un teléfono con depuración USB. El mínimo de instalación es Android 7.0 (API 24). [Instalar Flutter](https://docs.flutter.dev/install)

```sh
git clone https://github.com/OwerLopez/RepairAI.git
cd RepairAI/apps/mobile
flutter doctor
flutter pub get --enforce-lockfile
flutter devices
flutter run -d ID_DEL_DISPOSITIVO
```

El modelo y el catálogo vienen incluidos en el código. La app arranca y funciona sin variables de entorno, cuenta ni servidor. Para instalar el APK de pruebas en un teléfono ARM64, compila desde `apps/mobile` y usa el archivo ubicado en `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

```sh
flutter build apk --release --target-platform android-arm64 --split-per-abi
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Para un emulador x86_64, sustituye `android-arm64` por `android-x64` y usa `app-x86_64-release.apk`. La firma por defecto es de desarrollo. Consulta la [guía de firma y distribución](docs/PLAY_STORE.md) para generar un AAB con la clave de carga. El flujo local no requiere hosting.

## Arquitectura

```mermaid
flowchart LR
    A["Cámara o galería"] --> B["Calidad de imagen"]
    B -->|Foto apta| C["Detector ONNX local"]
    B -->|Foto insuficiente| A
    C --> D["Candidato o abstención"]
    D --> E["Confirmación del usuario"]
    E --> F["Catálogo local con fuentes"]
    F --> G["Reparación guiada"]
    G --> H[("SQLite en el dispositivo")]
```

| Carpeta | Contenido |
| --- | --- |
| [apps/mobile](apps/mobile/) | Flutter, Android, proyecto iOS, visión, catálogo y diario |
| [ml](ml/) | Adquisición, validación, entrenamiento, exportación y figuras |
| [research](research/) | Dataset, protocolo, resultados, figuras y manuscritos |
| [scripts](scripts/) | Prueba del flujo real por ADB |
| [docs](docs/) | Arquitectura, QA, estado, privacidad y distribución |
| [.github/workflows](.github/workflows/) | Validación continua del código, tabla experimental y compilación |

La app separa la región sugerida, la observación del usuario y el resultado declarado. Guarda una copia JPEG sin metadatos EXIF y conserva una copia del plan y su referencia. El historial vive en el almacenamiento privado de la app. Se puede eliminar una sesión y sus fotos desde Historial. [Decisión de arquitectura](docs/adr/001-local-first-pilot.md), [datos en el dispositivo](docs/PRIVACIDAD.md)

## Pruebas

```sh
cd apps/mobile
flutter analyze
flutter test
```

La prueba de integración usa un emulador Android y una fotografía real de CISUTAC. Abre la galería nativa, confirma contexto, comprueba la reanudación después de detener el proceso y verifica el resultado en SQLite. Incluye una comprobación de cambio de idioma. Las instrucciones y el registro reproducible están en la [guía de QA](docs/TESTING.md).

## Investigación y artículo

La evaluación conserva una sola variante de mayor resolución por vista y asigna prendas completas a entrenamiento, validación o prueba. El análisis completo localizó 8 de 61 vistas reservadas a IoU 0,25. Con marcas idealizadas se localizaron 11 de 61. En el dominio externo de FabriD se localizaron 0 de 77 vistas con agujeros y hubo 14 propuestas en 88 vistas con anotaciones vacías. Faltan confirmación con fotos tomadas por usuarios, validación en teléfonos físicos y evaluación independiente de los procedimientos.

- [Artículo IEEE A4 en español](research/paper/dist/reparaai-ieee-es.pdf) y [fuentes LaTeX](research/paper/)
- [Revisión de datasets y licencias](research/datasets/INVENTORY.md)
- [Protocolo de recolección, anotación y evaluación](research/methodology/ANNOTATION.md)
- [Resultados y reproducción de experimentos](research/experiments/)
- [Historial de implementación](docs/IMPLEMENTATION_LOG.md)

**Autores** · Lopez Arela, Ower Frank · Zegarra Puma, Mauricio Eduardo · Huamani Chañi, Diego Oswaldo.

**Atribución** · Se acredita a CISUTAC y Wargön Innovation por la revisión de [Garment Condition Holes](https://huggingface.co/datasets/wargoninnovation/Garment_condition_holes/tree/3b81cb807188690222ef2a6af9cbfd2271292a32) bajo [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Se deduplicaron las vistas, se reasignaron por prenda y se convirtieron polígonos en cajas para entrenar y evaluar los modelos. La captura del artículo muestra una imagen del mismo conjunto. Cada entrada del catálogo cita el procedimiento que la respalda.

## English

ReparaAI is a bilingual offline Android app for screening garment photos, finding source-linked repair instructions, and keeping a repair journal. Use the globe button to switch to English. The hole detector is experimental and the repair plan relies on the user confirming the damage and fabric. The [English manuscript source](research/paper/main.tex) and [reproduction instructions](research/experiments/) describe the benchmark.

## Contributing

Contributions to ReparaAI are welcome! Please read our [Contribution Guidelines](docs/CONTRIBUTING.md) for details on prerequisites, local environment setup, code style, testing protocols, and the pull request process.

## License

This project's license is currently under development / proprietary pending publication. See [docs/PRIVACIDAD.md](docs/PRIVACIDAD.md) and dataset notices for attribution and research usage terms.

## Changelog

For a detailed history of changes and releases, see [CHANGELOG.md](CHANGELOG.md).
