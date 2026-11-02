#!/usr/bin/env bash
# Gera o app bundle de release com os IDs de produção, conferindo tudo antes.
#
# Os valores vêm de `release.env.json` na raiz (fora do git; modelo em
# tool/release.env.example.json), passados por `--dart-define-from-file`.
# Assim o comando não depende de colar oito flags à mão — esquecer uma não
# quebra o build, só deixa aquele funil sem anúncio, e ninguém percebe.
#
# Checagens antes de compilar:
#   - toda unidade lida em ad_ids.dart tem chave no arquivo  -> FALHA
#   - unidade vazia                                          -> FALHA
#     (com --allow-missing vira AVISO: serve para a trilha de teste
#      interno enquanto o AdMob não tem todas as unidades)
#   - ID de teste do Google (3940256099942544)               -> FALHA
#   - PRIVACY_POLICY_URL vazio ou sem https                  -> FALHA
#     (com --allow-missing vira AVISO)
# Depois de compilar: tool/check_admob_ids.sh e a assinatura do .aab
# (não pode ser a chave de debug).
#
# Uso: tool/build_release.sh [--allow-missing] [--env arquivo.json]
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE="release.env.json"
ALLOW_MISSING=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-missing) ALLOW_MISSING=1 ;;
    --env) ENV_FILE="${2:?--env pede um arquivo}"; shift ;;
    *) echo "opção desconhecida: $1"; exit 2 ;;
  esac
  shift
done

if [[ ! -f "$ENV_FILE" ]]; then
  echo "FALHA: $ENV_FILE não existe. Copie tool/release.env.example.json e preencha."
  exit 1
fi

# Lê um valor do JSON sem depender de jq (python3 vem com o macOS).
value_of() {
  python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], "__MISSING__"))' \
    "$ENV_FILE" "$1"
}

fail=0
warn=0
problem() { # $1 = mensagem; vira aviso com --allow-missing
  if [[ $ALLOW_MISSING -eq 1 ]]; then echo "AVISO: $1"; warn=1; else echo "FALHA: $1"; fail=1; fi
}

units=$(grep -oE "'ADMOB_[A-Z_]+'" lib/core/ads/ad_ids.dart | tr -d "'" | sort -u)
for unit in $units; do
  v=$(value_of "$unit")
  if [[ "$v" == "__MISSING__" ]]; then
    echo "FALHA: $unit não está em $ENV_FILE"; fail=1
  elif [[ -z "$v" ]]; then
    problem "$unit vazio: esse funil fica sem anúncio no release"
  elif [[ "$v" == *3940256099942544* ]]; then
    echo "FALHA: $unit é ID de TESTE do Google"; fail=1
  elif [[ ! "$v" =~ ^ca-app-pub-[0-9]{16}/[0-9]{10}$ ]]; then
    echo "FALHA: $unit não parece uma unidade do AdMob ($v)"; fail=1
  fi
done

url=$(value_of PRIVACY_POLICY_URL)
if [[ "$url" == "__MISSING__" || -z "$url" ]]; then
  problem "PRIVACY_POLICY_URL vazio: o app sai sem link de privacidade (não publicável em produção)"
elif [[ "$url" != https://* ]]; then
  echo "FALHA: PRIVACY_POLICY_URL precisa ser https ($url)"; fail=1
fi

if [[ ! -f android/key.properties ]]; then
  echo "FALHA: android/key.properties ausente; o release sairia com a chave de debug"; fail=1
fi

if [[ $fail -ne 0 ]]; then exit 1; fi

flutter build appbundle --release --dart-define-from-file="$ENV_FILE"

tool/check_admob_ids.sh

AAB=build/app/outputs/bundle/release/app-release.aab
owner=$(keytool -printcert -jarfile "$AAB" | grep -m1 'Owner:' || true)
echo "assinatura: $owner"
if [[ "$owner" == *"Android Debug"* || -z "$owner" ]]; then
  echo "FALHA: o .aab não está assinado com a chave de upload"; exit 1
fi

echo
echo "ok: $AAB ($(du -h "$AAB" | cut -f1))"
if [[ $warn -ne 0 ]]; then
  echo "Há avisos acima: serve para teste interno, não para produção."
fi
