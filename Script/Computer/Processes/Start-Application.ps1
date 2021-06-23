<#
.Synopsis Start application on remote computer
.Description Start application on remote computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

$Program = Read-Host "$( $msgTable.QApp )"

Invoke-Command -ComputerName $ComputerName -Scriptblock { Start-Process $Using:Program }

WriteLog -LogText "$ComputerName $Program" | Out-Null
EndScript
