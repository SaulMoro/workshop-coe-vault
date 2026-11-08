# asset-kit

Lo que usa quien escribe o revisa assets para el vault.

## Contenido

- `skills/asset-review`: decide el tipo de cada pieza de un set, revisa la frontera del vault, marca los dated patterns y comprueba el manifest. Se invoca con `/asset-review`.
- `hooks/check-on-stop.json`: al terminar el agente, ejecuta `tools/verify.sh` si el repositorio es un vault. Detalles en `hooks/check-on-stop.md`.

## Línea de dependencia

- asset-kit
- common-core

## Frontera

Las reglas de un tipo de proyecto (React, TypeScript…) van en su set. Aquí solo está cómo se escribe y se revisa un asset.
