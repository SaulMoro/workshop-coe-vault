# front-ui-states

Estados de carga y de error, y accesibilidad, para las listas React que leen datos del servidor. Especializa `front-react`: su ámbito es más estrecho.

## Contenido

- `skills/loading-states`: Suspense con un esqueleto que mantiene la forma de la lista.
- `skills/list-a11y`: `aria-label` en la lista y un resumen para lectores de pantalla.
- `skills/api-errors`: errores de API con `ErrorBanner` y reintento.
- `instructions/ui.instructions.md`: hace que cada lista siga list-a11y.
- `hooks/check-loading.json`: al parar, comprueba el estado de carga de las páginas que han cambiado.
- `agents/ui-reviewer.agent.md`: revisa en su propio contexto los estados de carga y de error de una página.

## Línea de dependencia

- front-ui-states
- front-react
- front-core
- dev-typescript
- dev-core
- common-core
