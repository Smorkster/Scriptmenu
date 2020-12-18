<#
.Synopsis Update and verify deployed applications for remote computer
.Description Starts a search for updates and deployed applications with CM agent on given computer.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]
$CaseNr = Read-Host "Related casenumber (if any) "

Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000003}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000108}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000113}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000114}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000121}'

WriteLog -LogText "$CaseNr $( $ComputerName.ToUpper() )"
EndScript
