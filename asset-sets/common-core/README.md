# common-core

La base de todas las líneas de dependencia: lo que sirve en cualquier tarea, sea cual sea la tecnología.

## Contenido

- `skills/clarify-task`: ante una petición con más de una lectura razonable, pregunta antes de cambiar nada.
- `skills/project-glossary`: mantiene al día el glosario del proyecto.

## Línea de dependencia

- common-core

## Frontera

Nada de lenguajes, frameworks ni herramientas: eso va en `dev-core` y en los sets de encima. `common-core` no lleva skills `*-best-practices`: el export las juntaría con las de cada línea y dejarían de salir iguales en todas.
