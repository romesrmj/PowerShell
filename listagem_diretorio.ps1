param (
    [string]$Pasta = "DIRETORIO PARA LISTAGEM"
)

$saida = "C:\tmp\relatorio_espaco.html"

if (!(Test-Path $Pasta)) {
    Write-Host "Diretório não encontrado: $Pasta"
    exit
}

$tipos = @{}
$arquivosPorTipo = @{}

Write-Host "🔍 Analisando arquivos..."

Get-ChildItem -Path $Pasta -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {

    $ext = $_.Extension.ToLower()
    $size = $_.Length
    $fullPath = $_.FullName

    $tipo = switch -Regex ($ext) {
        "\.docx?$|\.odt$" { "Word" }
        "\.xlsx?$|\.ods$" { "Excel" }
        "\.jpg$|\.jpeg$|\.png$|\.gif$|\.bmp$" { "Imagens" }
        "\.mp4$|\.avi$|\.mkv$" { "Videos" }
        "\.pdf$" { "PDF" }
        default { "Outros" }
    }

    if (-not $tipos.ContainsKey($tipo)) {
        $tipos[$tipo] = 0
        $arquivosPorTipo[$tipo] = @()
    }

    $tipos[$tipo] += $size
    $arquivosPorTipo[$tipo] += $fullPath
}

$total = ($tipos.Values | Measure-Object -Sum).Sum

# HTML base
$html = @"
<!DOCTYPE html>
<html lang="pt-br">
<head>
<meta charset="UTF-8">
<title>Relatório de Espaço</title>
<style>
body { font-family: Arial; background:#0f172a; color:#e2e8f0; padding:30px;}
h1 { color:#38bdf8;}
table { width:80%; border-collapse: collapse;}
th, td { padding:10px; border-bottom:1px solid #334155;}
th { background:#1e293b;}
tr:hover { background:#1e293b;}
.total { font-weight:bold; color:#22c55e;}
.details { display:none; margin-left:20px; font-size:12px; color:#94a3b8;}
button { background:#38bdf8; border:none; padding:5px 10px; cursor:pointer;}
</style>
<script>
function toggle(id){
  var el = document.getElementById(id);
  el.style.display = (el.style.display === 'none') ? 'block' : 'none';
}
</script>
</head>
<body>

<h1>📊 Relatório de Espaço em Disco</h1>
<p><strong>Pasta:</strong> $Pasta</p>

<table>
<tr><th>Tipo</th><th>Tamanho (GB)</th><th>Detalhes</th></tr>
"@

$i = 0

foreach ($tipo in $tipos.Keys) {
    $i++
    $gb = [math]::Round($tipos[$tipo] / 1GB, 2)
    $divId = "detalhe_$i"

    $html += "<tr>
<td>$tipo</td>
<td>$gb GB</td>
<td><button onclick=`"toggle('$divId')`">Ver</button></td>
</tr>"

    $html += "<tr><td colspan='3'>
<div id='$divId' class='details'>"

    foreach ($arquivo in $arquivosPorTipo[$tipo]) {
        $html += "$arquivo<br>"
    }

    $html += "</div></td></tr>"
}

$totalGB = [math]::Round($total / 1GB, 2)
$html += "<tr class='total'><td>Total</td><td>$totalGB GB</td><td></td></tr>"

$html += @"
</table>
</body>
</html>
"@

$html | Out-File -Encoding UTF8 $saida

Write-Host "✅ Relatório gerado em: $saida"
