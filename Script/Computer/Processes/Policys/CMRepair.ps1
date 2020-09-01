<#
.Synopsis Repair CM agent on remote computer
.Description Repair CM agent on given computer.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]
$CaseNr = Read-Host "Related casenumber (if any) "

Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name RepairClient

WriteLog -LogText "$CaseNr $( $ComputerName.ToUpper() )"
EndScript
