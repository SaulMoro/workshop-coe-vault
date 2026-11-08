#!/usr/bin/env bash
# test.sh: ejecuta todos los *.test.sh del vault y resume.
# Comprueba además que cada script .sh (salvo las librerías de tools/lib) tiene el bit de ejecución en git.
# Salida: 0 todo pasa · 1 algún fallo
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT" || exit 1

passed=0
failed=0

suites="$(find . -type f -name '*.test.sh' ! -path './.git/*' ! -path '*/node_modules/*' | LC_ALL=C sort)"
for suite in $suites; do
  printf '== %s\n' "${suite#./}"
  output="$(bash "$suite" 2>&1)"
  status=$?
  printf '%s\n' "$output"
  ok_count="$(printf '%s\n' "$output" | grep -c '^ok - ' || true)"
  fail_count="$(printf '%s\n' "$output" | grep -c '^FALLO - ' || true)"
  passed=$((passed + ok_count))
  failed=$((failed + fail_count))
  if [ "$status" -ne 0 ] && [ "$fail_count" -eq 0 ]; then
    printf 'FALLO - %s terminó con %s sin decir por qué\n' "${suite#./}" "$status"
    failed=$((failed + 1))
  fi
done

printf '== bit de ejecución\n'
if git -C "$ROOT" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  missing="$(git -C "$ROOT" ls-files -s -- '*.sh' | awk '$1 != "100755" && index($4, "tools/lib/") != 1 { print $4 }')"
  if [ -z "$missing" ]; then
    printf 'ok - cada .sh del índice de git es ejecutable\n'
    passed=$((passed + 1))
  else
    for file in $missing; do printf 'FALLO - %s no es ejecutable en git: git update-index --chmod=+x %s\n' "$file" "$file"; done
    failed=$((failed + 1))
  fi
else
  printf 'ok - sin git: no se comprueba\n'
  passed=$((passed + 1))
fi

printf '\ntests: %s ok · %s fallos\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
