<#
.Synopsis Helps handle 'Waiting for userlogin'
.Description Clears tasklist for CCMEXEC. This may help errormessage "Waiting for userlogin".
.Depends WinRM
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

Invoke-Command -ComputerName $ComputerName -ScriptBlock `
{
	$CITask = Get-WmiObject -Query "SELECT * FROM CCM_CITask WHERE TaskState != ' PendingSoftReboot' AND TaskState != 'PendingHardReboot' AND TaskState != 'InProgress'" -Namespace root\ccm\CITasks
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
}

Write-Host "$( $msgTable.StrDone )"

WriteLog -LogText "$ComputerName" | Out-Null
EndScript
