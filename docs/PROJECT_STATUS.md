# Project status

| Scope | Status | Evidence and remaining work |
| --- | --- | --- |
| Selección de foto y calidad | VERIFIED en emulador | Galería nativa, control de foto y acceso a cámara. Pruebas de equipo físico pendientes. |
| Localización de agujeros | TESTED | Modelo por mosaicos en ONNX, umbral sujeto a validación y evaluación agrupada. Faltan negativos verificados y una cohorte externa de fotografías de celular. |
| Recuperación de procedimientos | TESTED | Cuatro guías bilingües con fuentes y filtros por tela y equipo. Quedan revisión experta, ingesta vectorial, reranking y respuestas generativas. |
| Reparación guiada y resultado | VERIFIED en emulador | Progreso, reanudación, foto anterior y posterior y resultado guardado en modo avión. La verificación visual y el efecto en reparaciones de usuarios requieren estudio. |
| Datos locales y privacidad | TESTED | SQLite, borrado por reparación, respaldo Android desactivado y remoción de EXIF. Cuentas, sincronización, backend y sitio administrativo pendientes. |
| Dataset y experimentos | TESTED | Revisión pública fijada, partición por prenda, modelos clásicos y convolucionales, ablación e intervalos. Faltan calibración, máscaras, más clases y validación externa. |
| Artículo | IMPLEMENTED | PDF IEEE A4 en español, manuscrito ampliado en inglés y materiales de envío. Quedan datos de autor, evaluación independiente y aprobación para presentación científica. |
| Web | IMPLEMENTED | Mismo flujo Flutter en GitHub Pages con ONNX Runtime Web e historial en IndexedDB. |

## Los 11 módulos del prompt original

| # | Módulo | Alcance actual |
| --- | --- | --- |
| 01 | Autenticación y usuarios | Pendiente. El diario actual es local y funciona sin cuenta. |
| 02 | Escáner visual | Cámara o galería en Android, galería web, control de calidad y marcado guiado. |
| 03 | Reconocimiento de objetos | Pendiente. El usuario confirma que es una prenda de uso habitual. |
| 04 | Detección y segmentación | Parcial. Un candidato de agujero con caja, versión y abstención. Sin máscaras ni más clases de IA. |
| 05 | Material | Parcial. Selección confirmada por el usuario. Sin clasificador visual de fibras. |
| 06 | Evaluación de daños | Parcial. Calidad, puntuación, abstención y observación manual. Sin severidad validada. |
| 07 | Conocimiento de reparación | Parcial. Catálogo bilingüe con citas y filtros. Sin ingesta OCR, índice vectorial ni generación. |
| 08 | Planificador | Parcial. Guías compatibles por tela, daño y herramientas. Sin evaluación experta. |
| 09 | Asistente | Pasos, reanudación, fotos y comparación visual. Quedan preguntas abiertas y verificación de reparación. |
| 10 | Historial e impacto | Historial con resultados y fotos. No se calculan ahorros ambientales. |
| 11 | Administración | Pendiente. Sin backend de cuentas, almacenamiento remoto ni panel administrativo. |
