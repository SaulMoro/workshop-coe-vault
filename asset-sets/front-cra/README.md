# front-cra

Aplicaciones React que aún se construyen con Create React App. Está en DEPRECATED: se exporta hasta su `retireOn`, el 2027-06-30, y después el export para y avisa.

## Contenido

- `instructions/cra-env.instructions.md`: variables de entorno al estilo de Create React App.

## Línea de dependencia

- front-cra
- front-core
- dev-typescript
- dev-core
- common-core

## Migrar a front-react

1. Pasa el proyecto a Vite con su plantilla de React y TypeScript.
2. Renombra las variables `REACT_APP_*` a `VITE_*` y lee `import.meta.env` en lugar de `process.env`.
3. Mueve `public/index.html` a la raíz como `index.html` y añade el `<script type="module">` de entrada.
4. Exporta `front-react` en lugar de `front-cra` y borra de `.agents/` lo que el export anterior dejó.
5. Ejecuta los tests y la build antes de borrar la configuración vieja.
