<#
.Synopsis Update and verify deployed applications for remote computer
.Description Starts a search for updates and deployed applications with CM agent on given computer.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]
$eh = @()

'{00000000-0000-0000-0000-000000000003}',
'{00000000-0000-0000-0000-000000000108}',
'{00000000-0000-0000-0000-000000000113}',
'{00000000-0000-0000-0000-000000000114}',
'{00000000-0000-0000-0000-000000000121}' | ForEach-Object {
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
