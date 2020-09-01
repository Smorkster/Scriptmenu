<#
.Synopsis Helps handle 'Waiting for userlogin'
.Description Clears tasklist for CCMEXEC. This may help errormessage "Waiting for userlogin".
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]
$CaseNr = Read-Host "Related casenumber (if any) "

Invoke-Command -ComputerName $ComputerName -ScriptBlock `
{
	$CITask = Get-WmiObject -Query "select * from CCM_CITask where TaskState != ' PendingSoftReboot' AND TaskState != 'PendingHardReboot' AND TaskState != 'InProgress'" -Namespace root\ccm\CITasks
	if ( $CITask -ne $NULL )
	{
		$CITask | Remove-WmiObject -Whatif
		$CITask | Remove-WmiObject
		Write-Host "CCM_CITask is now cleared"
	}
	else
	{
		Write-Host "List for CCM_CITask is empty. Nothing to do."
	}

	Start-Sleep -Seconds 10
	Restart-Service -Name CcmExec -Force
}

Write-Host "You can now ask the user to reboot the computer."

WriteLog -LogText "$CaseNr $ComputerName"
EndScript
