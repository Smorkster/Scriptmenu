<#
.Synopsis Open webpage on remote computer
.Description Open webpage on remote computer.
.Depends WinRM
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]
$Adress = Read-Host "$( $msgTable.QAddress )"

Invoke-Command -ComputerName $ComputerName -Scriptblock ` { start $Using:Adress }

WriteLog -LogText "$ComputerName > $Adress" | Out-Null
EndScript
