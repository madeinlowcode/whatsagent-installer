# WhatsAgent CRM — Instalador

Instalador local do WhatsAgent CRM para Windows, macOS e Linux.

## Instalacao rapida

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/madeinlowcode/whatsagent-installer/main/install.ps1 -OutFile install.ps1; .\install.ps1
```

### macOS / Linux

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/madeinlowcode/whatsagent-installer/main/install.sh)
```

## O que o instalador faz

1. Verifica e instala prerequisites (Docker Desktop, Node.js 20+, pnpm)
2. Baixa o WhatsAgent CRM (~45MB)
3. Wizard interativo: coleta API key + senha admin, gera chaves de seguranca
4. Sobe PostgreSQL e Redis via Docker
5. Instala dependencias e navegador Chromium
6. Roda migrations do banco de dados
7. Cria atalho no desktop e inicia o sistema

## Prerequisites

- **Docker Desktop** — para PostgreSQL e Redis
- **Node.js 20+** — instalado automaticamente via winget (Windows) ou brew/apt (macOS/Linux)
- **Conexao com internet** — para baixar dependencias

## Apos a instalacao

1. Acesse `http://localhost:3000` no navegador
2. Login com: `admin@whatsagent.com` / (senha definida no wizard)
3. Va em **Sessoes** para conectar seu WhatsApp (escaneie o QR code)
4. Crie agentes em **Agentes** e comece a atender

## Troubleshooting

| Problema | Solucao |
|---|---|
| Docker nao inicia | Verifique que Docker Desktop esta aberto e rodando |
| Porta 5432 em uso | Pare outro PostgreSQL: `docker stop` ou desinstale |
| PowerShell bloqueia script | Execute: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| Chromium nao abre | Verifique antivirus, pode bloquear Playwright |
| Erro nas migrations | Verifique se PostgreSQL esta healthy: `docker ps` |

## Desinstalar

```bash
# Parar containers
docker compose -f ~/whatsagent-crm/docker-compose.infra.yml down -v

# Remover projeto
rm -rf ~/whatsagent-crm
```
