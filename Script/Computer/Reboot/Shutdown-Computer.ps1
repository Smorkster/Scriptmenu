<#
.Synopsis Turn off remote computer
.Description Forces a shutdown of given computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

Stop-Computer -ComputerName $ComputerName -Force

WriteLog -LogText "$ComputerName" | Out-Null
EndScript
