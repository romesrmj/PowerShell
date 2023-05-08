# Desmapeamento de pastas
Remove-PSDrive -Name Z -ErrorAction SilentlyContinue
Remove-PSDrive -Name Y -ErrorAction SilentlyContinue

# Limpeza de arquivos temporários
Remove-Item -Path "$env:LOCALAPPDATA\Temp\*" -Recurse -Force

# Limpeza de cache de navegadores (para o Google Chrome)
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
if (Test-Path $chromePath) {
    Remove-Item -Path $chromePath\* -Recurse -Force
}

# Mapeamento de pastas
New-PSDrive -Name Z -PSProvider FileSystem -Root "\\servidor\compartilhamento" -Persist
New-PSDrive -Name Y -PSProvider FileSystem -Root "\\servidor\compartilhamento2" -Persist
