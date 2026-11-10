#!/usr/bin/env bash
# Busca pistas de carga en una página y su indicador. No valida su comportamiento.
# Uso: check-loading.sh <página> <indicador>
# Salida: 0 si encuentra las pistas · 2 si no las encuentra o falta un archivo.
set -u

if [ "$#" -ne 2 ]; then
  echo "Uso: check-loading.sh <página> <indicador>" >&2
  exit 2
fi

file="$1"
fallback="$2"
for path in "$file" "$fallback"; do
  if [ ! -f "$path" ]; then
    echo "No existe $path" >&2
    exit 2
  fi
done

fail=0
grep -q '<Suspense' "$file" || { echo "No se encontró <Suspense> en $file" >&2; fail=1; }
grep -Eq 'fallback[[:space:]]*=' "$file" || { echo "No se encontró fallback en $file" >&2; fail=1; }
grep -q 'aria-busy' "$fallback" || { echo "No se encontró aria-busy en $fallback" >&2; fail=1; }

if [ "$fail" -eq 0 ]; then
  echo "ok: pistas de carga encontradas; revisa su comportamiento"
fi
exit $(( fail * 2 ))
