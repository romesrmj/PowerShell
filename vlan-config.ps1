```powershell
# ============================================================
# VLAN-CONFIG.PS1
# Configurador automático de VLAN para Windows
#
# VLAN padrão: 2
#
# Funções:
#   1 - Configurar VLAN
#   2 - Limpar VLAN
#   3 - Sair
#
# O script:
#   - Detecta automaticamente a placa Ethernet física
#   - Não depende de fabricante
#   - Procura propriedades de VLAN disponíveis no driver
#   - Somente configura se encontrar uma propriedade
#     compatível com VLAN ID numérico
#   - Caso não seja compatível, apenas informa o usuário
# ============================================================

#requires -Version 5.1

$ErrorActionPreference = "SilentlyContinue"

# ============================================================
# CONFIGURAÇÃO
# ============================================================

$VlanPadrao = 2

# ============================================================
# VERIFICA ADMINISTRADOR
# ============================================================

$Principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)

$Administrador = $Principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $Administrador) {

    Clear-Host

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host "                 PERMISSÃO NECESSÁRIA"
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Execute o VLAN-Config.ps1 como Administrador."
    Write-Host ""
    Pause

    exit
}

# ============================================================
# FUNÇÕES
# ============================================================

function Mostrar-Cabecalho {

    Clear-Host

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "              CONFIGURADOR AUTOMÁTICO DE VLAN" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Obter-AdaptadorEthernet {

    # Obtém somente interfaces físicas.
    $Adaptadores = @(
        Get-NetAdapter -Physical |
        Where-Object {

            $_.HardwareInterface -eq $true -and

            $_.InterfaceDescription -notmatch `
            "Wi-Fi|Wireless|Bluetooth|Virtual|VPN|Hyper-V|VMware|VirtualBox|TAP|WAN Miniport"
        }
    )

    if ($Adaptadores.Count -eq 0) {
        return $null
    }

    # Prioriza interfaces com características Ethernet.
    $Ethernet = @(
        $Adaptadores |
        Where-Object {

            $_.Name -match "Ethernet|LAN" -or
            $_.InterfaceDescription -match `
            "Ethernet|Gigabit|GbE|Network Controller|PCIe"
        }
    )

    if ($Ethernet.Count -gt 0) {
        return $Ethernet
    }

    return $Adaptadores
}

function Selecionar-Adaptador {

    param(
        [array]$Adaptadores
    )

    if ($Adaptadores.Count -eq 1) {
        return $Adaptadores[0]
    }

    Write-Host ""
    Write-Host "Mais de uma interface de rede física foi encontrada."
    Write-Host ""

    for ($i = 0; $i -lt $Adaptadores.Count; $i++) {

        $A = $Adaptadores[$i]

        Write-Host "[$($i + 1)] $($A.Name)"
        Write-Host "    Modelo : $($A.InterfaceDescription)"
        Write-Host "    MAC    : $($A.MacAddress)"
        Write-Host "    Status : $($A.Status)"
        Write-Host ""
    }

    do {

        $Entrada = Read-Host "Selecione a interface"

        $Numero = 0

        $Valido = [int]::TryParse(
            $Entrada,
            [ref]$Numero
        )

    } while (
        -not $Valido -or
        $Numero -lt 1 -or
        $Numero -gt $Adaptadores.Count
    )

    return $Adaptadores[$Numero - 1]
}

function Obter-PropriedadesVlan {

    param(
        [string]$NomeAdaptador
    )

    $Propriedades = @(
        Get-NetAdapterAdvancedProperty `
            -Name $NomeAdaptador `
            -ErrorAction SilentlyContinue
    )

    if ($Propriedades.Count -eq 0) {
        return @()
    }

    # Propriedades que podem representar VLAN ID.
    #
    # NÃO consideramos "Priority & VLAN" como VLAN ID,
    # pois essa propriedade aceita apenas estados como:
    # Disabled
    # Priority Enabled
    # VLAN Enabled
    # Priority & VLAN Enabled

    $Resultado = @(
        $Propriedades |
        Where-Object {

            $_.DisplayName -match `
            "VLAN ID|VlanID|VLAN Identifier|VLAN Number|VLAN Tag|VLAN Tag ID" -or

            $_.RegistryKeyword -match `
            "VLANID|VLAN_ID|VlanID|VLANIdentifier|VLANNumber|VLANTag"
        }
    )

    return $Resultado
}

function Testar-PropriedadeNumerica {

    param(
        $Propriedade
    )

    if ($null -eq $Propriedade) {
        return $false
    }

    # Verifica se o valor atual é numérico.
    $Numero = 0

    if ([int]::TryParse(
        [string]$Propriedade.DisplayValue,
        [ref]$Numero
    )) {

        return $true
    }

    # Alguns drivers utilizam RegistryValue.
    $Numero = 0

    if ([int]::TryParse(
        [string]$Propriedade.RegistryValue,
        [ref]$Numero
    )) {

        return $true
    }

    # Se estiver vazio, ainda pode aceitar valores numéricos.
    if (
        [string]::IsNullOrWhiteSpace(
            [string]$Propriedade.DisplayValue
        )
    ) {

        return $true
    }

    return $false
}

function Encontrar-VlanID {

    param(
        [string]$NomeAdaptador
    )

    $Propriedades = Obter-PropriedadesVlan `
        -NomeAdaptador $NomeAdaptador

    if ($Propriedades.Count -eq 0) {
        return $null
    }

    foreach ($Propriedade in $Propriedades) {

        if (
            Testar-PropriedadeNumerica `
                -Propriedade $Propriedade
        ) {

            return $Propriedade
        }
    }

    return $null
}

function Mostrar-Incompatibilidade {

    param(
        $Adaptador
    )

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host "                 EQUIPAMENTO NÃO COMPATÍVEL" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "Adaptador:"
    Write-Host "$($Adaptador.InterfaceDescription)"
    Write-Host ""

    Write-Host "O driver desta placa não disponibiliza uma propriedade"
    Write-Host "compatível para configurar um VLAN ID numérico."
    Write-Host ""

    Write-Host "Nenhuma alteração foi realizada." -ForegroundColor Green
    Write-Host ""

    Write-Host "Observação:"
    Write-Host "Propriedades como 'Priority & VLAN' não são consideradas"
    Write-Host "VLAN ID, pois não permitem informar o número da VLAN."
    Write-Host ""
}

function Configurar-Vlan {

    param(
        $Adaptador,
        $Propriedade
    )

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "                 CONFIGURAR VLAN"
    Write-Host "============================================================"
    Write-Host ""

    # VLAN padrão
    $Entrada = Read-Host "Digite a VLAN [padrão: $VlanPadrao]"

    if ([string]::IsNullOrWhiteSpace($Entrada)) {
        $VLAN = $VlanPadrao
    }
    else {

        $Numero = 0

        if (
            -not [int]::TryParse(
                $Entrada,
                [ref]$Numero
            )
        ) {

            Write-Host ""
            Write-Host "VLAN inválida." -ForegroundColor Red
            Pause

            return
        }

        $VLAN = $Numero
    }

    if ($VLAN -lt 1 -or $VLAN -gt 4094) {

        Write-Host ""
        Write-Host "VLAN inválida." -ForegroundColor Red
        Write-Host "Informe um valor entre 1 e 4094."
        Write-Host ""

        Pause

        return
    }

    Write-Host ""
    Write-Host "Interface : $($Adaptador.Name)"
    Write-Host "VLAN      : $VLAN"
    Write-Host "Propriedade: $($Propriedade.DisplayName)"
    Write-Host ""

    $Confirmacao = Read-Host "Configurar VLAN $VLAN? [S/N]"

    if ($Confirmacao -notmatch "^[Ss]$") {

        Write-Host ""
        Write-Host "Operação cancelada."
        Pause

        return
    }

    Write-Host ""
    Write-Host "Configurando VLAN $VLAN..." -ForegroundColor Yellow

    try {

        Set-NetAdapterAdvancedProperty `
            -Name $Adaptador.Name `
            -DisplayName $Propriedade.DisplayName `
            -DisplayValue ([string]$VLAN) `
            -NoRestart:$false `
            -ErrorAction Stop

        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Green
        Write-Host "             VLAN CONFIGURADA COM SUCESSO" -ForegroundColor Green
        Write-Host "============================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Adaptador : $($Adaptador.Name)"
        Write-Host "VLAN      : $VLAN"
        Write-Host ""

    }
    catch {

        Write-Host ""
        Write-Host "Não foi possível configurar a VLAN." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "O driver não aceitou o VLAN ID informado."
        Write-Host ""
        Write-Host "Nenhuma configuração adicional foi realizada."
    }

    Write-Host ""
    Pause
}

function Limpar-Vlan {

    param(
        $Adaptador,
        $Propriedade
    )

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "                   LIMPAR VLAN"
    Write-Host "============================================================"
    Write-Host ""

    Write-Host "Adaptador : $($Adaptador.Name)"
    Write-Host "Propriedade: $($Propriedade.DisplayName)"
    Write-Host "Valor atual: $($Propriedade.DisplayValue)"
    Write-Host ""

    $Confirmacao = Read-Host "Remover a configuração VLAN? [S/N]"

    if ($Confirmacao -notmatch "^[Ss]$") {

        Write-Host ""
        Write-Host "Operação cancelada."
        Pause

        return
    }

    Write-Host ""
    Write-Host "Removendo VLAN..." -ForegroundColor Yellow

    try {

        # Para propriedades VLAN ID numéricas,
        # VLAN 0 representa ausência de VLAN em muitos drivers.

        Set-NetAdapterAdvancedProperty `
            -Name $Adaptador.Name `
            -DisplayName $Propriedade.DisplayName `
            -DisplayValue "0" `
            -NoRestart:$false `
            -ErrorAction Stop

        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Green
        Write-Host "                VLAN REMOVIDA COM SUCESSO" -ForegroundColor Green
        Write-Host "============================================================" -ForegroundColor Green
        Write-Host ""

    }
    catch {

        Write-Host ""
        Write-Host "O driver não permite remover a VLAN utilizando este método." `
            -ForegroundColor Yellow

        Write-Host ""
        Write-Host "Nenhuma outra configuração foi alterada."
    }

    Write-Host ""
    Pause
}

# ============================================================
# INÍCIO
# ============================================================

Mostrar-Cabecalho

Write-Host "Detectando placa de rede..." -ForegroundColor Yellow
Write-Host ""

$Adaptadores = Obter-AdaptadorEthernet

if ($null -eq $Adaptadores -or $Adaptadores.Count -eq 0) {

    Write-Host "Nenhum adaptador Ethernet físico foi encontrado." `
        -ForegroundColor Yellow

    Write-Host ""
    Write-Host "Nenhuma alteração foi realizada."
    Write-Host ""

    Pause

    exit
}

$Adaptador = Selecionar-Adaptador `
    -Adaptadores $Adaptadores

if ($null -eq $Adaptador) {

    Write-Host ""
    Write-Host "Nenhum adaptador selecionado."
    Pause

    exit
}

Write-Host ""
Write-Host "Adaptador encontrado:" -ForegroundColor Green
Write-Host ""
Write-Host "Nome       : $($Adaptador.Name)"
Write-Host "Modelo     : $($Adaptador.InterfaceDescription)"
Write-Host "MAC        : $($Adaptador.MacAddress)"
Write-Host "Status     : $($Adaptador.Status)"
Write-Host ""

# ============================================================
# PROCURA VLAN ID
# ============================================================

Write-Host "Verificando suporte a VLAN ID..." -ForegroundColor Yellow

$PropriedadeVlan = Encontrar-VlanID `
    -NomeAdaptador $Adaptador.Name

if ($null -eq $PropriedadeVlan) {

    Mostrar-Incompatibilidade `
        -Adaptador $Adaptador

    Pause

    exit
}

Write-Host ""
Write-Host "[OK] Propriedade de VLAN ID encontrada." `
    -ForegroundColor Green

Write-Host ""
Write-Host "Propriedade : $($PropriedadeVlan.DisplayName)"
Write-Host "Valor atual : $($PropriedadeVlan.DisplayValue)"
Write-Host ""

# ============================================================
# MENU
# ============================================================

do {

    Write-Host "============================================================"
    Write-Host "                         MENU"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "[1] Configurar VLAN"
    Write-Host "[2] Limpar VLAN"
    Write-Host "[3] Sair"
    Write-Host ""

    $Opcao = Read-Host "Escolha uma opção"

    switch ($Opcao) {

        "1" {

            Configurar-Vlan `
                -Adaptador $Adaptador `
                -Propriedade $PropriedadeVlan
        }

        "2" {

            Limpar-Vlan `
                -Adaptador $Adaptador `
                -Propriedade $PropriedadeVlan
        }

        "3" {

            Write-Host ""
            Write-Host "Encerrando..."
            Write-Host ""

            break
        }

        default {

            Write-Host ""
            Write-Host "Opção inválida." -ForegroundColor Yellow
            Write-Host ""

            Start-Sleep -Seconds 1
            Clear-Host
        }
    }

} while ($Opcao -ne "3")
```
