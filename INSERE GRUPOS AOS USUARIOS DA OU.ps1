# Defina a OU onde os usuários estão localizados
$ou = "OU=Exemplo,DC=dominio,DC=com"

# Defina a lista de grupos de permissões que deseja adicionar
$grupos = "Grupo1", "Grupo2", "Grupo3"

# Percorra todos os usuários na OU definida
Get-ADUser -Filter * -SearchBase $ou | ForEach-Object {

    # Percorra todos os grupos de permissões a serem adicionados
    foreach ($grupo in $grupos) {

        # Adicione o usuário ao grupo de permissões
        Add-ADGroupMember -Identity $grupo -Members $_.SamAccountName
    }
}
