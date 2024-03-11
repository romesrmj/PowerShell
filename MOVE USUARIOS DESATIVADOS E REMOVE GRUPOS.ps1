# Defina o nome da sua OU de origem e destino
$sourceOU = "OU=UsuáriosDesativados,DC=exemplo,DC=com"
$destinationOU = "OU=ArquivoMorto,DC=exemplo,DC=com"

# Defina o caminho do diretório de logs
$logDirectory = "C:\Logs"

# Crie o diretório de logs se não existir
if (!(Test-Path -Path $logDirectory)) {
    Write-Host "Diretório de logs não encontrado. Criando diretório em $logDirectory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $logDirectory | Out-Null
}

# Crie o nome do arquivo de log baseado na data e hora atual
$logFileName = "usuarios-movidos-$((Get-Date).ToString('yyyyMMdd-HHmmss')).log"
$logPath = Join-Path -Path $logDirectory -ChildPath $logFileName

# Crie o nome do arquivo CSV baseado na data e hora atual
$csvFileName = "usuarios-movidos-$((Get-Date).ToString('yyyyMMdd-HHmmss')).csv"
$csvPath = Join-Path -Path $logDirectory -ChildPath $csvFileName

# Obtenha todos os usuários desativados na OU de origem
$users = Get-ADUser -Filter {Enabled -eq $false} -SearchBase $sourceOU

# Se não houver usuários desativados, saia do script
if (!$users) {
    Write-Host "Não há usuários desativados na OU de origem." -ForegroundColor Yellow
    Exit
}

# Array para armazenar os dados para o CSV
$csvData = @()

# Remova todos os grupos dos usuários desativados
foreach ($user in $users) {
    Write-Host "Removendo grupos para o usuário $($user.SamAccountName)..." -ForegroundColor Green
    $memberGroups = Get-ADPrincipalGroupMembership -Identity $user | Select-Object -ExpandProperty Name
    $memberGroups | ForEach-Object {
        Remove-ADPrincipalGroupMembership -Identity $user -MemberOf $_ -Confirm:$false
        # Adiciona os dados ao array CSV
        $csvData += [PSCustomObject]@{
            'Data' = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            'Usuário' = $user.SamAccountName
            'MemberGroup' = $_
        }
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

# Exporta os dados para o CSV
$csvData | Export-Csv -Path $csvPath -NoTypeInformation

Write-Host "Movimento de usuários concluído. Confira o arquivo de log em $logPath e o arquivo CSV em $csvPath." -ForegroundColor Green
