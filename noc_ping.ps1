# ===== LISTA DE IPS =====

$ips = @(
"8.8.8.8",
"10.7.0.1",
"10.1.0.49",
"10.1.1.53",
"10.1.0.41"
)

# ===== CONFIGURAÇÃO GRID =====

$colunas = 4
$largura = 420
$altura = 180

# ===== API WINDOWS =====

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win {
[DllImport("user32.dll")]
public static extern bool MoveWindow(IntPtr hWnd,int X,int Y,int W,int H,bool repaint);
}
"@

# ===== ABRIR CMDs =====

$processos = @()

foreach ($ip in $ips) {

    try {
        $hostname = ([System.Net.Dns]::GetHostEntry($ip)).HostName
    }
    catch {
        $hostname = "DESCONHECIDO"
    }

    $titulo = "$hostname [$ip]"

    $cmd = "mode con: cols=50 lines=10 & color 0A & title $titulo & ping $ip -t"

    $p = Start-Process cmd.exe -ArgumentList "/k $cmd" -PassThru

    $processos += $p
}

Start-Sleep 2

# ===== ORGANIZAR NA TELA =====

for ($i = 0; $i -lt $processos.Count; $i++) {

    $p = $processos[$i]

    if ($p.MainWindowHandle -ne 0) {

        $col = $i % $colunas
        $row = [math]::Floor($i / $colunas)

        $x = $col * $largura
        $y = $row * $altura

        [Win]::MoveWindow($p.MainWindowHandle,$x,$y,$largura,$altura,$true)
    }
}
