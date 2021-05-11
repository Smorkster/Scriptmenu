<#
.Synopsis Restart remote computer
.Description Forces a reboot of given computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

Restart-Computer -ComputerName $ComputerName -Force -Wait -For PowerShell -Timeout 300 -Delay 2

WriteLog -LogText "$ComputerName" | Out-Null
EndScript
