<#
====================================================================================
SCRIPT: Higienização de Grupos de Segurança sem Membros no Active Directory
AUTOR: [Seu Nome ou Equipe de Infraestrutura]
DATA: 14/10/2025
VERSÃO: 1.0

OBJETIVO:
    Este script realiza a identificação e, opcionalmente, a exclusão de grupos 
    de segurança do Active Directory que não possuem membros (usuários, computadores 
    ou outros grupos) dentro de uma OU específica.

FUNCIONALIDADES:
    - Lista todos os grupos de segurança dentro da OU definida.
    - Identifica grupos sem membros.
    - Exporta a lista de grupos encontrados para um arquivo CSV (backup automático).
    - Permite rodar em dois modos:
        [S] Simulação — Apenas exibe os grupos que seriam excluídos (sem alterar nada).
        [E] Exclusão — Exclui efetivamente os grupos após confirmação adicional.

BOAS PRÁTICAS:
    - Execute primeiro em modo de SIMULAÇÃO (S) para revisar os grupos.
    - Verifique se os grupos não estão vinculados a permissões NTFS, ACLs, 
      sistemas de terceiros ou políticas antes da exclusão.
    - Execute com uma conta com permissões administrativas no AD.
    - É recomendável manter o backup CSV gerado para auditoria.

REQUISITOS:
    - Módulo ActiveDirectory instalado (RSAT ou em um Domain Controller).
    - PowerShell 5.1 ou superior.
====================================================================================
#>

# Importa o módulo do Active Directory
Import-Module ActiveDirectory

# Define a OU onde estão os grupos
$OU = "DEFINIR A OU AQUI"

# Busca todos os grupos de segurança na OU
$Grupos = Get-ADGroup -Filter {GroupCategory -eq "Security"} -SearchBase $OU -SearchScope Subtree

# Cria uma lista vazia para armazenar os grupos sem membros
$GruposSemMembros = @()

# Verifica membros de cada grupo
foreach ($Grupo in $Grupos) {
    $Membros = Get-ADGroupMember -Identity $Grupo.DistinguishedName -ErrorAction SilentlyContinue
    if (-not $Membros) {
        $GruposSemMembros += [PSCustomObject]@{
            Nome = $Grupo.Name
            DistinguishedName = $Grupo.DistinguishedName
        }
    }
}

# Exibe o resultado
Write-Host "`nGrupos sem membros encontrados:" -ForegroundColor Cyan
$GruposSemMembros | Format-Table Nome, DistinguishedName -AutoSize
Write-Host "`nTotal de grupos sem membros: $($GruposSemMembros.Count)`n" -ForegroundColor Cyan

# Cria backup antes de qualquer ação
$backupPath = "C:\Temp\Backup_GruposSemMembros_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"
$GruposSemMembros | Export-Csv -Path $backupPath -NoTypeInformation -Encoding UTF8
Write-Host "Backup salvo em: $backupPath" -ForegroundColor Yellow

# Pergunta se deseja executar simulação ou exclusão real
$modo = Read-Host "Deseja fazer apenas uma simulação (S) ou excluir os grupos realmente (E)? [S/E]"

if ($modo -match '^[Ss]$') {
    Write-Host "`n--- MODO SIMULAÇÃO --- Nenhum grupo será excluído." -ForegroundColor Yellow
    foreach ($Grupo in $GruposSemMembros) {
        Write-Host "SIMULAÇÃO: Grupo seria removido -> $($Grupo.Nome)" -ForegroundColor DarkYellow
    }
    Write-Host "`nSimulação concluída. Nenhuma modificação foi feita." -ForegroundColor Cyan
}
elseif ($modo -match '^[Ee]$') {
    Write-Host "`n--- MODO EXCLUSÃO REAL ---" -ForegroundColor Red
    $confirm = Read-Host "Tem certeza que deseja excluir TODOS esses grupos? (S/N)"
    if ($confirm -match '^[Ss]$') {
        foreach ($Grupo in $GruposSemMembros) {
            try {
                Remove-ADGroup -Identity $Grupo.DistinguishedName -Confirm:$false
                Write-Host "Grupo removido: $($Grupo.Nome)" -ForegroundColor Green
            }
            catch {
                Write-Host "Erro ao remover o grupo $($Grupo.Nome): $_" -ForegroundColor Red
            }
        }
        Write-Host "`nProcesso de exclusão concluído." -ForegroundColor Cyan
    } else {
        Write-Host "Operação cancelada. Nenhum grupo foi removido." -ForegroundColor Yellow
    }
}
else {
    Write-Host "Opção inválida. Encerrando sem alterações." -ForegroundColor Yellow
}
