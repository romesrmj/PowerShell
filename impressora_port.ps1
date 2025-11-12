# Script: impressora_port.ps1
# Cria automatico as portas a serem ocupadas no servidor de impressão.
# --------------------------------------------------------------------------------

# 🔧 Defina aqui o intervalo de IPs - opção para range de ips
$inicio = 10
$fim    = 20
$base   = "10.0.0"

Write-Host "Criando portas TCP/IP de $base.$inicio até $base.$fim..."

for ($i = $inicio; $i -le $fim; $i++) {
    $IpAddress = "$base.$i"
    $portName = "IP_$IpAddress"

    # Verifica se já existe a porta
    if (Get-PrinterPort -Name $portName -ErrorAction SilentlyContinue) {
        Write-Host "🟡 Porta $portName já existe — pulando..."
        continue
    }

    try {
        Write-Host "🟢 Criando porta TCP/IP para $IpAddress..."
        Add-PrinterPort -Name $portName -PrinterHostAddress $IpAddress
        Write-Host "✅ Porta $portName criada com sucesso.`n"
    } catch {
        Write-Warning "❌ Falha ao criar porta para $IpAddress: $_"
    }
}

Write-Host "🎯 Processo concluído."
