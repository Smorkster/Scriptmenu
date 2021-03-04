<#
.Synopsis Open services on remote computer
.Description Open Windows servicesmanager, connected to the given computer.
.Depends WinRM
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

C:\Windows\System32\services.msc -a /computer=$ComputerName

WriteLog -LogText "$ComputerName" | Out-Null
EndScript
