<#
.Synopsis Start application on remote computer
.Description Start application on remote computer.
.Depends WinRM
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$Program = Read-Host "$( $msgTable.QApp )"

Invoke-Command -ComputerName $ComputerName -Scriptblock { start $Using:Program }

WriteLog -LogText "$ComputerName $Program" | Out-Null
EndScript
