#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# WhatsAgent CRM — Instalador Local para macOS/Linux
#
# Uso remoto (1 comando):
#   bash <(curl -fsSL https://raw.githubusercontent.com/madeinlowcode/agent-whats-web/main/install.sh)
#
# Uso local:
#   chmod +x install.sh && ./install.sh
# ═══════════════════════════════════════════════════════════════════════

set -euo pipefail

# ─── Configuração ──────────────────────────────────────────────────

RELEASE_URL="https://github.com/madeinlowcode/whatsagent-installer/releases/latest/download/whatsagent-crm-v0.1.0-beta.zip"
REPO_NAME="whatsagent-crm"
INSTALL_DIR="$HOME/$REPO_NAME"

# ─── Cores e helpers ────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

step()    { echo -e "\n  ${CYAN}[*]${NC} $1"; }
success() { echo -e "  ${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "  ${YELLOW}[!]${NC} $1"; }
err()     { echo -e "  ${RED}[ERRO]${NC} $1"; }
info()    { echo -e "      ${GRAY}$1${NC}"; }

command_exists() { command -v "$1" &>/dev/null; }

port_in_use() {
    if command_exists lsof; then
        lsof -i ":$1" &>/dev/null
    elif command_exists ss; then
        ss -tuln | grep -q ":$1 "
    else
        return 1
    fi
}

# ─── Banner ─────────────────────────────────────────────────────────

clear
echo ""
echo -e "  ${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "  ${GREEN}║        WhatsAgent CRM — Instalador           ║${NC}"
echo -e "  ${GREEN}║     Assistente IA para WhatsApp Business     ║${NC}"
echo -e "  ${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ─── Detectar ou clonar o projeto ──────────────────────────────────

# Se executando via pipe (curl | bash), BASH_SOURCE não existe
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    SCRIPT_DIR=""
fi

# Verificar se estamos dentro do projeto
PROJECT_DIR=""
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/package.json" ]; then
    PKG_NAME=$(grep -o '"name": *"[^"]*"' "$SCRIPT_DIR/package.json" | head -1 | cut -d'"' -f4)
    if [ "$PKG_NAME" = "whatsagent-crm" ]; then
        PROJECT_DIR="$SCRIPT_DIR"
        info "Projeto encontrado localmente: $PROJECT_DIR"
    fi
fi

# Se não estamos no projeto, baixar ZIP do release
if [ -z "$PROJECT_DIR" ]; then
    # Verificar se diretório já existe
    if [ -d "$INSTALL_DIR" ]; then
        info "Diretorio $INSTALL_DIR ja existe."
        read -p "  Deseja reinstalar/atualizar? (S/N) " reinstall
        if [ "$reinstall" = "S" ] || [ "$reinstall" = "s" ]; then
            step "Baixando nova versao do WhatsAgent CRM..."
            ZIP_PATH="/tmp/whatsagent-crm.zip"
            curl -fsSL "$RELEASE_URL" -o "$ZIP_PATH"
            info "Extraindo arquivos (atualizando)..."
            # Preservar .env ao atualizar
            unzip -o "$ZIP_PATH" -d /tmp/whatsagent-extract >/dev/null 2>&1
            rsync -a --exclude='.env' /tmp/whatsagent-extract/whatsagent-crm/ "$INSTALL_DIR/"
            rm -rf "$ZIP_PATH" /tmp/whatsagent-extract
            success "Projeto atualizado"
        fi
        PROJECT_DIR="$INSTALL_DIR"
    else
        step "Baixando WhatsAgent CRM (~45MB)..."
        ZIP_PATH="/tmp/whatsagent-crm.zip"

        if ! curl -fsSL "$RELEASE_URL" -o "$ZIP_PATH"; then
            err "Falha ao baixar o WhatsAgent CRM."
            info "Verifique sua conexao com a internet."
            info "URL: $RELEASE_URL"
            exit 1
        fi

        info "Extraindo arquivos em $INSTALL_DIR..."
        unzip -q "$ZIP_PATH" -d "$HOME" 2>/dev/null
        rm -f "$ZIP_PATH"

        if [ ! -d "$INSTALL_DIR" ]; then
            err "Falha ao extrair arquivos."
            exit 1
        fi
        success "WhatsAgent CRM instalado em $INSTALL_DIR"
        PROJECT_DIR="$INSTALL_DIR"
    fi
fi

info "Diretorio do projeto: $PROJECT_DIR"

# ─── Detectar OS ───────────────────────────────────────────────────

OS="$(uname -s)"
case "$OS" in
    Darwin) OS_NAME="macOS" ;;
    Linux)  OS_NAME="Linux" ;;
    *)      err "Sistema operacional nao suportado: $OS"; exit 1 ;;
esac
info "Sistema: $OS_NAME"

# ═══════════════════════════════════════════════════════════════════
# ETAPA 1: Verificar Prerequisites
# ═══════════════════════════════════════════════════════════════════

step "Verificando prerequisites..."

# ─── Docker ─────────────────────────────────────────────────────────

if ! command_exists docker; then
    err "Docker nao encontrado."
    echo ""
    if [ "$OS_NAME" = "macOS" ]; then
        warn "Baixe o Docker Desktop em: https://www.docker.com/products/docker-desktop/"
        read -p "  Deseja abrir o link de download? (S/N) " open_link
        if [ "$open_link" = "S" ] || [ "$open_link" = "s" ]; then
            open "https://www.docker.com/products/docker-desktop/"
        fi
    else
        warn "Instale o Docker:"
        info "curl -fsSL https://get.docker.com | sh"
        info "sudo usermod -aG docker \$USER"
    fi
    warn "Apos instalar o Docker, rode este script novamente."
    exit 0
fi

if ! docker info &>/dev/null; then
    err "Docker esta instalado mas o daemon nao esta rodando."
    if [ "$OS_NAME" = "macOS" ]; then
        info "Inicie o Docker Desktop e rode este script novamente."
    else
        info "Inicie o Docker: sudo systemctl start docker"
    fi
    exit 1
fi
success "Docker instalado e rodando"

# ─── Node.js ────────────────────────────────────────────────────────

if command_exists node; then
    NODE_VERSION=$(node --version | sed 's/v//')
    NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
    if [ "$NODE_MAJOR" -ge 20 ]; then
        success "Node.js v$NODE_VERSION encontrado"
    else
        warn "Node.js v$NODE_VERSION encontrado, mas v20+ e necessario."
        NODE_INSTALLED=false
    fi
    NODE_INSTALLED=true
else
    NODE_INSTALLED=false
fi

if [ "$NODE_INSTALLED" = false ]; then
    step "Instalando Node.js 20 LTS..."

    if [ "$OS_NAME" = "macOS" ] && command_exists brew; then
        info "Instalando via Homebrew..."
        brew install node@20
        success "Node.js instalado via Homebrew"
    elif [ "$OS_NAME" = "Linux" ]; then
        if command_exists apt-get; then
            info "Instalando via apt (NodeSource)..."
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt-get install -y nodejs
            success "Node.js instalado via apt"
        elif command_exists dnf; then
            info "Instalando via dnf (NodeSource)..."
            curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
            sudo dnf install -y nodejs
            success "Node.js instalado via dnf"
        else
            err "Gerenciador de pacotes nao reconhecido."
            info "Instale Node.js 20+ manualmente: https://nodejs.org/"
            exit 1
        fi
    else
        err "Nao foi possivel instalar Node.js automaticamente."
        info "Instale manualmente: https://nodejs.org/"
        exit 1
    fi
fi

# ─── pnpm ───────────────────────────────────────────────────────────

if ! command_exists pnpm; then
    step "Instalando pnpm..."
    npm install -g pnpm 2>&1 | tail -1
    if command_exists pnpm; then
        success "pnpm instalado"
    else
        info "Tentando via corepack..."
        corepack enable 2>/dev/null || true
        corepack prepare pnpm@latest --activate 2>/dev/null || true
        if command_exists pnpm; then
            success "pnpm ativado via corepack"
        else
            err "Falha ao instalar pnpm."
            exit 1
        fi
    fi
else
    success "pnpm encontrado"
fi

# ─── Verificar portas ──────────────────────────────────────────────

step "Verificando portas disponiveis..."

PORT_CONFLICT=false
for port_info in "5432:PostgreSQL" "6379:Redis" "3000:Next.js" "3001:API Server"; do
    port="${port_info%%:*}"
    service="${port_info##*:}"
    if port_in_use "$port"; then
        container=$(docker ps --filter "publish=$port" --format "{{.Names}}" 2>/dev/null || true)
        if echo "$container" | grep -q "whatsagent-local"; then
            info "Porta $port ($service) — em uso pelo WhatsAgent (OK)"
        else
            warn "Porta $port ($service) ja esta em uso!"
            PORT_CONFLICT=true
        fi
    else
        info "Porta $port ($service) — disponivel"
    fi
done

if [ "$PORT_CONFLICT" = true ]; then
    read -p "  Portas em conflito. Continuar? (S/N) " continue_anyway
    if [ "$continue_anyway" != "S" ] && [ "$continue_anyway" != "s" ]; then
        info "Libere as portas e rode novamente."
        exit 0
    fi
fi

success "Prerequisites verificados"

# ═══════════════════════════════════════════════════════════════════
# ETAPA 2: Wizard de Configuração
# ═══════════════════════════════════════════════════════════════════

ENV_FILE="$PROJECT_DIR/.env"
SKIP_WIZARD=false

if [ -f "$ENV_FILE" ]; then
    warn "Arquivo .env ja existe."
    read -p "  Deseja reconfigurar? (S/N) " reconfigure
    if [ "$reconfigure" != "S" ] && [ "$reconfigure" != "s" ]; then
        info "Mantendo .env existente."
        SKIP_WIZARD=true
    fi
fi

if [ "$SKIP_WIZARD" = false ]; then
    echo ""
    echo -e "  ${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "  ${CYAN}║         Configuracao do WhatsAgent           ║${NC}"
    echo -e "  ${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""

    # API Key
    while true; do
        read -p "  Sua ANTHROPIC_API_KEY (sk-ant-...): " API_KEY
        if [ -n "$API_KEY" ]; then break; fi
        err "API key e obrigatoria."
    done

    if [[ ! "$API_KEY" == sk-ant-* ]]; then
        warn "Chave nao parece valida (deve comecar com sk-ant-)."
        read -p "  Continuar mesmo assim? (S/N) " proceed
        if [ "$proceed" != "S" ] && [ "$proceed" != "s" ]; then
            exit 0
        fi
    fi

    # Senha admin
    while true; do
        read -p "  Senha do admin (min 6 caracteres): " ADMIN_PASSWORD
        if [ ${#ADMIN_PASSWORD} -ge 6 ]; then break; fi
        err "Senha deve ter pelo menos 6 caracteres."
    done

    # Auto-gerar secrets
    step "Gerando chaves de seguranca..."
    JWT_SECRET=$(openssl rand -hex 32 2>/dev/null || head -c 64 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 64)
    ENCRYPTION_KEY=$(openssl rand -hex 32 2>/dev/null || head -c 64 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 64)
    success "JWT_SECRET e ENCRYPTION_KEY gerados"

    # Gerar .env
    step "Gerando arquivo .env..."

    cat > "$ENV_FILE" << EOF
# WhatsAgent CRM — Gerado pelo instalador em $(date '+%Y-%m-%d %H:%M:%S')

# Anthropic API key
ANTHROPIC_API_KEY=$API_KEY

# Database (PostgreSQL via Docker)
DATABASE_URL=postgresql://whatsagent:whatsagent123@localhost:5432/whatsagent
POSTGRES_PASSWORD=whatsagent123

# Redis (via Docker)
REDIS_URL=redis://localhost:6379

# Security
JWT_SECRET=$JWT_SECRET
ENCRYPTION_KEY=$ENCRYPTION_KEY

# Admin password
ADMIN_PASSWORD=$ADMIN_PASSWORD

# Agent settings
MAX_BUDGET_USD=0.50
AGENT_MODEL=claude-sonnet-4-6

# WhatsApp / Playwright (browser visivel)
HEADLESS=false
POLL_INTERVAL_MS=5000
LOGIN_TIMEOUT_MS=300000
DEBOUNCE_MS=10000

# Knowledge base
KNOWLEDGE_DIR=workspace/memory/knowledge

# Server
API_PORT=3001
EOF

    success "Arquivo .env criado"
fi

# ═══════════════════════════════════════════════════════════════════
# ETAPA 3: Subir Infraestrutura
# ═══════════════════════════════════════════════════════════════════

step "Iniciando PostgreSQL e Redis via Docker..."

cd "$PROJECT_DIR"

PG_HEALTHY=$(docker ps --filter "name=whatsagent-local-postgres" --format "{{.Status}}" 2>/dev/null || true)
REDIS_HEALTHY=$(docker ps --filter "name=whatsagent-local-redis" --format "{{.Status}}" 2>/dev/null || true)

if echo "$PG_HEALTHY" | grep -q "healthy" && echo "$REDIS_HEALTHY" | grep -q "healthy"; then
    success "PostgreSQL e Redis ja estao rodando (healthy)"
else
    docker compose -f docker-compose.infra.yml up -d 2>&1 | tail -3

    info "Aguardando health checks..."
    MAX_WAIT=60
    WAITED=0
    while [ $WAITED -lt $MAX_WAIT ]; do
        sleep 3
        WAITED=$((WAITED + 3))
        PG_STATUS=$(docker ps --filter "name=whatsagent-local-postgres" --format "{{.Status}}" 2>/dev/null || true)
        REDIS_STATUS=$(docker ps --filter "name=whatsagent-local-redis" --format "{{.Status}}" 2>/dev/null || true)
        printf "."
        if echo "$PG_STATUS" | grep -q "healthy" && echo "$REDIS_STATUS" | grep -q "healthy"; then
            break
        fi
    done
    echo ""

    if echo "$PG_STATUS" | grep -q "healthy" && echo "$REDIS_STATUS" | grep -q "healthy"; then
        success "PostgreSQL e Redis rodando (healthy)"
    else
        err "Timeout nos health checks. PG=$PG_STATUS Redis=$REDIS_STATUS"
        info "Verifique: docker compose -f docker-compose.infra.yml ps"
        exit 1
    fi
fi

# ═══════════════════════════════════════════════════════════════════
# ETAPA 4: Instalar Dependências
# ═══════════════════════════════════════════════════════════════════

step "Instalando dependencias (pode demorar 2-5 minutos)..."

cd "$PROJECT_DIR"
pnpm install 2>&1 | grep -E "Done|Packages|added|Progress" || true
success "Dependencias instaladas"

step "Instalando navegador Chromium (~250MB)..."
npx playwright install chromium 2>&1 | grep -E "Downloading|chromium|browser" || true
success "Chromium instalado"

# ═══════════════════════════════════════════════════════════════════
# ETAPA 5: Migrations
# ═══════════════════════════════════════════════════════════════════

step "Rodando migrations do banco..."

cd "$PROJECT_DIR"
if pnpm db:migrate 2>&1 | grep -E "migration|applied|already|done" || true; then
    success "Migrations executadas"
else
    warn "Migrations com warnings. O sistema usa graceful degradation."
fi

# ═══════════════════════════════════════════════════════════════════
# ETAPA 6: Launch Script
# ═══════════════════════════════════════════════════════════════════

step "Criando script de inicializacao..."

LAUNCH_SCRIPT="$PROJECT_DIR/start-whatsagent.sh"
cat > "$LAUNCH_SCRIPT" << LAUNCH
#!/usr/bin/env bash
# WhatsAgent CRM — Script de inicializacao
cd "$PROJECT_DIR"

# Verificar se infra esta rodando
PG=\$(docker ps --filter "name=whatsagent-local-postgres" --format "{{.Status}}" 2>/dev/null || true)
if ! echo "\$PG" | grep -q "healthy"; then
    echo "Iniciando PostgreSQL e Redis..."
    docker compose -f docker-compose.infra.yml up -d
    sleep 10
fi

echo "Iniciando WhatsAgent CRM..."
echo "  Frontend: http://localhost:3000"
echo "  API:      http://localhost:3001"
echo "  Pressione Ctrl+C para parar"
echo ""
pnpm start
LAUNCH

chmod +x "$LAUNCH_SCRIPT"
success "Script criado: $LAUNCH_SCRIPT"

# Desktop shortcut (Linux only)
if [ "$OS_NAME" = "Linux" ] && [ -d "$HOME/Desktop" ]; then
    DESKTOP_FILE="$HOME/Desktop/whatsagent-crm.desktop"
    cat > "$DESKTOP_FILE" << DESKTOP
[Desktop Entry]
Name=WhatsAgent CRM
Comment=Assistente IA para WhatsApp Business
Exec=bash -c 'cd "$PROJECT_DIR" && ./start-whatsagent.sh'
Terminal=true
Type=Application
Categories=Office;
DESKTOP
    chmod +x "$DESKTOP_FILE"
    info "Atalho criado no Desktop"
fi

# ═══════════════════════════════════════════════════════════════════
# ETAPA 7: Finalização
# ═══════════════════════════════════════════════════════════════════

echo ""
echo -e "  ${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "  ${GREEN}║      Instalacao concluida com sucesso!       ║${NC}"
echo -e "  ${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Proximos passos:"
echo -e "    ${GRAY}1. O sistema vai iniciar agora${NC}"
echo -e "    ${GRAY}2. Acesse http://localhost:3000 no navegador${NC}"
echo -e "    ${GRAY}3. Login: admin@whatsagent.com / (senha definida)${NC}"
echo -e "    ${GRAY}4. Va em 'Sessoes' para conectar seu WhatsApp${NC}"
echo ""
echo -e "  Para iniciar futuramente:"
echo -e "    ${GRAY}./start-whatsagent.sh${NC}"
echo ""

read -p "  Deseja iniciar o WhatsAgent agora? (S/N) " start_now

if [ "$start_now" = "S" ] || [ "$start_now" = "s" ]; then
    step "Iniciando WhatsAgent CRM..."
    info "API Server: http://localhost:3001"
    info "Frontend:   http://localhost:3000"
    info "Pressione Ctrl+C para parar"
    echo ""

    # Abrir browser após delay
    (sleep 15 && {
        if [ "$OS_NAME" = "macOS" ]; then
            open "http://localhost:3000"
        elif command_exists xdg-open; then
            xdg-open "http://localhost:3000"
        fi
    }) &

    cd "$PROJECT_DIR"
    pnpm start
else
    echo ""
    success "Tudo pronto! Use ./start-whatsagent.sh para iniciar."
    echo ""
fi
