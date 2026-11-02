#!/usr/bin/env bash
# Guard contra ID de teste do AdMob onde ele não deve estar.
#
# O prefixo 3940256099942544 é o dos IDs de TESTE oficiais do Google. Eles são
# legítimos em desenvolvimento, então a regra não é "nunca aparece": é "só
# aparece onde está previsto", e nunca no que vai para a loja.
#
# Checagens:
#   1. arquivo versionado FORA da lista de permitidos com o prefixo  -> FALHA
#   2. manifest mesclado do release (se já foi gerado) com o prefixo -> FALHA
#   3. Info.plist ainda com o App ID de teste do iOS                 -> AVISO
#      (vira FALHA com --strict; use --strict antes de enviar o app do iOS)
#
# Uso:  tool/check_admob_ids.sh [--strict]
set -euo pipefail

cd "$(dirname "$0")/.."

PREFIX="3940256099942544"
STRICT=0
[[ "${1:-}" == "--strict" ]] && STRICT=1

# Onde o ID de teste é esperado:
#  - ad_ids.dart: o fallback de debug/profile
#  - build.gradle.kts: App ID de debug (manifestPlaceholders)
#  - Info.plist: App ID do iOS, até o app iOS ser cadastrado no AdMob
#  - docs, README, CLAUDE.md, este script e os testes: só o mencionam
ALLOWED='^(lib/core/ads/ad_ids\.dart|android/app/build\.gradle\.kts|ios/Runner/Info\.plist|docs/.*|README\.md|CLAUDE\.md|tool/check_admob_ids\.sh|test/.*)$'

fail=0
warn=0

# 1. versionados fora da lista
leaks=$(git ls-files | grep -vE "$ALLOWED" | xargs grep -l "$PREFIX" 2>/dev/null || true)
if [[ -n "$leaks" ]]; then
  echo "FALHA: ID de teste do AdMob em arquivo não previsto:"
  echo "$leaks" | sed 's/^/  - /'
  fail=1
fi

# 2. manifest mesclado do release
release_manifest=$(find build/app/intermediates/merged_manifest/release -name AndroidManifest.xml 2>/dev/null | head -1 || true)
if [[ -n "$release_manifest" ]]; then
  if grep -q "$PREFIX" "$release_manifest"; then
    echo "FALHA: o manifest do RELEASE tem o App ID de teste ($release_manifest)"
    fail=1
  else
    echo "ok: manifest mesclado do release sem ID de teste"
  fi
else
  echo "aviso: manifest do release ainda não foi gerado (rode o build para checar)"
fi

# 3. iOS ainda em teste
if grep -q "$PREFIX" ios/Runner/Info.plist; then
  echo "AVISO: ios/Runner/Info.plist ainda usa o App ID de teste (iOS não publicável)"
  warn=1
fi

if [[ $fail -ne 0 ]]; then exit 1; fi
if [[ $warn -ne 0 && $STRICT -eq 1 ]]; then
  echo "FALHA (--strict): há avisos pendentes"
  exit 1
fi
echo "check_admob_ids: ok"
