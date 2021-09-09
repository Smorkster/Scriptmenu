<#
.Synopsis Find newly deployed applications for remote computer
.Description Find newly deployed applications for remote computer.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

try
{
	Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000022}'
	Write-Host $msgTable.StrDone
}
catch
{
	Write-Host $msgTable.StrError
	Write-Host $_
	$eh = WriteErrorlogTest -LogText $_ -UserInput "$ComputerName`n{00000000-0000-0000-0000-000000000022}" -Severity "OtherFail"
}

WriteLogTest -Text "." -UserInput "$ComputerName`n{00000000-0000-0000-0000-000000000022}" -Success ( $eh -eq $null ) -ErrorLogHash $eh | Out-Null
EndScript
