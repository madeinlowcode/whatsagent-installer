# ═══════════════════════════════════════════════════════════════════════
# WhatsAgent CRM — Instalador Local para Windows
#
# Uso remoto (1 comando):
#   irm https://raw.githubusercontent.com/madeinlowcode/whatsagent-installer/main/install.ps1 -OutFile install.ps1; .\install.ps1
#
# Uso local:
#   .\install.ps1
# ═══════════════════════════════════════════════════════════════════════

#Requires -Version 5.1
$ErrorActionPreference = "Stop"

# ─── Configuração ──────────────────────────────────────────────────

$RELEASE_URL = "https://github.com/madeinlowcode/whatsagent-installer/releases/latest/download/whatsagent-crm-v0.1.0-beta.zip"
$REPO_NAME = "whatsagent-crm"
$INSTALL_DIR = Join-Path $env:USERPROFILE $REPO_NAME

# ─── Cores e helpers ────────────────────────────────────────────────

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "  [*] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  [!] $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host "  [ERRO] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "      $Message" -ForegroundColor Gray
}

function Test-Command {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

function Test-PortInUse {
    param([int]$Port)
    $connection = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    return ($null -ne $connection)
}

# ─── Banner ─────────────────────────────────────────────────────────

Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║        WhatsAgent CRM — Instalador           ║" -ForegroundColor Green
Write-Host "  ║     Assistente IA para WhatsApp Business     ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# ─── Verificar ExecutionPolicy ──────────────────────────────────────

$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq "Restricted") {
    Write-Warn "ExecutionPolicy esta como 'Restricted'. Ajustando para 'RemoteSigned'..."
    try {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Success "ExecutionPolicy ajustada para RemoteSigned"
    } catch {
        Write-Err "Nao foi possivel ajustar ExecutionPolicy."
        Write-Info "Execute manualmente: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"
        exit 1
    }
}

# ─── Detectar ou clonar o projeto ──────────────────────────────────

# Se estamos dentro do projeto (execução local), usar diretório atual
if (Test-Path (Join-Path (Get-Location) "package.json")) {
    $packageJson = Get-Content (Join-Path (Get-Location) "package.json") -Raw | ConvertFrom-Json
    if ($packageJson.name -eq "whatsagent-crm") {
        $ProjectDir = (Get-Location).Path
        Write-Info "Projeto encontrado localmente: $ProjectDir"
    }
}

# Se não estamos no projeto, baixar ZIP do release
if (-not $ProjectDir) {
    # Verificar se diretório já existe (instalação anterior)
    if (Test-Path $INSTALL_DIR) {
        Write-Info "Diretorio $INSTALL_DIR ja existe."
        $reinstall = Read-Host "  Deseja reinstalar/atualizar? (S/N)"
        if ($reinstall -eq "S" -or $reinstall -eq "s") {
            Write-Step "Baixando nova versao do WhatsAgent CRM..."
            $zipPath = Join-Path $env:TEMP "whatsagent-crm.zip"
            Invoke-WebRequest -Uri $RELEASE_URL -OutFile $zipPath -UseBasicParsing
            Write-Info "Extraindo arquivos (atualizando)..."
            Expand-Archive -Path $zipPath -DestinationPath $env:TEMP -Force
            # Copiar arquivos novos sobre os existentes (preserva .env e dados)
            $extractedDir = Join-Path $env:TEMP "whatsagent-crm"
            Copy-Item -Path "$extractedDir\*" -Destination $INSTALL_DIR -Recurse -Force -Exclude ".env"
            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
            Remove-Item $extractedDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Success "Projeto atualizado"
        }
        $ProjectDir = $INSTALL_DIR
    } else {
        Write-Step "Baixando WhatsAgent CRM (~45MB)..."
        $zipPath = Join-Path $env:TEMP "whatsagent-crm.zip"

        try {
            Invoke-WebRequest -Uri $RELEASE_URL -OutFile $zipPath -UseBasicParsing
        } catch {
            Write-Err "Falha ao baixar o WhatsAgent CRM."
            Write-Info "Verifique sua conexao com a internet e tente novamente."
            Write-Info "URL: $RELEASE_URL"
            exit 1
        }

        Write-Info "Extraindo arquivos em $INSTALL_DIR..."
        Expand-Archive -Path $zipPath -DestinationPath $env:USERPROFILE -Force
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

        if (-not (Test-Path $INSTALL_DIR)) {
            Write-Err "Falha ao extrair arquivos."
            exit 1
        }
        Write-Success "WhatsAgent CRM instalado em $INSTALL_DIR"
        $ProjectDir = $INSTALL_DIR
    }
}

Write-Info "Diretorio do projeto: $ProjectDir"

# ═══════════════════════════════════════════════════════════════════
# ETAPA 1: Verificar Prerequisites
# ═══════════════════════════════════════════════════════════════════

Write-Step "Verificando prerequisites..."

# ─── Docker Desktop ─────────────────────────────────────────────────

$dockerInstalled = Test-Command "docker"
if (-not $dockerInstalled) {
    Write-Err "Docker Desktop nao encontrado."
    Write-Host ""
    Write-Host "  O Docker Desktop e necessario para rodar PostgreSQL e Redis." -ForegroundColor Yellow
    Write-Host "  Baixe e instale em:" -ForegroundColor Yellow
    Write-Host "  https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe" -ForegroundColor White
    Write-Host ""

    $openLink = Read-Host "  Deseja abrir o link de download agora? (S/N)"
    if ($openLink -eq "S" -or $openLink -eq "s") {
        Start-Process "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
    }

    Write-Host ""
    Write-Warn "Apos instalar o Docker Desktop, rode este script novamente."
    exit 0
}

# Verificar se Docker daemon está rodando
try {
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Docker daemon not running"
    }
    Write-Success "Docker Desktop instalado e rodando"
} catch {
    Write-Err "Docker Desktop esta instalado mas nao esta rodando."
    Write-Info "Inicie o Docker Desktop e rode este script novamente."
    exit 1
}

# ─── Node.js ────────────────────────────────────────────────────────

$nodeInstalled = Test-Command "node"
if ($nodeInstalled) {
    $nodeVersion = (node --version) -replace 'v', ''
    $nodeMajor = [int]($nodeVersion.Split('.')[0])
    if ($nodeMajor -ge 20) {
        Write-Success "Node.js v$nodeVersion encontrado"
    } else {
        Write-Warn "Node.js v$nodeVersion encontrado, mas v20+ e necessario."
        $nodeInstalled = $false
    }
}

if (-not $nodeInstalled) {
    Write-Step "Instalando Node.js 20 LTS..."

    $wingetAvailable = Test-Command "winget"
    if ($wingetAvailable) {
        Write-Info "Instalando via winget (pode demorar 1-2 minutos)..."
        winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-Null

        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        if (Test-Command "node") {
            Write-Success "Node.js instalado com sucesso via winget"
        } else {
            Write-Warn "Node.js instalado mas nao encontrado no PATH."
            Write-Info "Feche e reabra o terminal, depois rode este script novamente."
            exit 1
        }
    } else {
        Write-Err "Node.js nao encontrado e winget nao disponivel."
        Write-Host ""
        Write-Info "Baixe e instale Node.js 20 LTS em:"
        Write-Host "  https://nodejs.org/dist/v20.18.0/node-v20.18.0-x64.msi" -ForegroundColor White
        Write-Host ""
        $openLink = Read-Host "  Deseja abrir o link de download? (S/N)"
        if ($openLink -eq "S" -or $openLink -eq "s") {
            Start-Process "https://nodejs.org/en/download/"
        }
        Write-Warn "Apos instalar Node.js, rode este script novamente."
        exit 0
    }
}

# ─── pnpm ───────────────────────────────────────────────────────────

$pnpmInstalled = Test-Command "pnpm"
if (-not $pnpmInstalled) {
    Write-Step "Instalando pnpm..."
    npm install -g pnpm 2>&1 | Out-Null

    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    if (Test-Command "pnpm") {
        Write-Success "pnpm instalado com sucesso"
    } else {
        Write-Warn "pnpm instalado mas nao encontrado no PATH. Tentando corepack..."
        corepack enable 2>&1 | Out-Null
        corepack prepare pnpm@latest --activate 2>&1 | Out-Null
        if (Test-Command "pnpm") {
            Write-Success "pnpm ativado via corepack"
        } else {
            Write-Err "Falha ao instalar pnpm. Feche e reabra o terminal."
            exit 1
        }
    }
} else {
    Write-Success "pnpm encontrado"
}

# ─── Verificar portas ──────────────────────────────────────────────

Write-Step "Verificando portas disponiveis..."

$portsToCheck = @(
    @{ Port = 5432; Service = "PostgreSQL" },
    @{ Port = 6379; Service = "Redis" },
    @{ Port = 3000; Service = "Next.js (frontend)" },
    @{ Port = 3001; Service = "API Server" }
)

$portConflict = $false
foreach ($p in $portsToCheck) {
    if (Test-PortInUse -Port $p.Port) {
        # Verificar se é um container Docker nosso
        $containerName = docker ps --filter "publish=$($p.Port)" --format "{{.Names}}" 2>$null
        if ($containerName -match "whatsagent-local") {
            Write-Info "Porta $($p.Port) ($($p.Service)) — em uso pelo WhatsAgent (OK)"
        } else {
            Write-Warn "Porta $($p.Port) ($($p.Service)) ja esta em uso!"
            $portConflict = $true
        }
    } else {
        Write-Info "Porta $($p.Port) ($($p.Service)) — disponivel"
    }
}

if ($portConflict) {
    Write-Host ""
    $continueAnyway = Read-Host "  Portas em conflito detectadas. Deseja continuar mesmo assim? (S/N)"
    if ($continueAnyway -ne "S" -and $continueAnyway -ne "s") {
        Write-Info "Libere as portas e rode o script novamente."
        exit 0
    }
}

Write-Success "Prerequisites verificados"

# ═══════════════════════════════════════════════════════════════════
# ETAPA 2: Wizard de Configuração
# ═══════════════════════════════════════════════════════════════════

$envFile = Join-Path $ProjectDir ".env"
$envExists = Test-Path $envFile

if ($envExists) {
    Write-Host ""
    Write-Warn "Arquivo .env ja existe."
    $reconfigure = Read-Host "  Deseja reconfigurar? (S/N)"
    if ($reconfigure -ne "S" -and $reconfigure -ne "s") {
        Write-Info "Mantendo .env existente."
        $skipWizard = $true
    }
}

if (-not $skipWizard) {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║         Configuracao do WhatsAgent           ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    # API Key
    do {
        $apiKey = Read-Host "  Sua ANTHROPIC_API_KEY (sk-ant-...)"
        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            Write-Err "API key e obrigatoria."
        }
    } while ([string]::IsNullOrWhiteSpace($apiKey))

    if (-not $apiKey.StartsWith("sk-ant-")) {
        Write-Warn "Chave nao parece valida (deve comecar com sk-ant-)."
        $proceed = Read-Host "  Deseja continuar mesmo assim? (S/N)"
        if ($proceed -ne "S" -and $proceed -ne "s") {
            Write-Info "Corrija a API key e rode novamente."
            exit 0
        }
    }

    # Senha admin
    do {
        $adminPassword = Read-Host "  Senha do admin (min 6 caracteres)"
        if ($adminPassword.Length -lt 6) {
            Write-Err "Senha deve ter pelo menos 6 caracteres."
        }
    } while ($adminPassword.Length -lt 6)

    # Auto-gerar secrets
    Write-Step "Gerando chaves de seguranca..."
    $jwtSecret = -join ((1..64) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })
    $encryptionKey = -join ((1..64) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })
    Write-Success "JWT_SECRET e ENCRYPTION_KEY gerados automaticamente"

    # Modelo (default)
    $agentModel = "claude-sonnet-4-6"

    # Gerar .env
    Write-Step "Gerando arquivo .env..."

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $envLines = @(
        "# WhatsAgent CRM — Gerado pelo instalador em $timestamp",
        "",
        "# Anthropic API key",
        "ANTHROPIC_API_KEY=$apiKey",
        "",
        "# Database (PostgreSQL via Docker)",
        "DATABASE_URL=postgresql://whatsagent:whatsagent123@localhost:5432/whatsagent",
        "POSTGRES_PASSWORD=whatsagent123",
        "",
        "# Redis (via Docker)",
        "REDIS_URL=redis://localhost:6379",
        "",
        "# Security",
        "JWT_SECRET=$jwtSecret",
        "ENCRYPTION_KEY=$encryptionKey",
        "",
        "# Admin password (usado no primeiro login)",
        "ADMIN_PASSWORD=$adminPassword",
        "",
        "# Agent settings",
        "MAX_BUDGET_USD=0.50",
        "AGENT_MODEL=$agentModel",
        "",
        "# WhatsApp / Playwright (browser visivel)",
        "HEADLESS=false",
        "POLL_INTERVAL_MS=5000",
        "LOGIN_TIMEOUT_MS=300000",
        "DEBOUNCE_MS=10000",
        "",
        "# Knowledge base",
        "KNOWLEDGE_DIR=workspace/memory/knowledge",
        "",
        "# Server",
        "API_PORT=3001"
    )
    $envContent = $envLines -join "`r`n"

    Set-Content -Path $envFile -Value $envContent -Encoding UTF8
    Write-Success "Arquivo .env criado com sucesso"
}

# ═══════════════════════════════════════════════════════════════════
# ETAPA 3: Subir Infraestrutura (PostgreSQL + Redis)
# ═══════════════════════════════════════════════════════════════════

Write-Step "Iniciando PostgreSQL e Redis via Docker..."

$infraFile = Join-Path $ProjectDir "docker-compose.infra.yml"
if (-not (Test-Path $infraFile)) {
    Write-Err "Arquivo docker-compose.infra.yml nao encontrado em $ProjectDir"
    exit 1
}

# Verificar se containers já estão rodando
$pgRunning = docker ps --filter "name=whatsagent-local-postgres" --format "{{.Status}}" 2>$null
$redisRunning = docker ps --filter "name=whatsagent-local-redis" --format "{{.Status}}" 2>$null

if ($pgRunning -match "healthy" -and $redisRunning -match "healthy") {
    Write-Success "PostgreSQL e Redis ja estao rodando (healthy)"
} else {
    Push-Location $ProjectDir
    docker compose -f docker-compose.infra.yml up -d 2>&1 | Out-Null
    Pop-Location

    Write-Info "Aguardando health checks..."
    $maxWait = 60
    $waited = 0
    do {
        Start-Sleep -Seconds 3
        $waited += 3
        $pgStatus = docker ps --filter "name=whatsagent-local-postgres" --format "{{.Status}}" 2>$null
        $redisStatus = docker ps --filter "name=whatsagent-local-redis" --format "{{.Status}}" 2>$null
        Write-Host "." -NoNewline
    } while ((-not ($pgStatus -match "healthy" -and $redisStatus -match "healthy")) -and ($waited -lt $maxWait))

    Write-Host ""
    if ($pgStatus -match "healthy" -and $redisStatus -match "healthy") {
        Write-Success "PostgreSQL e Redis rodando (healthy)"
    } else {
        Write-Err "Timeout esperando health checks. Status: PG=$pgStatus Redis=$redisStatus"
        Write-Info "Verifique com: docker compose -f docker-compose.infra.yml ps"
        exit 1
    }
}

# ═══════════════════════════════════════════════════════════════════
# ETAPA 4: Instalar Dependências
# ═══════════════════════════════════════════════════════════════════

Write-Step "Instalando dependencias do projeto (pode demorar 2-5 minutos)..."

Push-Location $ProjectDir

$nodeModulesExist = Test-Path (Join-Path $ProjectDir "node_modules")
if ($nodeModulesExist) {
    Write-Info "node_modules encontrado, verificando atualizacoes..."
}

pnpm install 2>&1 | ForEach-Object {
    if ($_ -match "Done|Packages|added|removed|Progress") {
        Write-Info $_
    }
}

if ($LASTEXITCODE -ne 0) {
    Write-Err "Falha ao instalar dependencias. Verifique os erros acima."
    Pop-Location
    exit 1
}
Write-Success "Dependencias instaladas"

# Playwright Chromium
Write-Step "Instalando navegador Chromium para WhatsApp Web (~250MB)..."

$playwrightBrowsers = $env:PLAYWRIGHT_BROWSERS_PATH
if (-not $playwrightBrowsers) {
    $playwrightBrowsers = Join-Path $env:LOCALAPPDATA "ms-playwright"
}
$chromiumExists = Test-Path (Join-Path $playwrightBrowsers "chromium-*")

if ($chromiumExists) {
    Write-Info "Chromium ja instalado, verificando atualizacoes..."
}

npx playwright install chromium 2>&1 | ForEach-Object {
    if ($_ -match "Downloading|chromium|browsers") {
        Write-Info $_
    }
}
Write-Success "Chromium instalado"

Pop-Location

# ═══════════════════════════════════════════════════════════════════
# ETAPA 5: Rodar Migrations do Banco
# ═══════════════════════════════════════════════════════════════════

Write-Step "Rodando migrations do banco de dados..."

Push-Location $ProjectDir

pnpm db:migrate 2>&1 | ForEach-Object {
    if ($_ -match "migration|applied|already|Migration|Creating|done") {
        Write-Info $_
    }
}

if ($LASTEXITCODE -ne 0) {
    Write-Warn "Algumas migrations podem ter falhado. O sistema usa graceful degradation."
    Write-Info "Verifique a conexao com PostgreSQL: docker compose -f docker-compose.infra.yml ps"
} else {
    Write-Success "Migrations executadas com sucesso"
}

Pop-Location

# ═══════════════════════════════════════════════════════════════════
# ETAPA 6: Criar Atalho no Desktop
# ═══════════════════════════════════════════════════════════════════

Write-Step "Criando atalho no Desktop..."

$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktopPath "WhatsAgent CRM.lnk"

if (Test-Path $shortcutPath) {
    Write-Info "Atalho ja existe, atualizando..."
}

try {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "cmd.exe"
    $shortcut.Arguments = "/k cd /d `"$ProjectDir`" & pnpm start"
    $shortcut.WorkingDirectory = $ProjectDir
    $shortcut.Description = "WhatsAgent CRM — Assistente IA para WhatsApp Business"
    $shortcut.Save()
    Write-Success "Atalho criado: $shortcutPath"
} catch {
    Write-Warn "Nao foi possivel criar atalho no Desktop."
    Write-Info "Voce pode iniciar manualmente com: cd $ProjectDir ; pnpm start"
}

# ═══════════════════════════════════════════════════════════════════
# ETAPA 7: Finalização
# ═══════════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║      Instalacao concluida com sucesso!       ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Proximos passos:" -ForegroundColor White
Write-Host "    1. O sistema vai iniciar agora" -ForegroundColor Gray
Write-Host "    2. Acesse http://localhost:3000 no navegador" -ForegroundColor Gray
Write-Host "    3. Login: admin@whatsagent.com / (senha que voce definiu)" -ForegroundColor Gray
Write-Host "    4. Va em 'Sessoes' para conectar seu WhatsApp" -ForegroundColor Gray
Write-Host ""
Write-Host "  Para iniciar futuramente:" -ForegroundColor White
Write-Host "    - Use o atalho 'WhatsAgent CRM' no Desktop" -ForegroundColor Gray
Write-Host "    - Ou rode: cd $ProjectDir ; pnpm start" -ForegroundColor Gray
Write-Host ""

$startNow = Read-Host "  Deseja iniciar o WhatsAgent agora? (S/N)"

if ($startNow -eq "S" -or $startNow -eq "s") {
    Write-Step "Iniciando WhatsAgent CRM..."
    Write-Info "API Server: http://localhost:3001"
    Write-Info "Frontend:   http://localhost:3000"
    Write-Info "Pressione Ctrl+C para parar"
    Write-Host ""

    # Abrir o browser após um delay
    Start-Job -ScriptBlock {
        Start-Sleep -Seconds 15
        Start-Process "http://localhost:3000"
    } | Out-Null

    Push-Location $ProjectDir
    pnpm start
    Pop-Location
} else {
    Write-Host ""
    Write-Success "Tudo pronto! Use o atalho no Desktop para iniciar quando quiser."
    Write-Host ""
}
