#Description = Restart tasks in CM agent on remote computer
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$CaseNr = Read-Host "Related casenumber (if any) "
$Info = Invoke-Command -ComputerName $ComputerName -ScriptBlock `
{
	$CITask = Get-WmiObject -Query "select * from CCM_CITask where TaskState != ' PendingSoftReboot' AND TaskState != 'PendingHardReboot' AND TaskState != 'InProgress'" -namespace root\ccm\CITasks
	if ($CITask -ne $NULL)
	{
		$CITask | Remove-WmiObject -Whatif
		$CITask | Remove-WmiObject
	}
	else
	{
		$Info = "CCM_CITasks is empty. Nothing to do"
	}
	
	Start-Sleep -Seconds 10
	Restart-Service -Name CcmExec -Force
}

Write-Host $Info
Write-Host "You can now ask the user to reboot computer."

WriteLog -LogText "$CaseNr $( $ComputerName.ToUpper() )"

EndScript
