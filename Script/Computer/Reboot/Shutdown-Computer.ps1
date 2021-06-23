<#
.Synopsis Turn off remote computer
.Description Forces a shutdown of given computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

Stop-Computer -ComputerName $ComputerName -Force

WriteLog -LogText "$ComputerName" | Out-Null
EndScript
