# Contribuir al vault de práctica

## Quién decide

Cada set tiene un owner, el campo `owner` de su `manifest.json`. El owner decide qué entra en su set. En este vault los owners son equipos ficticios y revisa el formador.

**Los PR de práctica no se fusionan.** El formador los revisa y los cierra al terminar la sesión, para que `main` sea igual en cada edición del curso. Si en directo fusiona uno, es para enseñar el paso a ACTIVE o una versión nueva.

## Flujo

1. Rama nueva desde `main`, nunca desde otra propuesta: `git switch -c propuesta/<tema>-<tu-usuario> main`.
2. El cambio, en el set al que pertenece. Mismo ámbito, mismo set.
3. Revisión con Copilot: `/asset-review revisa asset-sets/<set>`. Decide cada aviso: un aviso no es un veredicto.
4. `tools/verify.sh`, hasta que termine con `0 errores`. Si tocas `tools/`, también `tools/test.sh`.
5. Commit y `gh pr create --fill`. Sin GitHub, `git diff main` es tu entregable.

## Un set nuevo

- Carpeta `asset-sets/<capa>-<especialización>/`, con el mismo nombre en el campo `name` del manifest.
- `"status": "PROPOSED"` y `"version": "0.1.0"`. Pasa a ACTIVE con su primer merge.
- Un `owner` propuesto y, en `dependencies`, el set más cercano sobre el que se apoya.
- `README.md` con su propósito y `## Línea de dependencia`: un set por elemento de lista, de la hoja a la base. Si falta, `tools/verify.sh` te da el texto exacto.

## Lo que nunca entra

- Código, nombres o reglas de un proyecto o de un cliente reales.
- Rutas de un repositorio concreto: una página de `src/`, una carpeta `.github/`. Un hook o un script del vault solo nombra rutas que crea el export (`.agents/…`) o rutas que recibe como argumento.
- Emails, tokens, hosts internos y secretos. Un `env` va como `${VARIABLE}`, nunca con su valor.
- Texto copiado de otros vaults o de su documentación.

## Idiomas

El texto para modelos (skills, instructions, agents) va en inglés. La documentación para personas y la salida de las herramientas van en español.
