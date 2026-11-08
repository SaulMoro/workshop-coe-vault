#!/usr/bin/env bash
# verify.sh: comprueba el vault, sin red.
# Ayuda: verify.sh --help
set -u

HERE="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source=lib/vault.sh
. "$HERE/lib/vault.sh"

usage() {
  cat <<'EOF'
Uso: verify.sh [--root <vault>] [set...]
     verify.sh --help

Comprueba el vault sin red: manifests, línea de dependencia, estados, carpetas,
assets, nombres, enlaces, tiradas entre assets, READMEs, hooks, secretos e higiene pública.
Con uno o más sets, solo informa de ellos (los demás se leen para resolver dependencias).

Cada error dice dónde está, qué regla no cumple y cómo se arregla. Un aviso no bloquea.

Opciones:
  --root <vault>   el vault (por defecto, el que contiene este script)
  -h, --help       esta ayuda

Variables:
  VAULT_TODAY=AAAA-MM-DD   fecha con la que se compara retireOn (por defecto, hoy)

Salida: 0 sin errores (puede haber avisos) · 1 hay errores · 2 uso incorrecto
EOF
}

usage_error() {
  printf 'verify.sh: %s\nAyuda: verify.sh --help\n' "$1" >&2
  exit 2
}

ROOT=""
SELECTED=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help) usage; exit 0 ;;
    --root)
      [ $# -ge 2 ] || usage_error "--root necesita la ruta del vault"
      ROOT="$2"
      shift ;;
    --root=*) ROOT="${1#--root=}" ;;
    -*) usage_error "opción desconocida: $1" ;;
    *) SELECTED="$SELECTED${1%/} " ;;
  esac
  shift
done

[ -n "$ROOT" ] || ROOT="$HERE/.."
[ -d "$ROOT" ] || usage_error "no existe el vault $ROOT"
ROOT="$(cd "$ROOT" && pwd -P)"
[ -d "$ROOT/asset-sets" ] || usage_error "$ROOT no es un vault: no tiene asset-sets/"

vault_tmp
vault_load "$ROOT"
SETS_DIR="$ROOT/asset-sets"
ALL="$(vault_folders)"
FILTERED=0
if [ -n "$SELECTED" ]; then
  FILTERED=1
  for set in $SELECTED; do
    [ -d "$SETS_DIR/$set" ] || usage_error "no existe el set «$set» en asset-sets/"
  done
else
  SELECTED="$(printf '%s\n' "$ALL" | tr '\n' ' ')"
fi

TODAY="$(vault_today)"
TAB="$(printf '\t')"
ERRORS=0
WARNINGS=0
FINDINGS="$VAULT_TMP/findings"

error() { printf 'error\t%s\t%s\n' "$1" "${2:-}" >> "$FINDINGS"; }
warn() { printf 'aviso\t%s\t%s\n' "$1" "${2:-}" >> "$FINDINGS"; }

# Ejecuta un check y escribe sus hallazgos, o una línea «ok» si no hay ninguno.
run_check() { # nombre, mensaje si todo va bien, función
  local name="$1" ok_message="$2" level message fix
  : > "$FINDINGS"
  "$3"
  name="$(pad "$name" 11)"
  if [ ! -s "$FINDINGS" ]; then
    printf '%-6s %s %s\n' ok "$name" "$ok_message"
    return
  fi
  awk '!seen[$0]++' "$FINDINGS" > "$FINDINGS.unique"
  while IFS="$TAB" read -r level message fix; do
    printf '%-6s %s %s\n' "$level" "$name" "$message"
    # Una reparación de varias líneas llega con las líneas separadas por \037.
    if [ -n "$fix" ]; then printf '%s\n' "$fix" | tr '\037' '\n' | sed '/./s/^/                   /'; fi
    if [ "$level" = error ]; then ERRORS=$((ERRORS + 1)); else WARNINGS=$((WARNINGS + 1)); fi
  done < "$FINDINGS.unique"
}

selected() { case " $SELECTED " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# Assets de todo el vault: tipo TAB nombre TAB set
INVENTORY="$VAULT_TMP/inventory"
: > "$INVENTORY"
for set in $ALL; do
  setdir="$SETS_DIR/$set"
  for skill in "$setdir"/skills/*/; do
    [ -d "$skill" ] && printf 'skill\t%s\t%s\n' "$(basename "$skill")" "$set" >> "$INVENTORY"
  done
  for file in "$setdir"/instructions/*.instructions.md; do
    [ -f "$file" ] && printf 'instruction\t%s\t%s\n' "$(basename "$file" .instructions.md)" "$set" >> "$INVENTORY"
  done
  for file in "$setdir"/agents/*.agent.md; do
    [ -f "$file" ] && printf 'agent\t%s\t%s\n' "$(basename "$file" .agent.md)" "$set" >> "$INVENTORY"
  done
  for file in "$setdir"/hooks/*.json; do
    [ -f "$file" ] && printf 'hook\t%s\t%s\n' "$(basename "$file" .json)" "$set" >> "$INVENTORY"
  done
  if [ -f "$setdir/mcp.json" ]; then
    vault_json mcp "$setdir/mcp.json" 2>/dev/null | awk -F'\t' -v s="$set" '$1 == "server" { print "servidor MCP\t" $2 "\t" s }' >> "$INVENTORY"
  fi
done

# Línea de dependencia de un set (base primero), o vacío si no se puede calcular.
line_of() {
  if vault_line "$1"; then printf '%s' "$VAULT_LINE"; fi
}

skill_owner() {
  awk -F'\t' -v n="$1" '$1 == "skill" && $2 == n { print $3; exit }' "$INVENTORY"
}

# ------------------------------------------------------------------ checks

check_manifests() {
  local set level message fix
  if [ "$FILTERED" -eq 0 ]; then
    if [ ! -f "$ROOT/manifest.json" ]; then
      error "falta manifest.json en la raíz del vault" '→ añade { "name": "…", "kind": "vault", "description": "…" }'
    else
      vault_json root "$ROOT/manifest.json" | while IFS="$TAB" read -r level message; do
        [ "$level" = error ] && error "$message"
      done
    fi
  fi
  for set in $SELECTED; do
    awk -F'\t' -v s="$set" '($1 == "error" || $1 == "warn") && $2 == s { print $1 "\t" $3 "\t" $4 }' "$VAULT_TSV" |
      while IFS="$TAB" read -r level message fix; do
        [ -n "$fix" ] && fix="→ $fix"
        if [ "$level" = error ]; then error "$message" "$fix"; else warn "$message" "$fix"; fi
      done
  done
}

check_line() {
  local set
  for set in $SELECTED; do
    vault_has_set "$set" || continue
    vault_line "$set" || error "$VAULT_LINE_ERROR" "→ corrige dependencies en el manifest"
  done
}

check_states() {
  local set status dep dep_status retire successor
  for set in $SELECTED; do
    vault_has_set "$set" || continue
    status="$(vault_field "$set" status)"
    case "$status" in
      ACTIVE | DEPRECATED)
        for dep in $(vault_deps "$set"); do
          vault_has_set "$dep" || continue
          dep_status="$(vault_field "$dep" status)"
          case "$dep_status" in
            ACTIVE) ;;
            DEPRECATED) warn "$set depende de $dep, que está en DEPRECATED hasta $(vault_field "$dep" retireOn)" ;;
            *) error "$set está en $status y depende de $dep, que está en $dep_status: no se podría exportar" "→ deja $set en PROPOSED o activa antes $dep" ;;
          esac
        done ;;
    esac
    case "$status" in
      PROPOSED) warn "$set está en PROPOSED: no se exporta hasta su primer merge" ;;
      SUSPENDED) warn "$set está en SUSPENDED: no se exporta ($(vault_field "$set" suspension))" ;;
      DEPRECATED)
        retire="$(vault_field "$set" retireOn)"
        successor="$(vault_field "$set" replacedBy | sed 's/,/, /g')"
        if [ -n "$retire" ] && [ "$TODAY" \> "$retire" ]; then
          warn "$set: su retireOn, $retire, ya pasó y no se exporta" "→ archívalo o amplía la fecha en un PR"
        else
          warn "$set está en DEPRECATED: se exporta hasta $retire${successor:+; su sucesor es $successor}"
        fi
        for dep in $(vault_field "$set" replacedBy | tr ',' ' '); do
          if ! vault_has_set "$dep"; then
            error "asset-sets/$set/manifest.json: replacedBy nombra $dep, que no existe"
          elif [ "$(vault_field "$dep" status)" != ACTIVE ]; then
            error "asset-sets/$set/manifest.json: replacedBy nombra $dep, que no está en ACTIVE"
          fi
        done ;;
    esac
  done
}

check_folders() {
  local set setdir entry name
  for set in $SELECTED; do
    setdir="$SETS_DIR/$set"
    [ -f "$setdir/README.md" ] || error "asset-sets/$set: falta README.md" "→ añade su propósito y «## Línea de dependencia»"
    for entry in "$setdir"/* "$setdir"/.[!.]*; do
      [ -e "$entry" ] || continue
      name="$(basename "$entry")"
      case "$name" in
        manifest.json | README.md | mcp.json | .DS_Store) ;;
        skills | instructions | agents | hooks) [ -d "$entry" ] || error "asset-sets/$set/$name tiene que ser una carpeta" ;;
        *) error "asset-sets/$set/$name: un set solo admite manifest.json, README.md, skills/, instructions/, agents/, hooks/ y mcp.json" "→ muévelo dentro de una skill o fuera del set" ;;
      esac
    done
    if [ -d "$setdir/skills" ]; then
      for entry in "$setdir"/skills/*; do
        [ -e "$entry" ] || continue
        if [ ! -d "$entry" ]; then error "asset-sets/$set/skills/$(basename "$entry"): en skills/ solo van carpetas, una por skill"; continue; fi
        [ -f "$entry/SKILL.md" ] || error "asset-sets/$set/skills/$(basename "$entry"): falta SKILL.md"
      done
    fi
    if [ -d "$setdir/instructions" ]; then
      for entry in "$setdir"/instructions/*; do
        [ -e "$entry" ] || continue
        case "$(basename "$entry")" in
          *.instructions.md) ;;
          *) error "asset-sets/$set/instructions/$(basename "$entry"): una instruction se llama <nombre>.instructions.md" ;;
        esac
      done
    fi
    if [ -d "$setdir/agents" ]; then
      for entry in "$setdir"/agents/*; do
        [ -e "$entry" ] || continue
        case "$(basename "$entry")" in
          *.agent.md) ;;
          *) error "asset-sets/$set/agents/$(basename "$entry"): un agent se llama <nombre>.agent.md" ;;
        esac
      done
    fi
  done
}

ASSET_COUNT=0
check_assets() {
  local set setdir skill file name description apply output calls topic phrases line member
  for set in $SELECTED; do
    setdir="$SETS_DIR/$set"
    for skill in "$setdir"/skills/*/; do
      [ -f "$skill/SKILL.md" ] || continue
      ASSET_COUNT=$((ASSET_COUNT + 1))
      name="$(basename "$skill")"
      file="asset-sets/$set/skills/$name/SKILL.md"
      if ! fm_present "$skill/SKILL.md"; then error "$file: no tiene frontmatter" "→ empieza con --- name: $name / description: … ---"; continue; fi
      [ "$(fm_get "$skill/SKILL.md" name)" = "$name" ] || error "$file: name tiene que ser «$name», como su carpeta"
      description="$(fm_get "$skill/SKILL.md" description)"
      if [ -z "$description" ]; then
        error "$file: falta description" "→ di qué hace y cuándo se usa: «… Use when …»"
      elif [ "${#description}" -gt 1024 ]; then
        error "$file: description tiene más de 1024 caracteres"
      fi
      if [ -f "$skill/manifest.json" ]; then
        if ! output="$(vault_json skill-manifest "$skill/manifest.json")"; then
          error "asset-sets/$set/skills/$name/manifest.json: $(printf '%s' "$output" | head -n 1 | cut -f2)"
          continue
        fi
        printf '%s\n' "$output" | awk -F'\t' '$1 == "error" { print $2 }' | while IFS= read -r line; do
          error "asset-sets/$set/skills/$name/manifest.json: $line"
        done
        [ "$(printf '%s\n' "$output" | awk -F'\t' '$1 == "name" { print $2 }')" = "$name" ] ||
          error "asset-sets/$set/skills/$name/manifest.json: name tiene que ser «$name»"
        calls="$(printf '%s\n' "$output" | awk -F'\t' '$1 == "calls" { print $2 }' | tr ',' '\n' | sed '/^$/d' | sorted -u | tr '\n' ' ')"
        phrases="$(load_phrases "$skill/SKILL.md" | tr '\n' ' ')"
        [ "$calls" = "$phrases" ] ||
          error "asset-sets/$set/skills/$name/manifest.json: calls (${calls% }) no coincide con las frases «Load the … skill» de SKILL.md (${phrases% })" "→ que digan las mismas skills"
        line="$(line_of "$set")"
        for member in $calls; do
          case "
$line
" in
            *"
$(skill_owner "$member")
"*) ;;
            *) error "asset-sets/$set/skills/$name/manifest.json: calls nombra $member, que no está en la línea de dependencia de $set" ;;
          esac
        done
      fi
    done
    for file in "$setdir"/instructions/*.instructions.md; do
      [ -f "$file" ] || continue
      ASSET_COUNT=$((ASSET_COUNT + 1))
      name="asset-sets/$set/instructions/$(basename "$file")"
      if ! fm_present "$file"; then error "$name: no tiene frontmatter" "→ empieza con --- description: … / applyTo: \"…\" ---"; continue; fi
      apply="$(fm_get "$file" applyTo)"
      [ -n "$apply" ] || error "$name: falta applyTo" "→ por ejemplo applyTo: \"src/**/*.tsx\""
      [ -n "$(fm_get "$file" description)" ] || error "$name: falta description"
    done
    for file in "$setdir"/agents/*.agent.md; do
      [ -f "$file" ] || continue
      ASSET_COUNT=$((ASSET_COUNT + 1))
      name="asset-sets/$set/agents/$(basename "$file")"
      if ! fm_present "$file"; then error "$name: no tiene frontmatter"; continue; fi
      [ "$(fm_get "$file" name)" = "$(basename "$file" .agent.md)" ] || error "$name: name tiene que ser «$(basename "$file" .agent.md)», como el fichero"
      [ -n "$(fm_get "$file" description)" ] || error "$name: falta description"
    done
    for file in "$setdir"/hooks/*.json; do
      [ -f "$file" ] || continue
      ASSET_COUNT=$((ASSET_COUNT + 1))
      if ! output="$(vault_json hook "$file" 2>&1)"; then
        error "asset-sets/$set/hooks/$(basename "$file"): ${output##*: }" "→ un hook es { \"version\": 1, \"hooks\": { \"Stop\": [ … ] } }"
      fi
    done
    if [ -f "$setdir/mcp.json" ]; then
      ASSET_COUNT=$((ASSET_COUNT + 1))
      if ! output="$(vault_json mcp "$setdir/mcp.json" 2>&1)"; then
        error "asset-sets/$set/mcp.json: ${output##*: }" "→ un mcp.json es { \"mcpServers\": { \"<nombre>\": { … } } }"
      fi
    fi
  done
}

check_names() {
  awk -F'\t' '{ key = $1 "\t" $2; sets[key] = sets[key] (sets[key] == "" ? "" : ", ") $3; n[key]++ }
    END { for (k in n) if (n[k] > 1) { split(k, p, "\t"); print p[1] "\t" p[2] "\t" sets[k] } }' "$INVENTORY" |
    sorted | while IFS="$TAB" read -r kind name sets; do
      for set in $(printf '%s' "$sets" | tr ',' ' '); do
        if selected "$set"; then
          error "$kind «$name» está en dos sets: $sets" "→ un nombre no se repite en el vault: renombra uno"
          break
        fi
      done
    done
}

check_links() {
  local set skill skill_root md md_dir link resolved
  for set in $SELECTED; do
    for skill in "$SETS_DIR/$set"/skills/*/; do
      [ -d "$skill" ] || continue
      skill_root="$(cd "$skill" && pwd -P)"
      while IFS= read -r md; do
        [ -n "$md" ] || continue
        md_dir="$(dirname "$md")"
        for link in $(md_links "$md"); do
          if [ ! -e "$md_dir/$link" ]; then
            error "${md#"$ROOT"/}: el enlace $link no existe"
            continue
          fi
          resolved="$(cd "$(dirname "$md_dir/$link")" && pwd -P)"
          case "$resolved/" in
            "$skill_root/"*) ;;
            *) error "${md#"$ROOT"/}: el enlace $link sale de la carpeta de la skill" "→ el export solo copia la carpeta de la skill: mueve el fichero dentro" ;;
          esac
        done
      done <<EOF
$(find "$skill" -type f -name '*.md' | sorted)
EOF
    done
  done
}

check_pulls() {
  local set line file name owner
  for set in $SELECTED; do
    vault_has_set "$set" || continue
    line="$(line_of "$set")"
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      for name in $(load_phrases "$file"); do
        owner="$(skill_owner "$name")"
        if [ -z "$owner" ]; then
          error "${file#"$ROOT"/}: «Load the $name skill» nombra una skill que no existe en el vault"
          continue
        fi
        case "
$line
" in
          *"
$owner
"*) ;;
          *) error "${file#"$ROOT"/}: «Load the $name skill» nombra una skill de $owner, que no está en la línea de dependencia de $set" "→ añade la dependencia en el manifest o lleva la skill a la línea" ;;
        esac
      done
    done <<EOF
$(find "$SETS_DIR/$set/skills" "$SETS_DIR/$set/instructions" "$SETS_DIR/$set/agents" -type f -name '*.md' 2>/dev/null | sorted)
EOF
  done
}

# La línea de dependencia de un README va bajo «## Línea de dependencia», de la hoja a la base:
# un set por elemento de lista, o los sets en un solo elemento separados por «→».
check_readmes() {
  local set status readme as_list as_line found suggestion
  for set in $SELECTED; do
    readme="$SETS_DIR/$set/README.md"
    [ -f "$readme" ] || continue
    vault_has_set "$set" || continue
    vault_line "$set" || continue
    as_list="$(printf '%s' "$VAULT_LINE" | awk 'NF { l[++n] = $0 } END { for (k = n; k >= 1; k--) printf "%s%s", l[k], (k > 1 ? "|" : "") }')"
    as_line="$VAULT_LINE_TEXT"
    status="$(vault_field "$set" status)"
    found="$(awk '
      { sub(/\r$/, "") }
      /^## (Línea de dependencia|Dependency line)[ \t]*$/ { inside = 1; seen = 1; next }
      inside && /^#/ { exit }
      inside && /^[-*] / { item = substr($0, 3); gsub(/`/, "", item); sub(/[ \t]+$/, "", item); out = out (n++ ? "|" : "") item; next }
      inside && n && /[^ \t]/ { exit }
      END { if (!seen) print "<none>"; else print out }' "$readme")"
    if [ "$found" = "$as_list" ] || [ "$found" = "$as_line" ]; then continue; fi
    if [ "$found" = "<none>" ]; then
      message="$set/README.md no tiene «## Línea de dependencia». Añade, de la hoja a la base:"
    else
      message="$set/README.md: su línea de dependencia no coincide con los manifests. Debe ser, de la hoja a la base:"
    fi
    suggestion="## Línea de dependencia$(printf '\037')$(printf '\037')- $(printf '%s' "$as_list" | sed "s/|/$(printf '\037')- /g")"
    case "$status" in
      ACTIVE | DEPRECATED) error "$message" "$suggestion" ;;
      *) warn "$message" "$suggestion" ;;
    esac
  done
}

check_hooks() {
  local set file type event value rest outside path
  for set in $SELECTED; do
    for file in "$SETS_DIR/$set"/hooks/*.json; do
      [ -f "$file" ] || continue
      outside=""
      while IFS="$TAB" read -r type event value rest; do
        [ "$type" = command ] || continue
        for path in $(command_paths "$value"); do
          case "$path" in
            .agents/*) ;;
            /*) outside="$outside $path" ;;
            */*) outside="$outside ${path%%/*}/" ;;
          esac
        done
      done <<EOF
$(vault_json hook "$file" 2>/dev/null)
EOF
      if [ -n "$outside" ]; then
        outside="$(printf '%s\n' $outside | awk '!seen[$0]++' | awk '{ l[++n] = $0 } END { for (k = 1; k <= n; k++) printf "%s%s", l[k], (k < n - 1 ? ", " : (k == n - 1 ? " y " : "")) }')"
        warn "$set/hooks/$(basename "$file") nombra $outside: solo existen en un repositorio concreto" "→ un hook del vault solo nombra rutas que crea el export (.agents/…)"
      fi
    done
  done
}

check_secrets() {
  local set file type a b c
  for set in $SELECTED; do
    for file in "$SETS_DIR/$set"/hooks/*.json "$SETS_DIR/$set/mcp.json"; do
      [ -f "$file" ] || continue
      case "$file" in *mcp.json) kind=mcp ;; *) kind=hook ;; esac
      while IFS="$TAB" read -r type a b c; do
        [ "$type" = env ] || continue
        case "$c" in
          '${'*'}') ;;
          *) error "${file#"$ROOT"/}: env $b tiene un valor escrito" "→ usa \${$b} o \${input:…}: un secreto nunca va escrito" ;;
        esac
      done <<EOF
$(vault_json "$kind" "$file" 2>/dev/null)
EOF
    done
  done
}

ALLOWED_HOSTS="github.com react.dev developer.mozilla.org www.typescriptlang.org playwright.dev vite.dev www.npmjs.com example.com localhost www.conventionalcommits.org"

check_public() {
  local list="$VAULT_TMP/public-files" set hit file host
  if [ "$FILTERED" -eq 1 ]; then
    : > "$list"
    for set in $SELECTED; do find "$SETS_DIR/$set" -type f >> "$list"; done
  else
    find "$ROOT" -type f ! -path '*/.git/*' ! -path '*/node_modules/*' > "$list"
  fi
  sorted -o "$list" "$list"
  # Emails
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    error "${hit#"$ROOT"/}: un email real no entra en el vault" "→ quítalo, o usa uno de example.com"
  done <<EOF
$(tr '\n' '\0' < "$list" | xargs -0 grep -IHnoE '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}' 2>/dev/null | grep -vE '@(example\.(com|org|net)|users\.noreply\.github\.com)$')
EOF
  # Tokens y claves
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    error "${hit%%:*}:$(printf '%s' "$hit" | cut -d: -f2): parece un token o una clave privada" "→ quítalo y revócalo: lo que se sube a git queda en la historia"
  done <<EOF
$(tr '\n' '\0' < "$list" | xargs -0 grep -IHnE 'ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16}|xox[abprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE''[ ]KEY-----' 2>/dev/null | sed "s#^$ROOT/##")
EOF
  # Hosts y rutas de servidores internos
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    error "${hit%%:*}:$(printf '%s' "$hit" | cut -d: -f2): nombra un servidor interno" "→ usa github.com o example.com"
  done <<EOF
$(tr '\n' '\0' < "$list" | xargs -0 grep -IHnE 'https?://(git|jira|confluence|bitbucket|wiki|intranet|nexus|artifactory|sonar)\.|/scm/[^ /]+/|/projects/[^ /]+/repos/' 2>/dev/null | sed "s#^$ROOT/##")
EOF
  # URLs con hosts fuera de la lista conocida
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    file="${hit%%:*}"
    host="$(printf '%s' "$hit" | sed -E 's#^[^:]*:[0-9]+:https?://##; s#[/:].*$##')"
    case " $ALLOWED_HOSTS " in *" $host "*) continue ;; esac
    warn "$file: enlaza a $host, que no está en la lista de hosts conocidos" "→ si es documentación pública, añádelo a ALLOWED_HOSTS en tools/verify.sh"
  done <<EOF
$(tr '\n' '\0' < "$list" | xargs -0 grep -IHnoE 'https?://[A-Za-z0-9.-]+' 2>/dev/null | sed "s#^$ROOT/##")
EOF
}

# ------------------------------------------------------------------ main

count=0
for set in $SELECTED; do count=$((count + 1)); done
total=0
for set in $ALL; do total=$((total + 1)); done
if [ "$FILTERED" -eq 1 ]; then
  printf 'verify.sh · %s (%s de %s sets en asset-sets/)\n' "$(printf '%s' "$SELECTED" | sed 's/ $//')" "$count" "$total"
else
  if [ "$total" -eq 1 ]; then printf 'verify.sh · 1 set en asset-sets/\n'; else printf 'verify.sh · %s sets en asset-sets/\n' "$total"; fi
fi

manifests_ok=0
for set in $SELECTED; do vault_has_set "$set" && manifests_ok=$((manifests_ok + 1)); done

if [ "$manifests_ok" -eq 1 ]; then manifests_text="1 manifest válido"; else manifests_text="$manifests_ok manifests válidos"; fi
run_check manifests "$manifests_text" check_manifests
run_check línea "sin ciclos ni bases que no existen" check_line
run_check estados "cada set se apoya en sets que se exportan" check_states
run_check carpetas "cada set tiene solo lo que admite un set" check_folders
: > "$FINDINGS"
check_assets
ASSETS_FINDINGS="$(cat "$FINDINGS")"
replay_assets() { printf '%s' "$ASSETS_FINDINGS" | sed '/^$/d' > "$FINDINGS"; }
if [ "$ASSET_COUNT" -eq 1 ]; then assets_text="1 asset con frontmatter correcto"; else assets_text="$ASSET_COUNT assets con frontmatter correcto"; fi
run_check assets "$assets_text" replay_assets
run_check nombres "ningún nombre repetido" check_names
run_check enlaces "cada enlace relativo apunta dentro de su skill" check_links
run_check tiradas "cada «Load the … skill» encuentra la skill en su línea de dependencia" check_pulls
run_check readmes "la línea de dependencia de cada README coincide con los manifests" check_readmes
run_check hooks "cada hook nombra solo rutas de .agents/" check_hooks
run_check secretos "ningún env con un valor escrito" check_secrets
run_check público "sin emails, tokens ni hosts internos" check_public

if [ "$ERRORS" -eq 1 ]; then e="1 error"; else e="$ERRORS errores"; fi
if [ "$WARNINGS" -eq 1 ]; then w="1 aviso"; else w="$WARNINGS avisos"; fi
printf 'resultado: %s, %s\n' "$e" "$w"
[ "$ERRORS" -eq 0 ]
