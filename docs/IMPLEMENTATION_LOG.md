# Historial de implementación

## 23 de noviembre de 2026

| Hito | Cambio y verificación |
| --- | --- |
| `ca83e0d` | Adquisición fijada a una revisión de CISUTAC, validación de etiquetas y preparación del detector de ventanas. Push confirmado. |
| `a13823a` | Aplicación Flutter, modelo local ONNX, catálogo bilingüe y SQLite. Baselines y variantes convolucionales evaluados por prenda. Análisis y pruebas Flutter aprobadas. Push confirmado. |
| `22a8431` | Español inicial, pantallas organizadas por función, icono propio y configuración de firma de carga. Push confirmado. |
| Artículo y cierre de piloto | PDF IEEE A4 en español, manuscrito complementario en inglés, figuras, anexos, referencias, resultados reproducibles, prueba Android en modo avión y documentación de instalación y Play Console. |

Se entrenaron los modelos convolucionales en una RTX 4060 Ti. La prueba integral utilizó Android Emulator API 36 y la foto seleccionada de CISUTAC. El caso recorrió flujo, reinicio, recuperación, adjunto y resultado. La caja candidata obtuvo IoU 0,699 respecto a la anotación de esa foto. Se compiló APK ARM64, APK x86_64 y AAB local. Los resultados experimentales de 61 prendas están en `research/experiments`.

Pendientes de validación externa · dispositivos Android físicos, evaluación con prendas sanas, revisión experta de procedimientos, confirmación de datos de autor y firma de Play Console. El estado de los componentes previstos en el plan maestro se detalla en el [registro de alcance](PROJECT_STATUS.md).
