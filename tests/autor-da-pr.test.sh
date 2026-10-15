#!/usr/bin/env bash
# Prova a linha "Autor" do aviso SEM rede e SEM mandar WhatsApp.
#
# Extrai o `run:` do action.yml, troca o `curl` por um dublê que responde a
# API do GitHub com fixtures (ou 403, para simular o token padrão restrito
# dos consumidores) e confere a mensagem montada. `UAZAPI_BASE_URL` vazia faz
# a action sair antes do envio.
set -u
AQUI=$(cd "$(dirname "$0")" && pwd)
RAIZ=$(dirname "$AQUI")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

python3 - "$RAIZ/action.yml" > "$TMP/run.sh" <<'PY'
import sys, yaml
print(yaml.safe_load(open(sys.argv[1]))["runs"]["steps"][0]["run"])
PY

mkdir -p "$TMP/bin"
cat > "$TMP/bin/curl" <<'STUB'
#!/usr/bin/env bash
url="${@: -1}"
echo "$url" >> "$STUB_LOG"
path="${url#"$API_URL"/}"
for negado in ${STUB_NEGA:-}; do
  case "$path" in
    $negado*) echo '{"message":"Resource not accessible by integration","status":"403"}'; exit 0 ;;
  esac
done
case "$path" in
  repos/o/r/commits/*/pulls) cat "$STUB_DIR/lista.json" 2>/dev/null || echo '[]' ;;
  repos/o/r/pulls/240)       cat "$STUB_DIR/pr240.json" ;;
  repos/o/r/pulls/12)        cat "$STUB_DIR/pr12.json" ;;
  repos/o/r/actions/*)       echo '{}' ;;
  users/lpalmeidabh)         echo '{"login":"lpalmeidabh","name":"Lucas Almeida"}' ;;
  users/HDBR)                echo '{"login":"HDBR","name":"Hildelbrando Lins"}' ;;
  users/*)                   echo '{"login":"x","name":null}' ;;
  *)                         echo '{}' ;;
esac
STUB
chmod +x "$TMP/bin/curl"

SHA_MERGE=21e3469ede1d6218db381802726a73a65defb5ba
mkdir -p "$TMP/fx"
cat > "$TMP/fx/lista.json" <<EOF
[{"number":240,"user":{"login":"lpalmeidabh"},"merged_at":"2026-10-15T08:14:16Z","merge_commit_sha":"$SHA_MERGE"}]
EOF
cat > "$TMP/fx/pr240.json" <<EOF
{"number":240,"user":{"login":"lpalmeidabh"},"merged_by":{"login":"HDBR"},"merged_at":"2026-10-15T08:14:16Z","merge_commit_sha":"$SHA_MERGE"}
EOF
cat > "$TMP/fx/pr12.json" <<'EOF'
{"number":12,"user":{"login":"lpalmeidabh"},"merged_by":{"login":"HDBR"},"merged_at":"2026-09-01T10:00:00Z","merge_commit_sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
EOF

FALHAS=0
# roda <nome> <esperado na linha Autor> [VAR=valor ...]
roda() {
  local nome="$1" esperado="$2"; shift 2
  : > "$TMP/stub.log"
  local saida
  saida=$(env -i PATH="$TMP/bin:/usr/bin:/bin" HOME="$TMP" RUNNER_TEMP="$TMP" \
    STUB_LOG="$TMP/stub.log" STUB_DIR="$TMP/fx" \
    STATUS=success PROJECT=teste UAZAPI_BASE_URL="" GH_TOKEN=tok \
    BRANCH=staging SHA="$SHA_MERGE" REPO=o/r SERVER_URL=https://github.com \
    API_URL=https://api.github.com RUN_ID=1 RUN_ATTEMPT=1 EVENT_NAME=push \
    ACTOR=HDBR AUTHOR="Hildelbrando Lins" \
    COMMIT_MSG="Merge pull request #240 from o/develop" \
    RUNNER_NAME_="GitHub Actions 1" RUNNER_OS_=Linux RUNNER_ARCH_=X64 \
    "$@" bash "$TMP/run.sh" 2>&1)
  local linha
  linha=$(printf '%s\n' "$saida" | grep -F '• *Autor:*' | head -1)
  if [ "$linha" = "• *Autor:* $esperado" ]; then
    echo "ok   $nome"
  else
    echo "FALHA $nome"
    echo "     esperado: • *Autor:* $esperado"
    echo "     veio:     $linha"
    FALHAS=$((FALHAS + 1))
  fi
  ULTIMA_SAIDA="$saida"
}

roda "merge de PR, token lê PRs" \
  "Lucas (PR #240) · mergeado por Hildelbrando"

roda "token padrão restrito: lista 403, acha pelo número do merge" \
  "Lucas (PR #240) · mergeado por Hildelbrando" \
  STUB_NEGA="repos/o/r/commits/"

roda "squash \"(#240)\" com lista 403" \
  "Lucas (PR #240) · mergeado por Hildelbrando" \
  STUB_NEGA="repos/o/r/commits/" COMMIT_MSG="feat: tela nova (#240)"

roda "sem permissão nenhuma em PR: autor do commit, como antes" \
  "Hildelbrando Lins" \
  STUB_NEGA="repos/o/r/commits/ repos/o/r/pulls/"

roda "push direto, sem PR" \
  "Hildelbrando Lins" \
  STUB_DIR="$TMP/vazio" COMMIT_MSG="fix: ajuste direto na main"

roda "\"(#12)\" de PR que não gerou ESTE commit: não atribui" \
  "Hildelbrando Lins" \
  STUB_NEGA="repos/o/r/commits/" COMMIT_MSG="chore: reaplica x (#12)"
grep -q '/pulls/12$' "$TMP/stub.log" \
  || { echo "FALHA não chegou a conferir a PR #12"; FALHAS=$((FALHAS + 1)); }

sed -i 's/"merged_by":{"login":"HDBR"}/"merged_by":{"login":"lpalmeidabh"}/' "$TMP/fx/pr240.json"
roda "autor mergeou a própria PR (merged_by = autor)" \
  "Lucas (PR #240)"
sed -i 's/"merged_by":{"login":"lpalmeidabh"}/"merged_by":null/' "$TMP/fx/pr240.json"
roda "merged_by ausente: cai para o actor do push" \
  "Lucas (PR #240) · mergeado por Hildelbrando"

roda "workflow_dispatch: sem busca de PR" \
  "@HDBR" \
  EVENT_NAME=workflow_dispatch AUTHOR="" COMMIT_MSG=""
if grep -q '/pulls' "$TMP/stub.log"; then
  echo "FALHA workflow_dispatch consultou PR"; FALHAS=$((FALHAS + 1))
fi

roda "sem github_token: autor do commit" \
  "Hildelbrando Lins" \
  GH_TOKEN=""

# A mensagem continua inteira (título), não só a linha do autor.
printf '%s\n' "$ULTIMA_SAIDA" | grep -q '^✅ \*Deploy concluído:\* teste' \
  || { echo "FALHA mensagem sem título"; FALHAS=$((FALHAS + 1)); }

echo
[ "$FALHAS" -eq 0 ] && echo "tudo ok" || echo "$FALHAS falha(s)"
exit "$FALHAS"
