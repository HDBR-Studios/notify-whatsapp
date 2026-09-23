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
| `github_token` | não | Default `${{ github.token }}`. Só serve para descobrir a duração quando `start` e `success` estão em **jobs diferentes**; sem ele a mensagem sai sem a linha de tempo nesse caso |

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

- **🖥️ Runner** — em máquina nossa sai o nome do runner (`guzz-harness-runner-1`,
  `macpro-runner-3`) com a marca `· nosso`; no GitHub sai `GitHub-hosted`. Existe
  porque os deploys da frota pedem `runs-on: [self-hosted, linux, arm64, hdbr]`, que
  é um **label e não uma máquina**: o mesmo job cai no guzz hoje e num macpro amanhã,
  e o aviso saía igual nos dois casos. Quando um runner nosso adoece, esta linha diz
  para qual máquina ir sem precisar abrir o run.
- **⏱️ Duração** — tempo entre o aviso de `start` e o de fechamento. O `start`
  grava o relógio em `$RUNNER_TEMP`; se o fechamento acontece em outro job, o
  início vem de `run_started_at` pela API. Sem nenhuma das duas fontes, a linha
  simplesmente não aparece.
- **🔁 Tentativa N** — aparece a partir do 2º `run_attempt`. Re-run do mesmo
  commit já foi lido como deploy novo.
- **🖐️ / ⏰ / ⚡ Disparo** — marca `workflow_dispatch`, `schedule` e outros
  eventos. Nesses casos não existe `head_commit`: antes o autor e a mensagem
  saíam **em branco**; agora caem para `@actor` e para o assunto do último commit.

## Comportamento

- **Non-blocking**: se a UAZAPI falhar ou a `uazapi_base_url` não estiver configurada, o action sai com `exit 0` (não derruba o workflow)
- **Sem link preview**: a mensagem é enviada com `linkPreview: false`
- **Logs**: imprime a mensagem montada, o status HTTP, a resposta da UAZAPI e o runner usado. O grupo de destino mora num secret — sem esse log o repositório fica mudo sobre o que foi enviado e para onde

## Versionamento

Use sempre uma tag fixa (`@v1`) em vez de `@main` pra evitar quebras inesperadas.
A `v1` é móvel: ela anda junto com as melhorias compatíveis (a linha do runner
entrou nela em 23/09/2026, na `v1.1`). Consumidores hoje: `app-hdbr-ihub`,
`groupanel-v2`, `studio-app`, `fatura-hub`, `prompt-pages-funnel`.
