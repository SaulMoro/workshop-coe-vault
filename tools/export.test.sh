#!/usr/bin/env bash
# Tests de export.sh.
set -u
# shellcheck source=lib/testing.sh
. "$(dirname "$0")/lib/testing.sh"

EXPORT="$TEST_VAULT/tools/export.sh"
# La línea de dependencia de front-react, desde la base.
LINE='common-core → dev-core → dev-typescript'
LINE="$LINE → front-core → front-react"

# ------------------------------------------------------------------ uso

out="$(bash "$EXPORT" --help)"
assert_exit "--help" 0 $?
assert_contains "--help explica el uso" "$out" "Uso: export.sh [--root <vault>] <set> <destino>"
bash "$EXPORT" > /dev/null 2>&1
assert_exit "sin argumentos" 2 $?
err="$(bash "$EXPORT" no-existe "$TEST_TMP/x" 2>&1)"
assert_exit "con un set que no existe" 2 $?
assert_contains "y lista los sets que hay" "$err" "front-react"
bash "$EXPORT" front-react "$TEST_VAULT/asset-sets/.agents" > /dev/null 2>&1
assert_exit "con un destino dentro del vault" 2 $?
assert_no_file "y no crea el destino" "$TEST_VAULT/asset-sets/.agents"

out="$(bash "$EXPORT" --list)"
summary="$(printf '%s\n' "$out" | tail -n 1)"
case "$summary" in
  *" sets · se exportan "*) pass "--list termina con el resumen: $summary" ;;
  *) fail "--list termina con el resumen" "$summary" ;;
esac
assert_contains "--list marca back-core como PROPOSED" "$out" "back-core        PROPOSED"
leaf_first='front-react → front-core → dev-typescript'
leaf_first="$leaf_first → dev-core → common-core"
assert_contains "--list da la línea de dependencia de la hoja a la base" "$out" "$leaf_first"

# ------------------------------------------------------------------ front-react

dest="$TEST_TMP/repo/.agents"
mkdir -p "$TEST_TMP/repo"
out="$(cd "$TEST_TMP/repo" && bash "$EXPORT" --root "$TEST_VAULT" front-react .agents)"
assert_exit "front-react se exporta" 0 $?
assert_contains "recorre la línea de dependencia desde la base" "$out" "$LINE"
assert_contains "imprime la auditoría con el script de react-check" "$out" ".agents/skills/react-check/scripts/scan-components.sh"
assert_eq "la última línea es el resumen estable" \
  "export.sh: front-react → .agents · 6 skills (1 compuesta de 4) · 4 instructions · 1 agent · 0 hooks · 0 MCP" \
  "$(printf '%s\n' "$out" | tail -n 1)"
audit_at="$(printf '%s\n' "$out" | grep -n 'AUDITORÍA' | cut -d: -f1)"
write_at="$(printf '%s\n' "$out" | grep -n '· escribe en' | cut -d: -f1)"
[ "$audit_at" -lt "$write_at" ]
assert_exit "la auditoría sale antes de escribir" 0 $?

assert_eq "el SKILL.md compuesto se llama react-best-practices" "react-best-practices" \
  "$(sed -n 's/^name: //p' "$dest/skills/react-best-practices/SKILL.md")"
assert_file "las fuentes van en sources/" "$dest/skills/react-best-practices/sources/dev-best-practices/references/naming.md"
assert_file "la instruction de componentes" "$dest/instructions/react-components.instructions.md"
assert_file "el agent" "$dest/agents/react-reviewer.agent.md"
assert_file "AGENTS.md" "$dest/AGENTS.md"
assert_no_file "no quedan las skills absorbidas" "$dest/skills/dev-best-practices"
assert_no_file "sin hooks" "$dest/hooks"
assert_no_file "sin mcp.json" "$dest/mcp.json"
assert_no_file "sin el manifest de skill de react-forms" "$dest/skills/react-forms/manifest.json"
assert_contains "los enlaces de las fuentes apuntan a sources/" \
  "$(cat "$dest/skills/react-best-practices/SKILL.md")" "(sources/typescript-best-practices/references/strict-types.md)"

all="$(find "$dest" -type f -name '*.md' -exec cat {} +)"
assert_not_contains "ningún fichero tira de front-best-practices" "$all" "Load the front-best-practices skill"
assert_contains "dev-tests tira del compuesto" "$(cat "$dest/instructions/dev-tests.instructions.md")" "Load the react-best-practices skill"
# La regla de estado derivado llega en front-react 1.1.0 (tag front-react-1.1.0).
if grep -q '"version": "1.0.0"' "$TEST_VAULT/asset-sets/front-react/manifest.json"; then
  assert_not_contains "front-react 1.0.0 no trae la regla de estado derivado" "$all" "Derived state"
else
  assert_contains "front-react 1.1.0 trae la regla de estado derivado" "$all" "Derived state is computed during render"
fi
assert_contains "AGENTS.md agrupa cada instruction por su applyTo" "$(cat "$dest/AGENTS.md")" '## When you edit files matching `src/**/*.tsx`'

# ------------------------------------------------------------------ reexportar

echo "- Mi cambio." >> "$dest/skills/react-best-practices/SKILL.md"
printf -- '---\ndescription: mine\napplyTo: "**"\n---\n\n- Mine.\n' > "$dest/instructions/mine.instructions.md"
out2="$(cd "$TEST_TMP/repo" && bash "$EXPORT" --root "$TEST_VAULT" front-react .agents)"
assert_not_contains "reexportar restaura el SKILL.md editado" "$(cat "$dest/skills/react-best-practices/SKILL.md")" "Mi cambio"
assert_file "y conserva lo que no escribe" "$dest/instructions/mine.instructions.md"
assert_contains "y avisa de lo que no ha escrito" "$out2" "instructions/mine.instructions.md"
rm "$dest/instructions/mine.instructions.md"
out3="$(cd "$TEST_TMP/repo" && bash "$EXPORT" --root "$TEST_VAULT" front-react .agents)"
assert_eq "dos exports seguidos imprimen lo mismo" "$out" "$out3"

# ------------------------------------------------------------------ determinismo

copy="$(copy_vault)"
(cd "$TEST_TMP" && bash "$EXPORT" --root "$TEST_VAULT" front-react "$TEST_TMP/a" > /dev/null)
(cd "$TEST_TMP" && bash "$copy/tools/export.sh" front-react "$TEST_TMP/b" > /dev/null)
diff -r "$TEST_TMP/a" "$TEST_TMP/b" > /dev/null
assert_exit "el mismo vault, con o sin .git, da los mismos bytes" 0 $?
diff -r "$TEST_TMP/a" "$dest" > /dev/null
assert_exit "y lo mismo que el export a .agents" 0 $?

# ------------------------------------------------------------------ estados

bash "$EXPORT" back-core "$TEST_TMP/back" > /dev/null 2>&1
assert_exit "un set PROPOSED no se exporta" 1 $?
assert_no_file "y no crea el destino" "$TEST_TMP/back"

for status in SUSPENDED ARCHIVED; do
  copy="$(copy_vault)"
  manifest="$copy/asset-sets/front-core/manifest.json"
  if [ "$status" = SUSPENDED ]; then
    replace_in "$manifest" '"status": "ACTIVE",' '"status": "SUSPENDED", "suspension": { "reason": "En revisión." },'
  else
    replace_in "$manifest" '"status": "ACTIVE"' '"status": "ARCHIVED"'
  fi
  err="$(bash "$copy/tools/export.sh" front-react "$TEST_TMP/s-$status" 2>&1 > /dev/null)"
  assert_exit "una base $status para la línea de dependencia" 1 $?
  assert_contains "y nombra el set y su estado" "$err" "front-core está en $status"
  assert_no_file "y no crea el destino" "$TEST_TMP/s-$status"
done

VAULT_TODAY=2027-06-30 bash "$EXPORT" front-cra "$TEST_TMP/cra-a" > /dev/null 2>&1
assert_exit "DEPRECATED se exporta el día de su retireOn" 0 $?
err="$(VAULT_TODAY=2027-07-01 bash "$EXPORT" front-cra "$TEST_TMP/cra-b" 2>&1 > /dev/null)"
assert_exit "DEPRECATED no se exporta el día siguiente" 1 $?
assert_contains "y nombra a su sucesor" "$err" "Su sucesor es front-react."

# ------------------------------------------------------------------ MCP, hooks y ciclos

out="$(bash "$EXPORT" qa-core "$TEST_TMP/qa")"
assert_contains "qa-core junta su mcp.json" "$(cat "$TEST_TMP/qa/mcp.json")" '"playwright"'
assert_contains "y la auditoría lista el servidor" "$out" "playwright: npx -y @playwright/mcp@"

copy="$(copy_vault)"
cat > "$copy/asset-sets/qa-core/mcp.json" <<'JSON'
{ "mcpServers": { "tracker": { "command": "npx", "args": ["-y", "tracker-mcp@1.0.0"], "env": { "TRACKER_TOKEN": "abc123" } } } }
JSON
err="$(bash "$copy/tools/export.sh" qa-core "$TEST_TMP/qa-env" 2>&1 > /dev/null)"
assert_exit "un env con valor escrito para el export" 1 $?
assert_contains "y dice cómo arreglarlo" "$err" 'Usa ${TRACKER_TOKEN}'
assert_no_file "y no crea el destino" "$TEST_TMP/qa-env"

copy="$(copy_vault)"
cp "$copy/asset-sets/qa-core/mcp.json" "$copy/asset-sets/dev-core/mcp.json"
bash "$copy/tools/export.sh" qa-core "$TEST_TMP/qa-dup" > /dev/null 2>&1
assert_exit "un servidor MCP en dos sets de la línea" 1 $?

copy="$(copy_vault)"
replace_in "$copy/asset-sets/asset-kit/hooks/check-on-stop.json" 'bash \.agents/hooks/' 'bash .github/hooks/'
err="$(bash "$copy/tools/export.sh" asset-kit "$TEST_TMP/kit" 2>&1 > /dev/null)"
assert_exit "un hook que apunta a .github/" 1 $?
assert_contains "y propone la reparación" "$err" "llámalo como .agents/hooks/<script>"

copy="$(copy_vault)"
replace_in "$copy/asset-sets/common-core/manifest.json" '"owner": "ai-coe"' '"owner": "ai-coe", "dependencies": ["front-react"]'
err="$(bash "$copy/tools/export.sh" front-react "$TEST_TMP/cycle" 2>&1 > /dev/null)"
assert_exit "un ciclo en las dependencias" 1 $?
assert_contains "y lo enseña" "$err" "ciclo en las dependencias"

finish
