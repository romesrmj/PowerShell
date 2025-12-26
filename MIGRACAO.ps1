# ===============================================
# MIGRAÇÃO - HOST1 --> HOST2
# ===============================================

Write-Host "Iniciando migração - " -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

# Define o caminho do log
$LOGPATH = "C:\LogsMigracao"

# Cria o diretório de log se não existir
if (-Not (Test-Path -Path $LOGPATH)) {
    New-Item -ItemType Directory -Path $LOGPATH | Out-Null
    Write-Host "Diretório de log criado em $LOGPATH" -ForegroundColor Green
} else {
    Write-Host "Diretório de log já existe: $LOGPATH" -ForegroundColor Yellow
}

# Caminhos de origem e destino

$origem = "DIRETORIO 1"
$destino = "DIRETORIO 2"


# Executa o ROBOCOPY
$robocopyArgs = @(
    $origem
    $destino
    "/E"        # Copia subpastas, incluindo vazias
    "/COPYALL"  # Copia todos os atributos e permissões
    "/DCOPY:T"  # Preserva timestamps das pastas
    "/R:2"      # Número de tentativas em caso de erro
    "/W:5"      # Tempo de espera entre tentativas
    "/MT:16"    # Multithread com 16 threads
    "/LOG+:$LOGPATH\NOME_LOG.log"  # Log
    "/TEE"      # Mostra saída no console e grava no log
)

Write-Host "Iniciando cópia com ROBOCOPY..." -ForegroundColor Cyan

# Executa o ROBOCOPY
Start-Process robocopy -ArgumentList $robocopyArgs -Wait

Write-Host "Migração concluída." -ForegroundColor Green
