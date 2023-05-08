# Defina o nome da sua OU de origem e destino
$sourceOU = "OU=UsuáriosDesativados,DC=exemplo,DC=com"
$destinationOU = "OU=ArquivoMorto,DC=exemplo,DC=com"

# Defina o caminho do arquivo de log
$logPath = "C:\Logs\usuarios-movidos.log"

# Verifique se a pasta de log existe. Se não existir, crie a pasta
if (!(Test-Path -Path (Split-Path $logPath))) {
    Write-Host "Pasta de log não encontrada. Criando pasta em $(Split-Path $logPath)..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path (Split-Path $logPath) | Out-Null
}

# Obtenha todos os usuários desativados na OU de origem
$users = Get-ADUser -Filter {Enabled -eq $false} -SearchBase $sourceOU

# Se não houver usuários desativados, saia do script
if (!$users) {
    Write-Host "Não há usuários desativados na OU de origem." -ForegroundColor Yellow
    Exit
}

# Remova todos os grupos dos usuários desativados
foreach ($user in $users) {
    Write-Host "Removendo grupos para o usuário $($user.SamAccountName)..." -ForegroundColor Green
    Get-ADPrincipalGroupMembership -Identity $user | ForEach-Object {
        Remove-ADPrincipalGroupMembership -Identity $user -MemberOf $_ -Confirm:$false
    }
}

# Mova cada usuário para a OU de destino e registre o movimento no log
foreach ($user in $users) {
    Move-ADObject -Identity $user -TargetPath $destinationOU
    Write-Host "Usuário $($user.SamAccountName) movido para a OU de destino." -ForegroundColor Green

    # Registre o movimento no log
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $($user.SamAccountName) movido de $($user.DistinguishedName) para $($destinationOU)"
    Add-Content -Path $logPath -Value $logMessage
}

Write-Host "Movimento de usuários concluído. Confira o arquivo de log em $logPath." -ForegroundColor Green
