<#
.Synopsis Run all tasks in CM-agent on remote computer
.Description Run all tasks in CM-agent on given computer.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]
$eh = @()

'{00000000-0000-0000-0000-000000000001}',
'{00000000-0000-0000-0000-000000000002}',
'{00000000-0000-0000-0000-000000000003}',
'{00000000-0000-0000-0000-000000000010}',
'{00000000-0000-0000-0000-000000000021}',
'{00000000-0000-0000-0000-000000000022}',
'{00000000-0000-0000-0000-000000000023}',
'{00000000-0000-0000-0000-000000000024}',
'{00000000-0000-0000-0000-000000000025}',
'{00000000-0000-0000-0000-000000000031}',
'{00000000-0000-0000-0000-000000000032}',
'{00000000-0000-0000-0000-000000000040}',
'{00000000-0000-0000-0000-000000000042}',
'{00000000-0000-0000-0000-000000000051}',
'{00000000-0000-0000-0000-000000000108}',
'{00000000-0000-0000-0000-000000000111}',
'{00000000-0000-0000-0000-000000000112}',
'{00000000-0000-0000-0000-000000000113}',
'{00000000-0000-0000-0000-000000000114}',
'{00000000-0000-0000-0000-000000000116}',
'{00000000-0000-0000-0000-000000000120}',
'{00000000-0000-0000-0000-000000000121}',
'{00000000-0000-0000-0000-000000000131}' | ForEach-Object {
	try
	{
		$schedule = $_
		Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule $schedule
	}
	catch { $eh += WriteErrorlogTest -LogText $_ -UserInput "$ComputerName`n$schedule" -Severity "OtherFail" }
}

Write-Host $msgTable.StrDone
if ( $eh.Count -gt 0 )
{
	Write-Error "$( $eh.Count ) $( $msgTable.StrErrors )"
	$Error.Exception.Message | ForEach-Object { "$_`n" }
}

WriteLogTest -Text "." -UserInput $ComputerName -Success ( $eh.Count -eq 0 ) -ErrorLogHash $eh | Out-Null
EndScript
