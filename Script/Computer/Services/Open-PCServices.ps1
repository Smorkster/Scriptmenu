<#
.Synopsis Open services on remote computer
.Description Open Windows servicesmanager, connected to the given computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

C:\Windows\System32\services.msc -a /computer=$ComputerName

WriteLog -LogText "$ComputerName" | Out-Null
EndScript
