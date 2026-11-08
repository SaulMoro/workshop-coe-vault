# workshop-coe-vault

Vault de práctica de la formación «Vault y CDN» del AI CoE de knowmad mood.

Tiene la estructura y las herramientas de un vault de assets para agentes: asset sets con su manifest y su estado, líneas de dependencia, un export que las lleva a tu repositorio y las comprobaciones que pasa cada cambio. El contenido es genérico y los owners son equipos ficticios. **No es el vault de la compañía.**

El vault organiza y gobierna: aquí se decide qué entra en cada set y quién responde de él. Para llevarlo a un repositorio, lo recomendado es instalar los paquetes de [workshop-coe-cdn](https://github.com/SaulMoro/workshop-coe-cdn), que se construyen desde este vault. Exportar a mano, como se explica abajo, es el puente mientras tu repositorio no tiene CDN.

Se usa con [workshop-coe](https://github.com/SaulMoro/workshop-coe), la aplicación de los talleres.

## Requisitos

- git y bash. En Windows, Git Bash.
- Node 20 o posterior. Las herramientas solo lo usan para leer JSON.
- Opcional: GitHub CLI (`gh`), para abrir el PR desde la terminal.

## Exportar una línea de dependencia a Copilot, sin CDN

Clona el vault una vez, al lado de tus repositorios:

```bash
git clone https://github.com/SaulMoro/workshop-coe-vault.git ~/workshop-coe-vault
~/workshop-coe-vault/tools/export.sh --list
```

Exporta desde la raíz de tu repositorio, nunca dentro del vault:

```bash
cd ~/workshop-coe
~/workshop-coe-vault/tools/export.sh --root ~/workshop-coe-vault front-react .agents
```

El export recorre la línea de dependencia de `front-react` desde la base, comprueba que cada set se puede exportar, junta las cuatro skills `*-best-practices` en `react-best-practices` y monta el resultado aparte. Si algo falla, no escribe nada. Antes de escribir imprime la **auditoría**: los hooks, los scripts y los servidores MCP que se ejecutarán en tu máquina. Léela junto al `git diff`.

Copilot lee las skills de `.agents/skills/` tal cual. Las instructions y los agents se copian a `.github/`:

```bash
mkdir -p .github/instructions .github/agents
cp .agents/instructions/*.md .github/instructions/
cp .agents/agents/*.agent.md .github/agents/
rm .agents/AGENTS.md
git add .agents .github && git commit -m "front-react exportado"
```

La guía completa, con hooks, MCP y cómo volver a exportar: [docs/copilot.md](docs/copilot.md).

## Los sets

| Set | Estado | Owner | Depende de |
|---|---|---|---|
| `common-core` | ACTIVE | ai-coe | — |
| `dev-core` | ACTIVE | equipo-dev | `common-core` |
| `dev-typescript` | ACTIVE | equipo-dev | `dev-core` |
| `front-core` | ACTIVE | equipo-front | `dev-typescript` |
| `front-react` | ACTIVE | equipo-front | `front-core` |
| `front-cra` | DEPRECATED hasta 2027-06-30 | equipo-front | `front-core` |
| `qa-core` | ACTIVE | equipo-qa | `dev-core` |
| `asset-kit` | ACTIVE | ai-coe | `common-core` |
| `back-core` | PROPOSED | equipo-back | `dev-core` |

Cada manifest declara solo el set inmediato sobre el que se apoya. La línea de dependencia entera de cada set la da `tools/export.sh --list`, y cada README la escribe de la hoja a la base.

`front-ui-states` no está: lo propone la sala en los talleres.

Un set por dentro:

```text
asset-sets/front-react/
├── manifest.json        nombre, estado, owner, versión y de qué set depende
├── README.md            propósito y línea de dependencia
├── instructions/react-components.instructions.md
├── agents/react-reviewer.agent.md
└── skills/
    ├── react-best-practices/   SKILL.md y references/
    ├── react-forms/            SKILL.md, references/ y manifest.json de skill
    └── react-check/            SKILL.md y scripts/scan-components.sh
```

## Estados

| Estado | Qué significa | ¿Se exporta? |
|---|---|---|
| PROPOSED | Set nuevo, aún sin su primer merge | No |
| ACTIVE | En uso, con owner | Sí |
| DEPRECATED | Se retira; su manifest dice hasta cuándo (`retireOn`) y qué lo sustituye | Sí, hasta su `retireOn` |
| SUSPENDED | Parado mientras se revisa | No |
| ARCHIVED | Retirado | No |

El export toma la línea de dependencia entera: si un set de la línea no se puede exportar, no se exporta nada.

## Proponer un cambio

Las propuestas llegan como PR, con ramas que salen siempre de `main`. Funciona igual si tienes permiso de escritura en el repo que si no:

```bash
cd ~/workshop-coe-vault
git config user.email "<tu-usuario>@users.noreply.github.com"
git switch -c propuesta/<tema>-<tu-usuario> main
# haz el cambio y, en VS Code: /asset-review revisa asset-sets/<set>
tools/verify.sh
git add asset-sets && git commit -m "<set>: <qué cambia>"
gh pr create --fill
```

- Si no tienes permiso de escritura, `gh pr create` te ofrece crear tu fork y empujar la rama allí. Si eres el dueño del repo, la empuja al propio repo.
- Sin cuenta de GitHub o sin `gh`, trabaja en la rama local: `tools/verify.sh` y `git diff main` son tu entregable.
- `/asset-review` aparece en el chat de Copilot al abrir el vault en VS Code (lo activa `.vscode/settings.json`).

Los PR de práctica no se fusionan: así `main` sigue igual en cada edición del curso. El resultado de referencia de cada propuesta vive en una rama `ref/…` y en tags. Más detalles en [CONTRIBUTING.md](CONTRIBUTING.md).

## Ramas y tags

| Ref | Qué es |
|---|---|
| `main` y tag `v1.0.0` | El punto de partida de los talleres. El CDN fija `front-react` 1.0.0 en `v1.0.0`. Cada PR de práctica sale de `main`. |
| `ref/front-ui-states-activo` | El set que propone la sala después de `/asset-review`, y su paso a ACTIVE con el primer merge. |
| `ref/front-react-1.1.0` y tag `front-react-1.1.0` | El PR aceptado de la promoción: la regla de estado derivado en `react-components` y `front-react` en 1.1.0. |

## Herramientas

| Herramienta | Qué hace |
|---|---|
| `tools/export.sh` | Exporta la línea de dependencia de un set a un destino. `--help` para el detalle. |
| `tools/verify.sh` | Comprueba el vault, o los sets que le pases, sin red. Los avisos no bloquean. |
| `tools/test.sh` | Ejecuta todos los tests del repo. |
| `asset-sets/asset-kit/skills/asset-review/scripts/scan-dated.sh` | Marca dated patterns en el texto de un set. |

## Licencia

[MIT](LICENSE).
