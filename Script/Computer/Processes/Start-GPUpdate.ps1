<#
.Synopsis Start Group policy update on remote computer
.Description Updates group policy on given computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

Invoke-GPUPDATE -Computer $ComputerName -Force

WriteLog -LogText "$ComputerName" | Out-Null
EndScript
