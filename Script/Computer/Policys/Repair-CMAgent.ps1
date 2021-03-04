<#
.Synopsis Repair CM agent on remote computer
.Description Repair CM agent on given computer.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name RepairClient

WriteLog -LogText "$( $ComputerName.ToUpper() )" | Out-Null
EndScript
