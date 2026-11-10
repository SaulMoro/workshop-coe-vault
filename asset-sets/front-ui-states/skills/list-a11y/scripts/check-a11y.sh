#!/usr/bin/env bash
# Busca pistas de accesibilidad en una lista. No valida su comportamiento.
# Uso:  check-a11y.sh <fichero de la lista>
# Salida: 0 si encuentra las pistas · 2 si no las encuentra o falta el archivo.
set -u

if [ "$#" -ne 1 ]; then
  echo "Uso: check-a11y.sh <fichero de la lista>" >&2
  exit 2
fi

file="$1"
if [ ! -f "$file" ]; then
  echo "No existe $file" >&2
  exit 2
fi

fail=0
tr '\n' ' ' < "$file" | grep -Eq '<(ul|ol)[[:space:]][^>]*aria-(label|labelledby)[[:space:]]*=' || { echo "No se encontró un nombre accesible en una lista de $file" >&2; fail=1; }
grep -q 'aria-live' "$file" || { echo "No se encontró aria-live en $file" >&2; fail=1; }

if [ "$fail" -eq 0 ]; then
  echo "ok: pistas de accesibilidad encontradas; revisa su comportamiento"
fi
exit $(( fail * 2 ))
