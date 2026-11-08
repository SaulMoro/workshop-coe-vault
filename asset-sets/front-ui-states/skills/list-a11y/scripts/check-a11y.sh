#!/usr/bin/env bash
# Comprueba la accesibilidad de una lista.
# Uso:  check-a11y.sh <fichero de la lista>
# Cada fallo va a stderr y el script sale con 2. Si todo está bien, escribe
# «ok: …» en stdout y sale con 0. Se ejecuta desde la raíz del repositorio.
set -u

file="${1:?Indica el fichero de la lista}"
if [ ! -f "$file" ]; then
  echo "No existe $file" >&2
  exit 2
fi

fail=0
tr '\n' ' ' < "$file" | grep -Eq '<ul[^>]*aria-label=' || { echo "El <ul> de $file no tiene aria-label" >&2; fail=1; }
grep -q 'aria-live' "$file" || { echo "Falta el resumen con aria-live en $file" >&2; fail=1; }
grep -q 'sr-only' "$file" || { echo "El resumen de $file no es sr-only" >&2; fail=1; }

if [ "$fail" -eq 0 ]; then
  echo "ok: lista accesible en $file"
fi
exit $(( fail * 2 ))
