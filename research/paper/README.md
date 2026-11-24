# Artículo UCRA

El manuscrito principal es `reparaai-ieee-es.tex`, en español y formato de conferencia IEEE A4. Incluye las secciones IMRyD, comparación de plataformas, figuras, tablas, bibliografía y anexos. `main.tex` conserva la versión ampliada en inglés. Consulta la [plantilla de conferencia](https://cai.ieee.org/2025/manuscript-templates-for-conference-proceedings/).

```sh
cd research/paper
tectonic reparaai-ieee-es.tex
tectonic main.tex
```

Desde la raíz, ejecuta `python ml/paper_tables.py` para regenerar la tabla del manuscrito inglés y `python ml/paper_figures.py` para regenerar las curvas de ambas versiones después de reproducir los experimentos. `references.bib` contiene las referencias compartidas. Para remitir el trabajo al curso, usa el PDF IEEE. Una eventual presentación científica requiere completar las [declaraciones de los autores](submission/STATEMENTS.md), comprobar los requisitos del destino y obtener aprobación del equipo.
