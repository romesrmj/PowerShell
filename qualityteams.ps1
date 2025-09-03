# =======================
# Script: qualityteams.ps1
# Autor: Romes Morais
# Data: 2025-08
# =======================

# Define o destino para testes
$target = "outlook.microsoft.com"

Write-Host "`n=== AVALIAÇÃO DE CONEXÃO PARA MICROSOFT TEAMS ===" -ForegroundColor Cyan

# Criar pasta para salvar o relatório
$reportFolder = "C:\Teams_Quality"
if (-not (Test-Path $reportFolder)) {
    New-Item -Path $reportFolder -ItemType Directory | Out-Null
    Write-Host "Pasta $reportFolder criada."
}

# Verifica adaptadores de rede ativos
$adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }
$adapterInfo = foreach ($adapter in $adapters) {
    $connType = if ($adapter.MediaType -eq "802.11") { "Wi-Fi" } else { "LAN" }
    "$($adapter.Name) ($connType)"
}

# IP local
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -ne "WellKnown" -and $_.IPAddress -notlike "169.*" }).IPAddress

# Teste de conexão
Write-Host "`nTestando conectividade com $target ..."
$pingResults = Test-Connection -ComputerName $target -Count 10 -ErrorAction SilentlyContinue

if (-not $pingResults) {
    Write-Host "Não foi possível alcançar o servidor $target." -ForegroundColor Red
    exit
}

# Processamento das estatísticas
$latencies = $pingResults | Select-Object -ExpandProperty ResponseTime
$latencyAvg = [math]::Round(($latencies | Measure-Object -Average).Average, 2)
$jitter = [math]::Round((($latencies | ForEach-Object -Begin { $prev = $null } -Process {
    if ($prev -ne $null) {
        [math]::Abs($_ - $prev)
    }
    $prev = $_
}) | Where-Object { $_ -ne $null } | Measure-Object -Average).Average, 2)

$total = 10
$received = $pingResults.Count
$lost = $total - $received
$lossPercent = [math]::Round(($lost / $total) * 100, 1)

# Avaliação da qualidade
if ($latencyAvg -le 100 -and $jitter -le 30 -and $lossPercent -eq 0) {
    $qualidade = "EXCELENTE"
    $qualidadeColor = "green"
} elseif ($latencyAvg -le 150 -and $jitter -le 50 -and $lossPercent -le 2) {
    $qualidade = "BOA"
    $qualidadeColor = "goldenrod"
} elseif ($latencyAvg -le 250 -and $jitter -le 75 -and $lossPercent -le 5) {
    $qualidade = "REGULAR"
    $qualidadeColor = "orange"
} else {
    $qualidade = "RUIM"
    $qualidadeColor = "red"
}

# JSON de latências para gráfico
$latencyJson = ($latencies -join ",")

# HTML com gráfico e exportação
$html = @"
<!DOCTYPE html>
<html lang='pt-br'>
<head>
    <meta charset='UTF-8'>
    <title>Relatório de Qualidade - Microsoft Teams</title>
    <script src='https://cdn.jsdelivr.net/npm/chart.js'></script>
    <script src='https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js'></script>
    <script src='https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js'></script>
    <style>
        body { font-family: Arial, sans-serif; margin: 30px; background-color: #f9f9f9; }
        h1 { color: #2b5797; }
        table { border-collapse: collapse; width: 100%; background-color: white; margin-bottom: 30px; box-shadow: 0 0 5px rgba(0,0,0,0.1); }
        th, td { border: 1px solid #ddd; padding: 10px; text-align: left; }
        th { background-color: #2b5797; color: white; }
        .status { font-weight: bold; color: $qualidadeColor; }
        #chartContainer { width: 80%; margin: auto; }
        .btns { margin-bottom: 20px; }
        button { padding: 10px 15px; margin-right: 10px; background-color: #2b5797; color: white; border: none; cursor: pointer; }
        button:hover { background-color: #1a3d6d; }
        .footer { margin-top: 20px; font-size: 0.9em; color: #555; }
    </style>
</head>
<body>

    <h1>Relatório de Qualidade da Conexão - Microsoft Teams</h1>

    <div class='btns'>
        <button onclick='exportToPDF()'>Exportar para PDF</button>
        <button onclick='exportToExcel()'>Exportar para Excel</button>
    </div>

    <table id='reportTable'>
        <tr><th>Data e Hora</th><td>$(Get-Date -Format 'dd/MM/yyyy HH:mm')</td></tr>
        <tr><th>Rede Conectada</th><td>$($adapterInfo -join ', ')</td></tr>
        <tr><th>Endereço IP</th><td>$ip</td></tr>
        <tr><th>Servidor Testado</th><td>$target</td></tr>
        <tr><th>Latência Média</th><td>$latencyAvg ms</td></tr>
        <tr><th>Jitter</th><td>$jitter ms</td></tr>
        <tr><th>Perda de Pacotes</th><td>$lossPercent %</td></tr>
        <tr><th>Qualidade Geral</th><td class='status'>$qualidade</td></tr>
    </table>

    <div id='chartContainer'>
        <canvas id='latencyChart'></canvas>
    </div>

    <div class='footer'>Relatório gerado automaticamente via script PowerShell - Microsoft Teams</div>

    <script>
        // Gera gráfico de latência
        const ctx = document.getElementById('latencyChart').getContext('2d');
        const latencyChart = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: Array.from({length: 10}, (_, i) => 'Ping ' + (i+1)),
                datasets: [{
                    label: 'Latência (ms)',
                    data: [$latencyJson],
                    backgroundColor: 'rgba(43, 87, 151, 0.7)'
                }]
            },
            options: {
                responsive: true,
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'ms'
                        }
                    }
                }
            }
        });

        // Exporta para PDF
        function exportToPDF() {
            const { jsPDF } = window.jspdf;
            const doc = new jsPDF();
            doc.text("Relatório de Qualidade da Conexão - Microsoft Teams", 10, 10);
            html2canvas(document.querySelector("table")).then(canvas => {
                const imgData = canvas.toDataURL("image/png");
                doc.addImage(imgData, 'PNG', 10, 20, 180, 0);
                doc.save("relatorio_teams.pdf");
            });
        }

        // Exporta para Excel
        function exportToExcel() {
            const wb = XLSX.utils.book_new();
            const ws = XLSX.utils.table_to_sheet(document.getElementById('reportTable'));
            XLSX.utils.book_append_sheet(wb, ws, "Relatório");
            XLSX.writeFile(wb, "relatorio_teams.xlsx");
        }
    </script>

    <script src='https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js'></script>
</body>
</html>
"@

# Salvar HTML
$htmlPath = Join-Path $reportFolder "relatorio.html"
$html | Set-Content -Path $htmlPath -Encoding UTF8
Write-Host "Relatório salvo em: $htmlPath" -ForegroundColor Green

# Abrir relatório automaticamente
Start-Process $htmlPath
