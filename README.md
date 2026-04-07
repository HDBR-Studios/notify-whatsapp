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

## Exemplo de mensagem

```
🚀 Deploy INICIADO
━━━━━━━━━━━━━━━━━
📦 meu-projeto
🌎 🚀 Produção · main

👤 Hildelbrando Lins
💬 fix: ajustes finais
🔖 abc1234

🔗 https://github.com/owner/repo/actions/runs/123
```

## Comportamento

- **Non-blocking**: se a UAZAPI falhar ou a `uazapi_base_url` não estiver configurada, o action sai com `exit 0` (não derruba o workflow)
- **Sem link preview**: a mensagem é enviada com `linkPreview: false`
- **Logs**: imprime status HTTP e resposta da UAZAPI no log do step pra facilitar debug

## Versionamento

Use sempre uma tag fixa (`@v1`) em vez de `@main` pra evitar quebras inesperadas.
