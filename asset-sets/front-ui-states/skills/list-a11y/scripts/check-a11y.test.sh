#!/usr/bin/env bash
# Tests de las pistas de accesibilidad de una lista.
set -u

HERE="$(cd "$(dirname "$0")" && pwd -P)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/check-a11y.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
failures=0

check() {
  if [ "$2" = "$3" ]; then echo "ok - $1"; else echo "FALLO - $1: esperado $2, obtenido $3"; failures=$((failures + 1)); fi
}

list="$WORK/lista accesible.tsx"
printf '%s\n' '<p aria-live="polite">3 resultados</p>' '<ol' '  aria-labelledby="heading"' ' />' > "$list"
bash "$HERE/check-a11y.sh" "$list" > /dev/null 2>&1
check "acepta listas ordenadas con aria-labelledby sin exigir sr-only" 0 "$?"

printf '%s\n' '<p aria-live="polite">3 resultados</p>' '<ul aria-label="Resultados" />' > "$list"
bash "$HERE/check-a11y.sh" "$list" > /dev/null 2>&1
check "acepta listas con aria-label" 0 "$?"

printf '%s\n' '<p aria-live="polite">3 resultados</p>' '<ul />' > "$list"
bash "$HERE/check-a11y.sh" "$list" > /dev/null 2>&1
check "avisa si no encuentra un nombre accesible" 2 "$?"

printf '%s\n' '<ul aria-label="Resultados" />' > "$list"
bash "$HERE/check-a11y.sh" "$list" > /dev/null 2>&1
check "avisa si no encuentra aria-live" 2 "$?"

bash "$HERE/check-a11y.sh" "$WORK/no-existe" > /dev/null 2>&1
check "rechaza una lista inexistente" 2 "$?"

bash "$HERE/check-a11y.sh" > /dev/null 2>&1
check "requiere el archivo de la lista" 2 "$?"

[ "$failures" -eq 0 ]
