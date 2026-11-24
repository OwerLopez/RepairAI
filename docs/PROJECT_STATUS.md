# Project status

| Scope | Status | Evidence and remaining work |
| --- | --- | --- |
| Selección de foto y calidad | VERIFIED en emulador | Galería nativa, control de foto, acceso a cámara y validaciones desacopladas con `ImageService` (límite 28 MB y 32 MP). Pruebas de equipo físico pendientes. |
| Localización de agujeros | TESTED | Modelo por mosaicos en ONNX, umbral sujeto a validación y evaluación agrupada. Faltan negativos verificados y una cohorte externa de fotografías de celular. |
| Recuperación de procedimientos | TESTED | Cuatro guías bilingües con fuentes y filtros por tela y equipo. Algoritmo de especificidad probado. Quedan revisión experta, ingesta vectorial, reranking y respuestas generativas. |
| Reparación guiada y resultado | VERIFIED en emulador | Progreso, reanudación, foto anterior y posterior y resultado guardado en modo avión. Métricas de impacto ecológico (`ImpactWidget`). La verificación visual y el efecto en reparaciones de usuarios requieren estudio. |
| Datos locales y privacidad | TESTED | SQLite con soporte para purga completa (`deleteAll`), borrado por reparación, respaldo Android desactivado y remoción de EXIF. Cuentas, sincronización, backend y sitio administrativo en la nube pendientes. |
| Dataset y experimentos | TESTED | Revisión pública fijada, partición por prenda, modelos clásicos y convolucionales, ablación e intervalos. Faltan calibración, máscaras, más clases y validación externa. |
| Artículo | IMPLEMENTED | PDF IEEE A4 en español, manuscrito ampliado en inglés y materiales de envío. Quedan datos de autor, evaluación independiente y aprobación para presentación científica. |
| Web | IMPLEMENTED | Mismo flujo Flutter en GitHub Pages con ONNX Runtime Web e historial en IndexedDB (Wasm). |

## Los 11 módulos del prompt original

| # | Módulo | Alcance actual |
| --- | --- | --- |
| 01 | Autenticación y usuarios | Pendiente. El diario actual es local y funciona sin cuenta. |
| 02 | Escáner visual | Cámara o galería en Android, galería web, control de calidad, marcado guiado y servicio desacoplado `ImageService`. |
| 03 | Reconocimiento de objetos | Pendiente. El usuario confirma que es una prenda de uso habitual. |
| 04 | Detección y segmentación | Parcial. Un candidato de agujero con caja, versión y abstención. Sin máscaras ni más clases de IA. |
| 05 | Material | Parcial. Selección confirmada por el usuario. Sin clasificador visual de fibras. |
| 06 | Evaluación de daños | Parcial. Calidad, puntuación, abstención y observación manual. Sin severidad validada. |
| 07 | Conocimiento de reparación | Parcial. Catálogo bilingüe con citas y filtros. Sin ingesta OCR, índice vectorial ni generación. |
| 08 | Planificador | Parcial. Guías compatibles por tela, daño y herramientas con ranking determinista por especificidad. Sin evaluación experta. |
| 09 | Asistente | Pasos, reanudación, fotos y comparación visual. Quedan preguntas abiertas y verificación de reparación. |
| 10 | Historial e impacto | Parcial. Historial local con resultados, fotos y reanudación. Módulo de cálculo y visualización de impacto ambiental estimado (`ImpactService` e `ImpactWidget`: CO₂ evitado en kg, agua ahorrada en litros y prendas rescatadas del vertedero). |
| 11 | Administración | Parcial. Pantalla de ajustes local (`SettingsPage`) con selector de idioma en tiempo de ejecución, créditos de autoría, declaratoria de privacidad local-first y gestión de datos con borrado completo (`deleteAll`). Sin backend de cuentas en la nube ni almacenamiento remoto centralizado. |

## Mejoras de Arquitectura e Ingeniería

- **Pantalla de Ajustes y Administración (`SettingsPage`)**: Módulo 11 parcial. Permite conmutar idioma (español/inglés) en tiempo de ejecución, consultar información del proyecto y autores, revisar la política de privacidad local-first y ejecutar el borrado total de la base de datos local con diálogo de confirmación seguro.
- **Seguimiento de Impacto Ambiental (`ImpactWidget` e `ImpactService`)**: Módulo 10 parcial. Cuantifica y presenta métricas ambientales acumuladas a partir de las prendas reparadas exitosamente (33.4 kg de CO₂ y 3,781 litros de agua por prenda).
- **Capa de Cadenas Centralizadas e Internacionalización (`Strings`)**: Arquitectura de localización centralizada en `lib/l10n/strings.dart` con acceso tipado e indexado por idioma para todas las pantallas del sistema, eliminando cadenas duras dispersas.
- **Capa de Modelos de Datos (`lib/models/`)**: Entidades de dominio tipadas que desacoplan la lógica de datos: `RepairSession` (con deserialización/serialización bidireccional SQLite y JSON), `Scan` (resultado de inferencia de visión) y jerarquía de excepciones tipadas `AppError` (`ImageTooLargeError`, `ImageFormatError`, `DatabaseError`).
- **Capa de Servicios Desacoplada (`lib/services/`)**: `ImageService` (aislamiento de validaciones de tamaño, dimensiones, megapíxeles y decodificación de imagen) e `ImpactService` (cálculos de ahorro ambiental).
- **Suite Integral de Pruebas Unitarias**: Crecimiento de 4 pruebas iniciales a 24 pruebas exhaustivas cubriendo:
  - `glass_test.dart`: Paleta de colores, componentes de vidrio esmerilado y shader Aurora.
  - `journal_test.dart`: Ciclo de vida completo del SQLite Journal (CRUD, atomicidad, persistencia de fotos BLOB, bloqueo de avance idempotente y gestión de preferencias).
  - `procedures_test.dart`: Filtrado por material, herramientas y ordenamiento determinista por especificidad de tela.
  - `ui_helpers_test.dart`: Etiquetas de escaneo, estados de resultado y extensiones de localización.
  - `vision_test.dart`: Heurísticas de calidad (resolución, iluminación, enfoque) y despojado de metadatos EXIF.
- **Documentación Técnica y Gobernanza**:
  - `docs/ARCHITECTURE.md`: Arquitectura del sistema, pipeline visual, patrones de diseño (Repository, Strategy, Advisory), postura de seguridad local-first y optimizaciones de rendimiento.
  - `docs/API.md`: Especificación técnica de modelos internos, interfaces de visión, motor de conocimiento y repositorio SQLite.
  - `docs/CONTRIBUTING.md`: Guía de contribución, estándares de estilo, comandos de verificación y flujo de trabajo de pull requests.
  - `CHANGELOG.md`: Registro de versiones según Keep a Changelog y SemVer.
  - `.github/ISSUE_TEMPLATE/`: Plantillas para reportes de errores y sugerencias de nuevas características.
