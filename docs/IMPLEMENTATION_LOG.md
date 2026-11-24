# Historial de implementación

## 24 de noviembre de 2026

| Hito | Cambio y verificación |
| --- | --- |
| Arquitectura y modelos | Creación de capa de datos desacoplada en `lib/models/` (`RepairSession`, `Scan`, jerarquía de excepciones `AppError`) y capa de servicios en `lib/services/` (`ImageService` para validación y decodificación; `ImpactService` para métricas de sostenibilidad). |
| Ajustes y administración | Implementación de `SettingsPage` (Módulo 11 parcial): selector de idioma en tiempo de ejecución, créditos de autoría, declaratoria de privacidad local-first y borrado completo de base de datos (`deleteAll`) con confirmación modal. |
| Impacto ambiental | Implementación de `ImpactWidget` (Módulo 10 parcial): visualización reactiva de prendas rescatadas, kg de CO₂ evitados y litros de agua ahorrados calculados a partir de las reparaciones registradas en SQLite. |
| Internacionalización (i18n) | Centralización de recursos lingüísticos bilingües en `lib/l10n/strings.dart` (`Strings`), organizando textos por pantalla y eliminando cadenas dispersas. |
| Suite de pruebas integral | Expansión de pruebas unitarias de 4 a 24 tests aprobados (`glass_test.dart`, `journal_test.dart`, `procedures_test.dart`, `ui_helpers_test.dart`, `vision_test.dart`), validando el ciclo SQLite completo, ranking de procedimientos, heurísticas de calidad y renderizado de componentes. |
| Documentación y gobernanza | Creación de documentación integral del repositorio: `docs/ARCHITECTURE.md`, `docs/API.md`, `docs/CONTRIBUTING.md`, `CHANGELOG.md` (formato Keep a Changelog) y plantillas en `.github/ISSUE_TEMPLATE/`. |
| Validación y `.gitignore` | Actualización de reglas `.gitignore` a nivel raíz y en `apps/mobile/` para cubrir archivos generados (Dart/Flutter, IDEs, Python, SQLite, LaTeX). Verificación integral: `dart format lib test` limpio, `flutter analyze --no-pub` con 0 incidencias y `flutter test --no-pub` con 24/24 pruebas superadas. |

## 23 de noviembre de 2026

| Hito | Cambio y verificación |
| --- | --- |
| `ca83e0d` | Adquisición fijada a una revisión de CISUTAC, validación de etiquetas y preparación del detector de ventanas. Push confirmado. |
| `a13823a` | Aplicación Flutter, modelo local ONNX, catálogo bilingüe y SQLite. Baselines y variantes convolucionales evaluados por prenda. Análisis y pruebas Flutter aprobadas. Push confirmado. |
| `22a8431` | Español inicial, pantallas organizadas por función, icono propio y configuración de firma de carga. Push confirmado. |
| Artículo y cierre de piloto | PDF IEEE A4 en español, manuscrito complementario en inglés, figuras, anexos, referencias, resultados reproducibles, prueba Android en modo avión y documentación de instalación y Play Console. |

Se entrenaron los modelos convolucionales en una RTX 4060 Ti. La prueba integral utilizó Android Emulator API 36 y la foto seleccionada de CISUTAC. El caso recorrió flujo, reinicio, recuperación, adjunto y resultado. La caja candidata obtuvo IoU 0,699 respecto a la anotación de esa foto. Se compiló APK ARM64, APK x86_64 y AAB local. Los resultados experimentales de 61 prendas están en `research/experiments`.

Pendientes de validación externa · dispositivos Android físicos, evaluación con prendas sanas, revisión experta de procedimientos, confirmación de datos de autor y firma de Play Console. El estado de los componentes previstos en el plan maestro se detalla en el [registro de alcance](PROJECT_STATUS.md).
