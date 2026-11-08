#!/usr/bin/env bash
# Tests de verify.sh.
set -u
# shellcheck source=lib/testing.sh
. "$(dirname "$0")/lib/testing.sh"

VERIFY="$TEST_VAULT/tools/verify.sh"

out="$(bash "$VERIFY")"
assert_exit "el vault pasa" 0 $?
assert_contains "sin errores" "$(printf '%s\n' "$out" | tail -n 1)" "resultado: 0 errores"
assert_contains "avisa de back-core, en PROPOSED" "$out" "back-core está en PROPOSED: no se exporta hasta su primer merge"
assert_contains "y de front-cra, en DEPRECATED" "$out" "front-cra está en DEPRECATED: se exporta hasta 2027-06-30; su sucesor es front-react"
bash "$VERIFY" --help > /dev/null
assert_exit "--help" 0 $?
bash "$VERIFY" no-existe > /dev/null 2>&1
assert_exit "con un set que no existe" 2 $?

# Cada caso parte de una copia limpia, rompe una regla y espera salida 1 y el check que la nombra.
expect_error() { # descripción, check, fragmento del mensaje
  local out status
  out="$(bash "$copy/tools/verify.sh" 2>&1)"
  status=$?
  if [ "$status" -eq 1 ] && printf '%s\n' "$out" | grep -q "^error  $2 .*$3"; then
    pass "$1"
  else
    fail "$1" "salida $status, se esperaba «error  $2 … $3»:
$out"
  fi
}

copy="$(copy_vault)"
replace_in "$copy/asset-sets/front-react/manifest.json" '"name": "front-react"' '"name": "front-reactive"'
expect_error "name distinto de la carpeta" manifests "name es «front-reactive» y la carpeta, «front-react»"

copy="$(copy_vault)"
replace_in "$copy/asset-sets/front-react/manifest.json" '"dependencies"' '"dependecies"'
expect_error "clave desconocida" manifests "clave desconocida «dependecies»"
assert_contains "con una sugerencia" "$(bash "$copy/tools/verify.sh" 2>&1)" "¿querías decir «dependencies»?"

copy="$(copy_vault)"
replace_in "$copy/asset-sets/common-core/manifest.json" '"owner": "ai-coe"' '"owner": "ai-coe", "dependencies": ["front-react"]'
expect_error "ciclo en las dependencias" línea "ciclo en las dependencias"

copy="$(copy_vault)"
replace_in "$copy/asset-sets/front-react/manifest.json" '\["front-core"\]' '["front-base"]'
expect_error "base que no existe" línea "depende de front-base, que no existe"

copy="$(copy_vault)"
replace_in "$copy/asset-sets/qa-core/manifest.json" '\["dev-core"\]' '["back-core"]'
expect_error "un set ACTIVE sobre uno PROPOSED" estados "qa-core está en ACTIVE y depende de back-core, que está en PROPOSED"

copy="$(copy_vault)"
replace_in "$copy/asset-sets/front-cra/manifest.json" '"retireOn": "2027-06-30",' ''
expect_error "DEPRECATED sin retireOn" manifests "deprecation.retireOn tiene que ser una fecha"

copy="$(copy_vault)"
cp -R "$copy/asset-sets/common-core/skills/clarify-task" "$copy/asset-sets/qa-core/skills/"
expect_error "una skill repetida en dos sets" nombres "skill «clarify-task» está en dos sets: common-core, qa-core"

copy="$(copy_vault)"
skills="$copy/asset-sets/front-react/skills"
echo "- More in [missing.md](references/missing.md)" >> "$skills/react-best-practices/SKILL.md"
expect_error "un enlace roto" enlaces "el enlace references/missing.md no existe"

copy="$(copy_vault)"
echo "- Load the e2e-tests skill before you write a test." >> "$copy/asset-sets/front-react/instructions/react-components.instructions.md"
expect_error "una tirada fuera de la línea de dependencia" tiradas "nombra una skill de qa-core, que no está en la línea de dependencia de front-react"

copy="$(copy_vault)"
skills="$copy/asset-sets/front-react/skills"
echo "- Load the clarify-task skill when in doubt." >> "$skills/react-forms/SKILL.md"
expect_error "calls del manifest de skill que no coincide con SKILL.md" assets "calls (react-best-practices) no coincide"

copy="$(copy_vault)"
replace_in "$copy/asset-sets/qa-core/mcp.json" '"command": "npx",' '"command": "npx", "env": { "API_KEY": "abc123" },'
expect_error "un env con valor escrito" secretos "env API_KEY tiene un valor escrito"

copy="$(copy_vault)"
email="ana.garcia""@""empresa-real.es"
echo "Dudas: $email" >> "$copy/asset-sets/front-react/README.md"
expect_error "un email real" público "un email real no entra en el vault"

copy="$(copy_vault)"
host="https:/""/git.empresa-real.es/s""cm/equipo/repo.git"
echo "Origen: $host" >> "$copy/asset-sets/front-react/README.md"
expect_error "un host interno" público "nombra un servidor interno"

copy="$(copy_vault)"
replace_in "$copy/asset-sets/front-react/README.md" '^- dev-typescript$' '- dev-javascript'
expect_error "la línea de dependencia del README de un set ACTIVE" readmes "front-react/README.md: su línea de dependencia no coincide"

copy="$(copy_vault)"
mkdir -p "$copy/asset-sets/front-react/docs"
expect_error "una carpeta que un set no admite" carpetas "asset-sets/front-react/docs: un set solo admite"

# Un set con la forma del que propone la sala, tal como lo copia: sin owner, sin línea en el README y con un hook
# que nombra rutas de un repositorio. Pasa con avisos.
copy="$(copy_vault)"
set_dir="$copy/asset-sets/front-demo-states"
mkdir -p "$set_dir/skills/status-badges" "$set_dir/hooks" "$set_dir/instructions"
cat > "$set_dir/manifest.json" <<'JSON'
{
  "name": "front-demo-states",
  "description": "Loading and error states for React lists that read server data.",
  "version": "0.1.0",
  "kind": "asset-set",
  "status": "PROPOSED",
  "dependencies": ["front-react"]
}
JSON
printf '# front-demo-states\n\nEstados de las listas.\n' > "$set_dir/README.md"
printf -- '---\nname: status-badges\ndescription: Status badges for lists. Use when a list shows a status.\n---\n\n# Status badges\n\n1. Each badge has its text, not only a colour.\n' > "$set_dir/skills/status-badges/SKILL.md"
printf -- '---\ndescription: Lists\napplyTo: "src/**/*List.tsx"\n---\n\n- Load the status-badges skill and follow it.\n' > "$set_dir/instructions/lists.instructions.md"
cat > "$set_dir/hooks/check-lists.json" <<'JSON'
{ "version": 1, "hooks": { "Stop": [ { "type": "command", "command": "bash .github/skills/x/check.sh src/features/users/UsersPage.tsx", "timeout": 60 } ] } }
JSON
out="$(bash "$copy/tools/verify.sh")"
assert_exit "el set de la sala pasa" 0 $?
assert_eq "con cuatro avisos suyos" "4" "$(printf '%s\n' "$out" | grep -c '^aviso .*front-demo-states')"
assert_contains "uno, el del hook" "$out" "front-demo-states/hooks/check-lists.json nombra .github/ y src/"
assert_contains "otro, la línea que falta en el README" "$out" "front-demo-states/README.md no tiene «## Línea de dependencia»"
assert_contains "con el texto que hay que añadir" "$out" "                   - front-demo-states"
out="$(bash "$copy/tools/verify.sh" front-demo-states)"
assert_exit "verify de un solo set" 0 $?
assert_eq "solo informa de ese set" "resultado: 0 errores, 4 avisos" "$(printf '%s\n' "$out" | tail -n 1)"

VAULT_TODAY=2027-07-01 bash "$VERIFY" > "$TEST_TMP/late" 2>&1
assert_exit "con retireOn pasado, verify sigue pasando" 0 $?
assert_contains "y avisa de que hay que archivar o ampliar" "$(cat "$TEST_TMP/late")" "archívalo o amplía la fecha en un PR"

finish
