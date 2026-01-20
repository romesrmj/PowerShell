#LISTA O ULTIMO USUÁRIO QUE REINICIOU O EQUIPAMENTO.
Get-WinEvent -FilterHashtable @{LogName='System'; Id=1074} |
Sort-Object TimeCreated -Descending |
Select-Object -First 1 TimeCreated, @{Name='User';Expression={$_.Properties[1].Value}}, Message
