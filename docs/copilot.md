# Usar el export con GitHub Copilot

Guía para llevar una línea de dependencia del vault a un repositorio que trabaja con Copilot en VS Code (modo Agent). Los ejemplos usan `front-react` y `~/workshop-coe`.

## 1. Exporta

Desde la raíz de tu repositorio:

```bash
cd ~/workshop-coe
~/workshop-coe-vault/tools/export.sh --root ~/workshop-coe-vault front-react .agents
```

Lee la auditoría antes de seguir: lista los hooks, los scripts y los servidores MCP que se ejecutarán en tu máquina. Ábrelos y mira qué escriben, a qué red llaman y qué leen del entorno. Después, `git status --short .agents`.

El export escribe en `.agents/`:

| Ruta | Qué es | Qué haces con ello |
|---|---|---|
| `skills/<nombre>/` | Una carpeta por skill | Nada |
| `instructions/*.instructions.md` | Una por instruction, con su `applyTo` | Copiarlas a `.github/instructions/` |
| `agents/*.agent.md` | Uno por agent | Copiarlos a `.github/agents/` |
| `hooks/` | Declaraciones `.json` y sus scripts | Copiar los `.json` a `.github/hooks/` |
| `mcp.json` | Los servidores MCP de la línea, juntos | Pasarlos a `.vscode/mcp.json` |
| `AGENTS.md` | Todas las instructions en un fichero | Borrarlo |

## 2. Skills: nada que hacer

Copilot descubre las skills en `.agents/skills/<nombre>/SKILL.md` y las carga por su description cuando una tarea las necesita.

## 3. Instructions y agents: a `.github/`

Copilot aplica las instructions de `.github/instructions/` según su `applyTo`, y ofrece los agents de `.github/agents/`. En `.agents/` no los busca:

```bash
mkdir -p .github/instructions .github/agents
cp .agents/instructions/*.md .github/instructions/
cp .agents/agents/*.agent.md .github/agents/
```

## 4. Borra `.agents/AGENTS.md`

Es para clientes que no entienden `applyTo`: repite todas las instructions en un solo fichero. Con Copilot, las reglas llegarían dos veces y además sin su `applyTo`, en cualquier fichero que edites:

```bash
rm .agents/AGENTS.md
```

## 5. Hooks

La declaración `.json` va a `.github/hooks/` tal cual: el vault ya usa el formato de Copilot (`"version": 1`). El script se queda en `.agents/hooks/`, que es la ruta a la que apunta la declaración:

```bash
mkdir -p .github/hooks
cp .agents/hooks/*.json .github/hooks/
```

La línea de `front-react` no trae hooks; la de `asset-kit`, sí.

## 6. Servidores MCP

VS Code los lee de `.vscode/mcp.json`, bajo la clave `servers`. Copia cada entrada de `mcpServers` de `.agents/mcp.json`:

```json
{
  "servers": {
    "playwright": { "command": "npx", "args": ["-y", "@playwright/mcp@0.0.41"] }
  }
}
```

Un secreto va como `${input:…}` o `${env:VARIABLE}`, nunca escrito. La línea de `front-react` no trae servidores; la de `qa-core`, sí.

## 7. Comprueba

Haz commit del export y de las copias, y pregunta en el chat:

> Dime qué skills puedes cargar y de qué carpeta sale cada una.

La vista de diagnóstico del chat enseña qué instructions, skills y agents ha cargado.

## 8. Vuelve a exportar

Lo exportado no se edita: el siguiente export lo reescribe. Cada export vuelve a escribir sus ficheros en `.agents/` y no borra nada más. Repite las copias cada vez:

```bash
~/workshop-coe-vault/tools/export.sh --root ~/workshop-coe-vault front-react .agents
cp .agents/instructions/*.md .github/instructions/
cp .agents/agents/*.agent.md .github/agents/
rm .agents/AGENTS.md
```

Si cambias de línea de dependencia, el export avisa de las entradas de `.agents/` que no ha escrito: bórralas tú.

## 9. Lo tuyo, al lado

Lo que solo vale en tu repositorio va en ficheros con nombre propio, fuera de `.agents/`: por ejemplo `.github/instructions/proyecto.instructions.md`. Si una regla vale para todos, propónla al vault con un PR ([CONTRIBUTING.md](../CONTRIBUTING.md)).

## Si `/asset-review` no aparece en el vault

El vault activa su skill con `chat.agentSkillsLocations` en `.vscode/settings.json`, con una ruta relativa a la raíz del vault. Abre la carpeta del vault como raíz de VS Code (`code ~/workshop-coe-vault`), no una carpeta de encima.

Si tu versión de VS Code no acepta esa ruta, copia la skill a `.github/skills/`, que Copilot siempre lee. Esa copia está en `.gitignore`: no entra en tus commits. Repítela si la skill cambia:

```bash
cd ~/workshop-coe-vault
mkdir -p .github/skills && cp -R asset-sets/asset-kit/skills/asset-review .github/skills/
```
