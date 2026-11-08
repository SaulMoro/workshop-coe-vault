#!/usr/bin/env bash
# export.sh: exporta la línea de dependencia entera de un set a un destino, por ejemplo .agents.
# Ayuda: export.sh --help
set -u

HERE="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source=lib/vault.sh
. "$HERE/lib/vault.sh"

usage() {
  cat <<'EOF'
Uso: export.sh [--root <vault>] <set> <destino>
     export.sh [--root <vault>] --list
     export.sh --help

Exporta la línea de dependencia entera de <set> a <destino>, por ejemplo .agents.
Ejecútalo desde la raíz de tu repositorio.

  1. Recorre la línea de dependencia desde la base. Cada set entra una vez.
  2. Lee el estado de cada set. Se exporta un set ACTIVE, o DEPRECATED hasta su retireOn.
     Si uno no se puede exportar, para y no escribe nada.
  3. Junta las skills *-best-practices de la línea en una sola, con el nombre de la más específica.
  4. Monta el resultado en un directorio temporal y lo comprueba.
  5. Imprime la auditoría: lo que se ejecutará en tu máquina.
  6. Solo entonces escribe en <destino>.

Escribe en <destino>:
  skills/<nombre>/                 una carpeta por skill
  instructions/*.instructions.md   una por instruction, con su applyTo
  agents/*.agent.md                uno por agent
  hooks/                           declaraciones y scripts, sin cambios
  mcp.json                         los servidores MCP de la línea, juntos
  AGENTS.md                        las instructions en un solo fichero, para clientes sin applyTo

Sobrescribe lo que escribe y no borra nada más. Dos exports del mismo commit dan los mismos bytes.

Opciones:
  --root <vault>   el vault (por defecto, el que contiene este script)
  --list           los sets, su estado, su owner y su línea de dependencia
  -h, --help       esta ayuda

Variables:
  VAULT_TODAY=AAAA-MM-DD   fecha con la que se compara retireOn (por defecto, hoy)

Salida: 0 exportado · 1 no se exporta nada · 2 uso incorrecto
EOF
}

usage_error() {
  printf 'export.sh: %s\n' "$1" >&2
  shift
  for detail in "$@"; do printf '  %s\n' "$detail" >&2; done
  printf 'Ayuda: export.sh --help\n' >&2
  exit 2
}

# Cada argumento puede traer varias líneas: se imprimen todas, sangradas.
nothing_exported() {
  printf 'export.sh: no se exporta nada.\n' >&2
  for text in "$@"; do printf '%s\n' "$text" | sed -e '/^$/d' -e 's/^/  /' >&2; done
  exit 1
}

plural() { # n singular plural
  if [ "$1" -eq 1 ]; then printf '%s %s' "$1" "$2"; else printf '%s %s' "$1" "$3"; fi
}

# Ruta absoluta de un destino que puede no existir todavía.
absolute_path() {
  local path="$1" rest=""
  case "$path" in
    /* | [A-Za-z]:*) ;;
    *) path="$PWD/$path" ;;
  esac
  while [ ! -d "$path" ]; do
    rest="/$(basename "$path")$rest"
    path="$(dirname "$path")"
  done
  printf '%s%s\n' "$(cd "$path" && pwd -P)" "$rest"
}

# ------------------------------------------------------------------ argumentos

ROOT=""
LIST=0
NARGS=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help) usage; exit 0 ;;
    --list) LIST=1 ;;
    --root)
      [ $# -ge 2 ] || usage_error "--root necesita la ruta del vault"
      ROOT="$2"
      shift ;;
    --root=*) ROOT="${1#--root=}" ;;
    -*) usage_error "opción desconocida: $1" ;;
    *)
      NARGS=$((NARGS + 1))
      if [ "$NARGS" -eq 1 ]; then SET="$1"; else DEST_ARG="$1"; fi ;;
  esac
  shift
done

[ -n "$ROOT" ] || ROOT="$HERE/.."
[ -d "$ROOT" ] || usage_error "no existe el vault $ROOT"
ROOT="$(cd "$ROOT" && pwd -P)"
[ -d "$ROOT/asset-sets" ] || usage_error "$ROOT no es un vault: no tiene asset-sets/"

vault_tmp
vault_load "$ROOT"

# ------------------------------------------------------------------ --list

if [ "$LIST" -eq 1 ]; then
  [ "$NARGS" -eq 0 ] || usage_error "--list no lleva más argumentos"
  total=0
  exportable=0
  printf '%-16s %-12s %-14s %s\n' "SET" "ESTADO" "OWNER" "LÍNEA DE DEPENDENCIA"
  for set in $(vault_folders); do
    total=$((total + 1))
    if ! vault_has_set "$set"; then
      printf '%-16s %-12s %-14s %s\n' "$set" "?" "?" "(el manifest tiene errores: tools/verify.sh)"
      continue
    fi
    status="$(vault_field "$set" status)"
    owner="$(vault_field "$set" owner)"
    note=""
    if vault_line "$set"; then
      text="$VAULT_LINE_TEXT"
      ok=1
      for member in $VAULT_LINE; do vault_gate "$member" || ok=0; done
      [ "$ok" -eq 1 ] && exportable=$((exportable + 1))
      if [ "$status" = DEPRECATED ]; then note="   (hasta $(vault_field "$set" retireOn))"; fi
    else
      text="($VAULT_LINE_ERROR)"
    fi
    printf '%-16s %-12s %-14s %s%s\n' "$set" "${status:-?}" "${owner:-—}" "$text" "$note"
  done
  printf '%s · se exportan %s\n' "$(plural "$total" set sets)" "$exportable"
  exit 0
fi

# ------------------------------------------------------------------ set y destino

[ "$NARGS" -eq 2 ] || usage_error "indica un set y un destino, por ejemplo: export.sh front-react .agents"

if [ ! -d "$ROOT/asset-sets/$SET" ]; then
  usage_error "no existe el set «$SET». Los sets del vault son:" "$(vault_folders | tr '\n' ' ')"
fi

DEST_SHOW="${DEST_ARG%/}"
[ -n "$DEST_SHOW" ] || DEST_SHOW="/"
if [ -e "$DEST_ARG" ] && [ ! -d "$DEST_ARG" ]; then
  usage_error "$DEST_ARG existe y no es una carpeta"
fi
DEST_ABS="$(absolute_path "$DEST_ARG")"
case "$DEST_ABS/" in
  "$ROOT/"*) usage_error "el destino $DEST_ARG está dentro del vault" "Exporta desde tu repositorio, no dentro del vault: cd <tu repositorio> && $0 --root $ROOT $SET .agents" ;;
esac

# ------------------------------------------------------------------ 1 · línea de dependencia

if ! vault_line "$SET"; then
  nothing_exported "$VAULT_LINE_ERROR" "Corrige el manifest y comprueba el vault con tools/verify.sh."
fi
LINE="$VAULT_LINE"

bad=""
for member in $LINE; do
  errors="$(vault_manifest_errors "$member" | cut -f1)"
  [ -z "$errors" ] || bad="$bad$errors
"
done
if [ -n "$bad" ]; then
  nothing_exported "$bad" "Corrige el manifest y comprueba el vault con tools/verify.sh."
fi

count=0
for member in $LINE; do count=$((count + 1)); done

printf 'export.sh · %s %s %s\n\n' "$SET" "$ARROW" "$DEST_SHOW"
printf '1 · línea de dependencia, desde la base\n'
printf '    %s\n' "$(printf '%s' "$LINE" | awk -v a=" $ARROW " 'NF { printf "%s%s", (n++ ? a : ""), $0 }')"

# ------------------------------------------------------------------ 2 · estados

printf '2 · estado de los %s de la línea\n' "$(plural "$count" set sets)"
blocked=""
for member in $LINE; do
  status="$(vault_field "$member" status)"
  if [ "$status" = DEPRECATED ]; then
    printf '    %-16s %s hasta %s\n' "$member" "$status" "$(vault_field "$member" retireOn)"
  else
    printf '    %-16s %s\n' "$member" "$status"
  fi
  vault_gate "$member" || blocked="$blocked$member "
done
if [ -n "$blocked" ]; then
  reasons=""
  for member in $blocked; do
    vault_gate "$member"
    reasons="$reasons$VAULT_GATE_REASON
"
    successor="$(vault_field "$member" replacedBy | sed 's/,/, /g')"
    if [ -n "$successor" ]; then reasons="${reasons}Su sucesor es $successor.
"; fi
  done
  nothing_exported "$reasons" "Solo se exportan sets ACTIVE, o DEPRECATED hasta su retireOn."
fi

# ------------------------------------------------------------------ montaje

STAGE="$VAULT_TMP/stage"
SOURCES="$VAULT_TMP/sources"
ORIGIN="$VAULT_TMP/origin.tsv"
MCPS="$VAULT_TMP/mcp.list"
mkdir -p "$STAGE" "$SOURCES"
: > "$ORIGIN"
: > "$MCPS"

collision() { # tipo nombre set
  local kind="$1" asset="$2" owner="$3" first
  first="$(awk -F'\t' -v k="$kind" -v n="$asset" '$1 == k && $2 == n { print $3; exit }' "$ORIGIN")"
  if [ -n "$first" ]; then
    nothing_exported "$kind «$asset» está en dos sets de la línea de dependencia: $first y $owner." "Un nombre no se repite en el vault: renombra uno de los dos."
  fi
  printf '%s\t%s\t%s\n' "$kind" "$asset" "$owner" >> "$ORIGIN"
}

for member in $LINE; do
  src="$ROOT/asset-sets/$member"
  if [ -d "$src/skills" ]; then
    for dir in "$src"/skills/*/; do
      [ -d "$dir" ] || continue
      name="$(basename "$dir")"
      collision skill "$name" "$member"
      mkdir -p "$STAGE/skills/$name"
      cp -R "$dir." "$STAGE/skills/$name/"
      rm -f "$STAGE/skills/$name/manifest.json"
      find "$STAGE/skills/$name" -name '.*' -exec rm -rf {} + 2>/dev/null
    done
  fi
  for kind in instructions agents hooks; do
    [ -d "$src/$kind" ] || continue
    for file in "$src/$kind"/*; do
      [ -f "$file" ] || continue
      name="$(basename "$file")"
      case "$name" in .*) continue ;; esac
      collision "$kind" "$name" "$member"
      mkdir -p "$STAGE/$kind"
      cp "$file" "$STAGE/$kind/$name"
    done
  done
  if [ -f "$src/mcp.json" ]; then printf '%s\n' "$src/mcp.json" >> "$MCPS"; fi
done

if [ -s "$MCPS" ]; then
  set --
  while IFS= read -r file; do set -- "$@" "$file"; done < "$MCPS"
  if ! merge_error="$(vault_json merge-mcp "$STAGE/mcp.json" "$@" 2>&1)"; then
    nothing_exported "$(printf '%s' "$merge_error" | sed "s#$ROOT/##g")" "Cada servidor MCP vive en un solo set de la línea de dependencia."
  fi
fi

# ------------------------------------------------------------------ 3 · composición

BEST=""
NBEST=0
for member in $LINE; do
  for name in $(awk -F'\t' -v s="$member" '$1 == "skill" && $3 == s { print $2 }' "$ORIGIN" | sorted); do
    case "$name" in
      *-best-practices) BEST="$BEST$name "; NBEST=$((NBEST + 1)) ;;
    esac
  done
done

COMPOSED=""
ABSORBED=""
if [ "$NBEST" -ge 2 ]; then
  for name in $BEST; do COMPOSED="$name"; done
  for name in $BEST; do
    [ "$name" = "$COMPOSED" ] || ABSORBED="$ABSORBED$name "
    mv "$STAGE/skills/$name" "$SOURCES/$name"
  done

  # Los nombres absorbidos pasan a ser el compuesto en todo el texto montado.
  rename_script="$VAULT_TMP/rename.sed"
  : > "$rename_script"
  for name in $ABSORBED; do
    printf 's/(^|[^a-z0-9-])%s([^a-z0-9-]|$)/\\1%s\\2/g\n' "$name" "$COMPOSED" >> "$rename_script"
  done
  find "$STAGE" "$SOURCES" -type f -name '*.md' | sorted | while IFS= read -r file; do
    sed -E -f "$rename_script" "$file" | sed -E -f "$rename_script" > "$file.tmp" && mv "$file.tmp" "$file"
  done

  target="$STAGE/skills/$COMPOSED"
  mkdir -p "$target/sources"
  list="$(printf '%s' "$BEST" | awk '{ for (k = 1; k <= NF; k++) printf "%s%s", $k, (k < NF - 1 ? ", " : (k == NF - 1 ? " y " : "")) }')"
  {
    awk '{ sub(/\r$/, "") } NR == 1 && $0 == "---" { inside = 1; print; next } inside { print; if ($0 == "---") exit }' "$SOURCES/$COMPOSED/SKILL.md"
    printf '\n<!-- Generado por tools/export.sh a partir de %s. No lo edites: el siguiente export lo reescribe. -->\n\n' "$list"
    awk '{ sub(/\r$/, "") } /^# / { print; exit }' "$SOURCES/$COMPOSED/SKILL.md"
    for name in $BEST; do
      printf '\n'
      awk -v prefix="sources/$name/" '
        { sub(/\r$/, "") }
        NR == 1 && $0 == "---" { front = 1; next }
        front { if ($0 == "---") front = 0; next }
        !title && /^# / { title = 1; print "#" $0; started = 1; next }
        /^(```|~~~)/ { fence = !fence }
        {
          line = $0
          if (!fence) {
            if (line ~ /^#+ /) line = "#" line
            out = ""
            while (match(line, /\]\([^)]*\)/)) {
              target = substr(line, RSTART + 2, RLENGTH - 3)
              if (target !~ /^[a-zA-Z][a-zA-Z0-9+.-]*:/ && target !~ /^[#\/]/) target = prefix target
              out = out substr(line, 1, RSTART - 1) "](" target ")"
              line = substr(line, RSTART + RLENGTH)
            }
            line = out line
          }
          body[++n] = line
        }
        END {
          first = 1; while (first <= n && body[first] == "") first++
          last = n; while (last >= first && body[last] == "") last--
          if (first <= last) print ""
          for (i = first; i <= last; i++) print body[i]
        }' "$SOURCES/$name/SKILL.md"
    done
  } > "$target/SKILL.md"
  for name in $BEST; do
    mkdir -p "$target/sources/$name"
    cp -R "$SOURCES/$name/." "$target/sources/$name/"
    rm -f "$target/sources/$name/SKILL.md"
    rmdir "$target/sources/$name" 2>/dev/null || true
  done
  rmdir "$target/sources" 2>/dev/null || true
fi

# ------------------------------------------------------------------ AGENTS.md

{
  printf '<!-- Generado por tools/export.sh desde la línea de dependencia de %s. No lo edites: el siguiente export lo reescribe. -->\n\n' "$SET"
  printf '# Instructions\n\n'
  printf 'Each section applies when you edit files that match its pattern.\n'
  for member in $LINE; do
    for name in $(awk -F'\t' -v s="$member" '$1 == "instructions" && $3 == s { print $2 }' "$ORIGIN" | sorted); do
      file="$STAGE/instructions/$name"
      printf '\n## When you edit files matching `%s`\n\n' "$(fm_get "$file" applyTo)"
      awk '
        { sub(/\r$/, "") }
        NR == 1 && $0 == "---" { front = 1; next }
        front { if ($0 == "---") front = 0; next }
        { body[++n] = $0 }
        END {
          first = 1; while (first <= n && body[first] == "") first++
          last = n; while (last >= first && body[last] == "") last--
          for (i = first; i <= last; i++) print body[i]
        }' "$file"
    done
  done
} > "$STAGE/AGENTS.md"

# ------------------------------------------------------------------ 4 · comprobaciones

problems=""
problem() { problems="$problems$1
"; }

if [ -d "$STAGE/skills" ]; then
  for dir in "$STAGE"/skills/*/; do
    name="$(basename "$dir")"
    if [ ! -f "$dir/SKILL.md" ]; then problem "skills/$name no tiene SKILL.md"; continue; fi
    [ "$(fm_get "$dir/SKILL.md" name)" = "$name" ] || problem "skills/$name/SKILL.md: name no es «$name»"
    [ -n "$(fm_get "$dir/SKILL.md" description)" ] || problem "skills/$name/SKILL.md: falta description"
    skill_root="$(cd "$dir" && pwd -P)"
    while IFS= read -r md; do
      md_dir="$(dirname "$md")"
      for link in $(md_links "$md"); do
        if [ ! -e "$md_dir/$link" ]; then
          problem "${md#"$STAGE"/}: el enlace $link no existe"
          continue
        fi
        resolved="$(cd "$(dirname "$md_dir/$link")" && pwd -P)"
        case "$resolved/" in
          "$skill_root/"*) ;;
          *) problem "${md#"$STAGE"/}: el enlace $link sale de la carpeta de la skill" ;;
        esac
      done
    done <<EOF
$(find "$dir" -type f -name '*.md' | sorted)
EOF
  done
fi

while IFS= read -r file; do
  [ -n "$file" ] || continue
  for name in $(load_phrases "$file"); do
    [ -d "$STAGE/skills/$name" ] || problem "${file#"$STAGE"/}: «Load the $name skill» no encuentra skills/$name en la línea de dependencia"
  done
done <<EOF
$(find "$STAGE" -type f -name '*.md' ! -name AGENTS.md ! -path '*/sources/*' | sorted)
EOF

is_reference() { case "$1" in '${'*'}') return 0 ;; *) return 1 ;; esac; }

if [ -d "$STAGE/hooks" ]; then
  for file in "$STAGE"/hooks/*.json; do
    [ -f "$file" ] || continue
    if ! hook_lines="$(vault_json hook "$file" 2>&1)"; then
      problem "hooks/$(basename "$file"): $hook_lines"
      continue
    fi
    while IFS="$(printf '\t')" read -r type event value rest; do
      case "$type" in
        command)
          for path in $(command_paths "$value"); do
            case "$path" in
              .agents/*)
                [ -e "$STAGE/${path#.agents/}" ] || problem "hooks/$(basename "$file"): el comando nombra $path, que el export no escribe" ;;
              *)
                problem "hooks/$(basename "$file"): el comando nombra $path, fuera de .agents/. Un hook exportado no encontrará esa ruta. Pon el script en hooks/ del set y llámalo como .agents/hooks/<script>" ;;
            esac
          done ;;
        env)
          is_reference "$rest" || problem "hooks/$(basename "$file"): env $value tiene un valor escrito. Usa \${$value}" ;;
      esac
    done <<EOF
$hook_lines
EOF
  done
fi

MCP_LINES=""
if [ -f "$STAGE/mcp.json" ]; then
  MCP_LINES="$(vault_json mcp "$STAGE/mcp.json")"
  while IFS="$(printf '\t')" read -r type server key value; do
    [ "$type" = env ] || continue
    is_reference "$value" || problem "mcp.json: env $key del servidor $server tiene un valor escrito. Usa \${$key}"
  done <<EOF
$MCP_LINES
EOF
fi

if [ -n "$problems" ]; then
  nothing_exported "$problems"
fi

# ------------------------------------------------------------------ 3 y 4 · informe

if [ -n "$COMPOSED" ]; then
  printf '3 · compone\n'
  printf '    %s\n' "$(printf '%s' "$BEST" | awk '{ for (k = 1; k <= NF; k++) printf "%s%s", $k, (k < NF ? " + " : "") }')"
  printf '    = %s\n' "$COMPOSED"
else
  printf '3 · compone: nada que juntar\n'
fi
printf '4 · comprueba: todo pasa\n'

# ------------------------------------------------------------------ 5 · auditoría

count_in() { find "$STAGE/$1" -maxdepth 1 "$2" "$3" 2>/dev/null | wc -l | tr -d ' '; }
N_SKILLS="$(find "$STAGE/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
N_INSTRUCTIONS="$(count_in instructions -name '*.instructions.md')"
N_AGENTS="$(count_in agents -name '*.agent.md')"
N_HOOKS="$(count_in hooks -name '*.json')"
N_MCP="$(printf '%s\n' "$MCP_LINES" | grep -c '^server' || true)"

audit_block() { # etiqueta, elementos (uno por línea)
  local label="$1" first=1 item
  if [ -z "$2" ]; then
    printf '    %-16s ninguno\n' "$label"
    return
  fi
  while IFS= read -r item; do
    if [ "$first" -eq 1 ]; then printf '    %-16s %s\n' "$label" "$item"; first=0; else printf '    %-16s %s\n' "" "$item"; fi
  done <<EOF
$2
EOF
}

AUDIT_HOOKS="$(find "$STAGE/hooks" -type f 2>/dev/null | sorted | sed "s#^$STAGE#$DEST_SHOW#")"
AUDIT_SCRIPTS="$(find "$STAGE/skills" -type f -path '*/scripts/*' 2>/dev/null | sorted | sed "s#^$STAGE#$DEST_SHOW#")"
AUDIT_MCP="$(printf '%s\n' "$MCP_LINES" | awk -F'\t' '$1 == "server" { print $2 ": " $3 }')"
printf '5 · AUDITORÍA · lo que se ejecutará en tu máquina\n'
audit_block hooks "$AUDIT_HOOKS"
audit_block scripts "$AUDIT_SCRIPTS"
audit_block 'servidores MCP' "$AUDIT_MCP"
printf '\n'
if [ -n "$AUDIT_HOOKS$AUDIT_SCRIPTS$AUDIT_MCP" ]; then
  printf '    Ábrelos antes de hacer commit, junto al git diff. En cada uno, mira:\n'
  printf '      - qué escribe o borra, y dónde\n'
  printf '      - qué descarga o a qué red llama\n'
  # shellcheck disable=SC2016
  printf '      - qué lee del entorno. Un secreto nunca va escrito: va como ${VARIABLE}\n'
else
  printf '    Esta línea de dependencia no trae nada que se ejecute en tu máquina.\n'
fi

# ------------------------------------------------------------------ 6 · escritura

mkdir -p "$DEST_ARG"
cp -R "$STAGE/." "$DEST_ARG/"

printf '6 · escribe en %s/\n' "$DEST_SHOW"
printf '    %s · %s · %s · %s · %s · AGENTS.md\n' \
  "$(plural "$N_SKILLS" skill skills)" "$(plural "$N_INSTRUCTIONS" instruction instructions)" \
  "$(plural "$N_AGENTS" agent agents)" "$(plural "$N_HOOKS" hook hooks)" "$(plural "$N_MCP" 'servidor MCP' 'servidores MCP')"
printf '    Para ver qué ha cambiado: git status --short %s\n' "$DEST_SHOW"

if [ -n "$COMPOSED" ]; then
  printf '\nNombres juntados en %s: %s.\n' "$COMPOSED" "$(printf '%s' "$ABSORBED" | awk '{ for (k = 1; k <= NF; k++) printf "%s%s", $k, (k < NF ? ", " : "") }')"
fi

foreign=""
for kind in skills instructions agents hooks; do
  [ -d "$DEST_ARG/$kind" ] || continue
  for entry in "$DEST_ARG/$kind"/* "$DEST_ARG/$kind"/.[!.]*; do
    [ -e "$entry" ] || continue
    name="$(basename "$entry")"
    [ -e "$STAGE/$kind/$name" ] && continue
    if [ -d "$entry" ]; then foreign="$foreign $kind/$name/"; else foreign="$foreign $kind/$name"; fi
  done
done
if [ -n "$foreign" ]; then
  printf '\nEn %s/ hay entradas que este export no ha escrito:%s\n' "$DEST_SHOW" "$foreign"
  printf 'Si son de un export anterior, bórralas. Si son tuyas, muévelas fuera de %s/.\n' "$DEST_SHOW"
fi

summary_skills="$(plural "$N_SKILLS" skill skills)"
if [ -n "$COMPOSED" ]; then summary_skills="$summary_skills (1 compuesta de $NBEST)"; fi
printf '\nexport.sh: %s %s %s · %s · %s · %s · %s · %s MCP\n' "$SET" "$ARROW" "$DEST_SHOW" "$summary_skills" \
  "$(plural "$N_INSTRUCTIONS" instruction instructions)" "$(plural "$N_AGENTS" agent agents)" \
  "$(plural "$N_HOOKS" hook hooks)" "$N_MCP"
