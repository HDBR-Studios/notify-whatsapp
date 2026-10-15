# notify-whatsapp

Composite GitHub Action que envia notificação de deploy para um grupo WhatsApp via [UAZAPI](https://uazapi.com).

## Uso

```yaml
- uses: HDBR/notify-whatsapp@v1
  with:
    status: success            # start | success | failure
    project: meu-projeto
    prod_url: https://meu.app  # opcional, exibido em success
    failed_step: Vercel Deploy # opcional, exibido em failure
    uazapi_token: ${{ secrets.UAZAPI_LARISSA_TOKEN }}
    uazapi_base_url: ${{ vars.UAZAPI_BASE_URL }}
    group_jid: ${{ secrets.WHATSAPP_GROUP_JID }}
```

## Inputs

| Input | Required | Descrição |
|-------|----------|-----------|
| `status` | sim | `start`, `success` ou `failure` |
| `project` | sim | Nome do projeto (display) |
| `uazapi_token` | sim | Token UAZAPI da instância |
| `uazapi_base_url` | sim | URL base da UAZAPI (ex: `https://rafahdbrimpa.uazapi.com`) |
| `group_jid` | sim | JID do grupo WhatsApp destino |
| `prod_url` | não | URL de produção (exibida em sucesso) |
| `failed_step` | não | Nome do passo que falhou (exibido em failure) |
| `github_token` | não | Default `${{ github.token }}`. Serve para descobrir a duração quando `start` e `success` estão em **jobs diferentes** e para achar o **autor da PR** num push de merge; sem ele essas duas coisas caem para o comportamento antigo |

## Exemplo de mensagem

```
✅ Deploy CONCLUÍDO
━━━━━━━━━━━━━━━━━
📦 iHub
🌎 🚀 Produção · main
🌐 https://ihub.hdbr.studio
🖥️ guzz-harness-runner-1 · nosso (Linux/ARM64)
⏱️ 4m12s

👤 Hildelbrando Lins
💬 fix: ajustes finais
🔖 abc1234

🔗 https://github.com/owner/repo/actions/runs/123
```

## O que cada linha responde

- **🖥️ Runner** — em máquina nossa sai o nome do runner (`zeus-groupanel-1`,
  `macpro-runner-3`) com a marca `· nosso`; no GitHub sai `GitHub-hosted`. Existe
  porque os deploys da frota pedem `runs-on: [self-hosted, linux, arm64, hdbr]`, que
  é um **label e não uma máquina**: o mesmo job cai no zeus hoje e num macpro amanhã,
  e o aviso saía igual nos dois casos. Quando um runner nosso adoece, esta linha diz
  para qual máquina ir sem precisar abrir o run.

  O runner reportado é o de **quem fez o trabalho**, não o deste step. Em
  `groupanel-v2` e `fatura-hub` o aviso mora num job próprio que cai em
  GitHub-hosted enquanto o deploy roda em máquina nossa — reportar o runner local
  faria a linha nascer mentindo. Com token, a action lê os jobs do run: se
  **qualquer** job caiu em máquina nossa, são esses nomes que aparecem. O os/arch
  só entra quando o trabalho e o aviso estão no mesmo runner (é a única situação em
  que são o mesmo hardware). Sem token, sobra o runner local.
- **⏱️ Duração** — tempo entre o aviso de `start` e o de fechamento. O `start`
  grava o relógio em `$RUNNER_TEMP`; se o fechamento acontece em outro job, o
  início vem de `run_started_at` pela API. Sem nenhuma das duas fontes, a linha
  simplesmente não aparece.
- **🔁 Tentativa N** — aparece a partir do 2º `run_attempt`. Re-run do mesmo
  commit já foi lido como deploy novo.
- **🖐️ / ⏰ / ⚡ Disparo** — marca `workflow_dispatch`, `schedule` e outros
  eventos. Nesses casos não existe `head_commit`: antes o autor e a mensagem
  saíam **em branco**; agora caem para `@actor` e para o assunto do último commit.

- **👤 Autor** — num `push` que veio do merge de uma PR, sai o autor da PR e
  quem mergeou: `Lucas (PR #240) · mergeado por Hildelbrando` (só
  `Lucas (PR #240)` quando o autor mergeou a própria PR). Existe porque o
  `head_commit.author` de um merge é **quem clicou em merge**: em 15/10/2026 a
  PR #240 do criart-convex era do Lucas e o aviso disse "Hildelbrando Lins".
  A PR só é atribuída se o `merge_commit_sha` dela for o próprio commit do
  deploy. Sem PR (push direto, `workflow_dispatch`, `schedule`) ou sem
  permissão, fica o autor do commit, como antes.

  **Permissão:** `commits/{sha}/pulls` exige `pull-requests: read`, que o token
  padrão restrito (`contents`/`metadata`/`packages`) não tem. Por isso há uma
  2ª porta: o número da PR na mensagem do merge (`Merge pull request #N`, ou
  `(#N)` do squash) abre `pulls/{n}`. Para não depender dela, o workflow do
  consumidor pode declarar:

  ```yaml
  permissions:
    contents: read
    pull-requests: read
    actions: read   # também devolve a duração quando o aviso está em outro job
  ```

  Atenção: um bloco `permissions:` zera o que não estiver listado; confira o
  que o resto do workflow usa antes de colocá-lo.

## Comportamento

- **Non-blocking**: se a UAZAPI falhar ou a `uazapi_base_url` não estiver configurada, o action sai com `exit 0` (não derruba o workflow)
- **Sem link preview**: a mensagem é enviada com `linkPreview: false`
- **Logs**: imprime a mensagem montada, o status HTTP, a resposta da UAZAPI e o runner usado. O grupo de destino mora num secret — sem esse log o repositório fica mudo sobre o que foi enviado e para onde

## Testes

`tests/*.test.sh` rodam a action **sem rede e sem envio** (o `curl` vira dublê
com fixtures da API) e entram no CI em toda PR. O `selftest.yml` roda a action
de verdade no Actions, também sem enviar.

## Versionamento

Use sempre uma tag fixa (`@v1`) em vez de `@main` pra evitar quebras inesperadas.
A `v1` é móvel: ela anda junto com as melhorias compatíveis (a linha do runner
entrou nela em 23/09/2026, na `v1.1`). O autor da PR entra na `v1.2`; mover
a `v1` para ela é decisão à parte, depois de conferir os consumidores. Consumidores hoje: `app-hdbr-ihub`,
`groupanel-v2`, `studio-app`, `fatura-hub`, `prompt-pages-funnel`.
