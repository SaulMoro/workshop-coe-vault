# shellcheck shell=bash
# testing.sh: asserts mínimos para los *.test.sh de tools/.
# Cada caso imprime «ok - …» o «FALLO - …». tools/test.sh los cuenta.

TEST_FAILURES=0
TEST_VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/vault-test.XXXXXX")"
trap 'rm -rf "$TEST_TMP"' EXIT

pass() { printf 'ok - %s\n' "$1"; }
fail() {
  printf 'FALLO - %s\n' "$1"
  if [ -n "${2:-}" ]; then printf '%s\n' "$2" | sed 's/^/    /'; fi
  TEST_FAILURES=$((TEST_FAILURES + 1))
}

assert_eq() { # descripción, esperado, obtenido
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "esperado: $2
obtenido: $3"; fi
}

assert_contains() { # descripción, texto, fragmento
  case "$2" in
    *"$3"*) pass "$1" ;;
    *) fail "$1" "no contiene: $3
salida:
$2" ;;
  esac
}

assert_not_contains() { # descripción, texto, fragmento
  case "$2" in
    *"$3"*) fail "$1" "contiene: $3" ;;
    *) pass "$1" ;;
  esac
}

assert_exit() { # descripción, código esperado, código obtenido
  assert_eq "$1 (sale con $2)" "$2" "$3"
}

assert_file() { if [ -e "$2" ]; then pass "$1"; else fail "$1" "no existe: ${2#"$TEST_TMP"/}"; fi; }
assert_no_file() { if [ -e "$2" ]; then fail "$1" "existe: ${2#"$TEST_TMP"/}"; else pass "$1"; fi; }

# Copia del vault sin .git, para modificarla en un caso. Imprime su ruta.
copy_vault() {
  local target
  target="$(mktemp -d "$TEST_TMP/vault.XXXXXX")"
  cp -R "$TEST_VAULT/asset-sets" "$TEST_VAULT/tools" "$TEST_VAULT/manifest.json" "$target/"
  printf '%s\n' "$target"
}

# Sustituye texto en un fichero (sin sed -i, que no es portable).
replace_in() { # fichero, buscar (ERE de sed), sustituir
  sed -E "s|$2|$3|" "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

finish() {
  [ "$TEST_FAILURES" -eq 0 ]
}
