<#
.Synopsis Run all tasks in CM-agent on remote computer
.Description Run all tasks in CM-agent on given computer.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000001}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000002}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000003}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000010}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000021}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000022}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000023}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000024}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000025}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000031}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000032}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000040}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000042}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000051}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000108}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000111}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000112}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000113}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000114}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000116}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000120}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000121}'
Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000131}'

WriteLog -LogText "$( $ComputerName.ToUpper() )" | Out-Null
EndScript
