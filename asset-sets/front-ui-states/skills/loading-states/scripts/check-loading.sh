#!/usr/bin/env bash
# Comprueba que una página con lista tiene su estado de carga.
# Uso:  check-loading.sh <página>...
#       check-loading.sh --hook   (desde un hook Stop: lee el JSON de stdin y comprueba
#                                  las páginas *Page.tsx que han cambiado)
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
  # Sin páginas por argumento, las que han cambiado respecto al último commit.
  if [ $# -eq 0 ]; then
    pages="$({ git diff --name-only --diff-filter=d HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } | grep 'Page\.tsx$' | sort -u)"
    [ -n "$pages" ] || exit 0
    # shellcheck disable=SC2086
    set -- $pages
  fi
fi

if [ $# -eq 0 ]; then
  echo "Indica el fichero de la página" >&2
  exit 2
fi

fail=0
for file in "$@"; do
  if [ ! -f "$file" ]; then
    echo "No existe $file" >&2
    fail=1
    continue
  fi
  grep -q "<Suspense" "$file" || { echo "Falta <Suspense> en $file" >&2; fail=1; }
  grep -q "ListSkeleton" "$file" || { echo "Falta ListSkeleton en $file" >&2; fail=1; }
done

skeleton="$(git ls-files 2>/dev/null | grep '/ListSkeleton\.tsx$' | head -n 1)"
if [ -n "$skeleton" ] && ! grep -q 'aria-busy' "$skeleton"; then
  echo "$skeleton no tiene aria-busy" >&2
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "ok: estado de carga en $*"
fi
exit $(( fail * 2 ))
