#!/usr/bin/env bash
# Comprueba que una página con lista tiene su estado de carga.
# Uso:  check-loading.sh <página>
#       check-loading.sh --hook <página>   (desde un hook Stop: lee el JSON de stdin)
# Cada fallo va a stderr y el script sale con 2. Si todo está bien, escribe
# «ok: …» en stdout y sale con 0. Se ejecuta desde la raíz del repositorio.
set -u

if [ "${1:-}" = "--hook" ]; then
  shift
  input="$(cat)"
  # Ya se bloqueó una vez al parar: no se vuelve a bloquear (un solo reintento).
  if printf '%s' "$input" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
    exit 0
  fi
fi

file="${1:?Indica el fichero de la página}"
if [ ! -f "$file" ]; then
  echo "No existe $file" >&2
  exit 2
fi

fail=0
grep -q "<Suspense" "$file" || { echo "Falta <Suspense> en $file" >&2; fail=1; }
grep -q "ListSkeleton" "$file" || { echo "Falta ListSkeleton en $file" >&2; fail=1; }
grep -q 'aria-busy' src/shared/ui/ListSkeleton.tsx 2>/dev/null || { echo "ListSkeleton no tiene aria-busy" >&2; fail=1; }

if [ "$fail" -eq 0 ]; then
  echo "ok: estado de carga en $file"
fi
exit $(( fail * 2 ))
