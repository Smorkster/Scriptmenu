<#
.Synopsis Restart tasks in CM agent on remote computer
.Description Restart tasks in CM agent on remote computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$Info = Invoke-Command -ComputerName $ComputerName -ScriptBlock `
{
	$CITask = Get-WmiObject -Query "SELECT * FROM CCM_CITask WHERE TaskState != ' PendingSoftReboot' AND TaskState != 'PendingHardReboot' AND TaskState != 'InProgress'" -namespace root\ccm\CITasks
	if ( $CITask -ne $NULL )
	{
		$CITask | Remove-WmiObject -Whatif
		$CITask | Remove-WmiObject
		$ret = $using:msgTable.StrCleared
	}
	else
	{
		$ret = $using:msgTable.StrEmpty
	}
	
	Start-Sleep -Seconds 10
	Restart-Service -Name CcmExec -Force
	$ret
}

Write-Host $Info
Write-Host "$( $msgTable.StrDone )"

WriteLog -LogText "$( $ComputerName.ToUpper() )" | Out-Null
EndScript
