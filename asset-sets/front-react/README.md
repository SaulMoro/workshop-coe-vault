# front-react

Aplicaciones React con Vite y TypeScript.

## Contenido

- `skills/react-best-practices`: componentes, efectos, keys y contexto, con una reference por tema. Al exportar, se junta con las `*-best-practices` de su línea de dependencia.
- `skills/react-forms`: formularios con las acciones de React 19. Su `manifest.json` declara su tema y las skills a las que llama.
- `skills/react-check`: diagnóstico de componentes, con un script de solo lectura.
- `instructions/react-components.instructions.md`: reglas para los componentes `.tsx`.
- `agents/react-reviewer.agent.md`: revisa componentes en su propio contexto y devuelve hallazgos con fichero y línea.

## Línea de dependencia

- front-react
- front-core
- dev-typescript
- dev-core
- common-core

## Frontera

Lo que vale para cualquier framework va en `front-core`. Una especialización de React, por ejemplo los estados de una pantalla, va en un set propio que depende de este.
