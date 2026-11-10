#!/usr/bin/env bash
# Tests de las pistas de carga con rutas recibidas como argumentos.
set -u

HERE="$(cd "$(dirname "$0")" && pwd -P)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/check-loading.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
failures=0

check() {
  if [ "$2" = "$3" ]; then echo "ok - $1"; else echo "FALLO - $1: esperado $2, obtenido $3"; failures=$((failures + 1)); fi
}

page="$WORK/página de lista.tsx"
fallback="$WORK/indicador de carga.tsx"
printf '%s\n' '<Suspense fallback={<PendingRows />}><List /></Suspense>' > "$page"
printf '%s\n' '<ul aria-busy="true" />' > "$fallback"
bash "$HERE/check-loading.sh" "$page" "$fallback" > /dev/null 2>&1
check "acepta rutas con espacios y cualquier nombre de indicador" 0 "$?"

printf '%s\n' '<Suspense><List /></Suspense>' > "$page"
bash "$HERE/check-loading.sh" "$page" "$fallback" > /dev/null 2>&1
check "avisa si no encuentra fallback" 2 "$?"

printf '%s\n' '<Suspense fallback={<PendingRows />}><List /></Suspense>' > "$page"
printf '%s\n' '<ul />' > "$fallback"
bash "$HERE/check-loading.sh" "$page" "$fallback" > /dev/null 2>&1
check "avisa si no encuentra aria-busy en el indicador" 2 "$?"

bash "$HERE/check-loading.sh" "$page" "$WORK/no-existe" > /dev/null 2>&1
check "rechaza un indicador inexistente" 2 "$?"
bash "$HERE/check-loading.sh" "$page" > /dev/null 2>&1
check "requiere los dos archivos" 2 "$?"

[ "$failures" -eq 0 ]
