# shellcheck shell=bash
# vault.sh: funciones comunes de export.sh y verify.sh.
# Portable: bash 3.2 (macOS), Linux y Git Bash. Sin arrays asociativos ni readlink -f.
# Node solo lee JSON (json.mjs). Todo lo demás es bash, sed y awk.

VAULT_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ARROW='→'

# Rellena un texto UTF-8 con espacios hasta un ancho en caracteres (printf cuenta bytes).
pad() {
  local chars
  chars="$(printf '%s' "$1" | LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' ')"
  printf '%s%*s' "$1" "$(($2 > chars ? $2 - chars : 0))" ''
}

# Orden de bytes, igual en cualquier máquina.
sorted() {
  LC_ALL=C sort "$@"
}

# Ejecuta json.mjs.
vault_json() {
  node "$VAULT_LIB/json.mjs" "$@"
}

# Fecha con la que se compara retireOn.
vault_today() {
  printf '%s\n' "${VAULT_TODAY:-$(date +%Y-%m-%d)}"
}

# Directorio temporal de trabajo, borrado al salir.
vault_tmp() {
  VAULT_TMP="$(mktemp -d "${TMPDIR:-/tmp}/vault.XXXXXX")"
  trap 'rm -rf "$VAULT_TMP"' EXIT
}

# Lee los manifests de asset-sets/ una sola vez.
# Deja en $VAULT_TSV una línea por set, error o aviso (ver json.mjs), y cada campo de cada
# manifest en una variable VF_<set>_<campo>, para no lanzar un proceso por consulta.
vault_load() {
  VAULT_ROOT="$1"
  VAULT_SETS="$VAULT_ROOT/asset-sets"
  VAULT_TSV="$VAULT_TMP/sets.tsv"
  vault_json sets "$VAULT_SETS" > "$VAULT_TSV"
  eval "$(awk -F'\t' -v q="'" '
    function quote(v) { gsub(q, q "\"" q "\"" q, v); return q v q }
    $1 == "set" {
      key = $2; gsub(/[^A-Za-z0-9]/, "_", key)
      split("name status owner version deps retireOn replacedBy suspension description", field, " ")
      print "VF_" key "_present=1"
      for (i = 1; i <= 9; i++) print "VF_" key "_" field[i] "=" quote($(i + 2))
    }' "$VAULT_TSV")"
}

# Carpetas de asset-sets/, ordenadas.
vault_folders() {
  awk -F'\t' '{ print $2 }' "$VAULT_TSV" | sorted -u
}

# 0 si el set tiene un manifest legible.
vault_has_set() {
  local key="${1//[^A-Za-z0-9]/_}"
  eval "[ -n \"\${VF_${key}_present:-}\" ]"
}

# Un campo del manifest: name status owner version deps retireOn replacedBy suspension description
vault_field() {
  local key="${1//[^A-Za-z0-9]/_}"
  eval "printf '%s\\n' \"\${VF_${key}_$2:-}\""
}

# Dependencias directas, separadas por espacios.
vault_deps() {
  local deps
  deps="$(vault_field "$1" deps)"
  printf '%s\n' "${deps//,/ }"
}

# Errores de manifest de un set (mensaje TAB reparación).
vault_manifest_errors() {
  awk -F'\t' -v s="$1" '$1 == "error" && $2 == s { print $3 "\t" $4 }' "$VAULT_TSV"
}

# Línea de dependencia de un set, desde la base hasta él.
# Recorrido en profundidad por dependencies en el orden escrito; cada set entra una vez.
# Deja la línea en VAULT_LINE (un set por línea, la base primero) y, escrita de la hoja
# a la base («a → b → c»), en VAULT_LINE_TEXT. Si hay un ciclo o una base que no existe,
# deja el motivo en VAULT_LINE_ERROR y devuelve 1.
vault_line() {
  _vl_visited=" "
  VAULT_LINE=""
  VAULT_LINE_TEXT=""
  VAULT_LINE_ERROR=""
  _vault_line_visit "$1" "" || return 1
  VAULT_LINE_TEXT="$(printf '%s' "$VAULT_LINE" | awk -v a=" $ARROW " 'NF { l[++n] = $0 } END { for (i = n; i >= 1; i--) printf "%s%s", l[i], (i > 1 ? a : "") }')"
}

_vault_line_visit() {
  local set="$1" path="$2" dep
  case " $path " in
    *" $set "*)
      VAULT_LINE_ERROR="ciclo en las dependencias: $(printf '%s' "$path $set" | sed "s/ / $ARROW /g")"
      return 1 ;;
  esac
  case "$_vl_visited" in *" $set "*) return 0 ;; esac
  if ! vault_has_set "$set"; then
    if [ -n "$path" ]; then
      VAULT_LINE_ERROR="${path##* } depende de $set, que no existe (asset-sets/${path##* }/manifest.json)"
    else
      VAULT_LINE_ERROR="el set $set no existe o su manifest no se puede leer"
    fi
    return 1
  fi
  for dep in $(vault_deps "$set"); do
    _vault_line_visit "$dep" "${path:+$path }$set" || return 1
  done
  _vl_visited="$_vl_visited$set "
  VAULT_LINE="$VAULT_LINE$set
"
}

# 0 si el estado del set permite exportarlo hoy. Si no, escribe el motivo en VAULT_GATE_REASON.
vault_gate() {
  local set="$1" status retire today
  status="$(vault_field "$set" status)"
  today="$(vault_today)"
  VAULT_GATE_REASON=""
  case "$status" in
    ACTIVE) return 0 ;;
    DEPRECATED)
      retire="$(vault_field "$set" retireOn)"
      if [ -n "$retire" ] && ! [ "$today" \> "$retire" ]; then return 0; fi
      VAULT_GATE_REASON="$set está en DEPRECATED y su retireOn, $retire, ya ha pasado (asset-sets/$set/manifest.json)."
      ;;
    SUSPENDED)
      VAULT_GATE_REASON="$set está en SUSPENDED: $(vault_field "$set" suspension) (asset-sets/$set/manifest.json)."
      ;;
    *)
      VAULT_GATE_REASON="$set está en ${status:-un estado desconocido} (asset-sets/$set/manifest.json)."
      ;;
  esac
  return 1
}

# Valor de una clave del frontmatter YAML simple (clave: valor) de un .md, sin comillas.
fm_get() {
  awk -v key="$2" -v q="'" '
    { sub(/\r$/, "") }
    NR == 1 { if ($0 != "---") exit; next }
    $0 == "---" { exit }
    index($0, key ":") == 1 {
      v = substr($0, length(key) + 2)
      sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
      if (length(v) > 1 && ((substr(v, 1, 1) == "\"" && substr(v, length(v)) == "\"") || (substr(v, 1, 1) == q && substr(v, length(v)) == q))) v = substr(v, 2, length(v) - 2)
      print v; exit
    }' "$1"
}

# 0 si el .md empieza con un frontmatter cerrado.
fm_present() {
  awk '{ sub(/\r$/, "") } NR == 1 && $0 != "---" { exit 1 } NR > 1 && $0 == "---" { ok = 1; exit } END { exit ok ? 0 : 1 }' "$1"
}

# Destinos de los enlaces relativos de un .md: [texto](destino), sin URLs ni anclas.
md_links() {
  awk '
    { sub(/\r$/, "") }
    /^(```|~~~)/ { fence = !fence; next }
    fence { next }
    {
      line = $0
      gsub(/`[^`]*`/, "", line)
      while (match(line, /\]\([^)]*\)/)) {
        target = substr(line, RSTART + 2, RLENGTH - 3)
        line = substr(line, RSTART + RLENGTH)
        sub(/[ \t].*$/, "", target)
        sub(/#.*$/, "", target)
        if (target == "" || target ~ /^[a-zA-Z][a-zA-Z0-9+.-]*:/ || target ~ /^\//) continue
        print target
      }
    }' "$1"
}

# Nombres de skill en las frases «Load the <x> skill» de un fichero.
load_phrases() {
  tr -d '\r' < "$1" | grep -oE 'Load the [a-z0-9-]+ skill' | sed -E 's/^Load the (.*) skill$/\1/' | sorted -u
}

# Rutas (con /) que nombra un comando de hook, sin comillas.
command_paths() {
  printf '%s\n' "$1" | tr ' \t' '\n\n' | sed -e "s/^[\"']//" -e "s/[\"']\$//" | grep '/' || true
}
