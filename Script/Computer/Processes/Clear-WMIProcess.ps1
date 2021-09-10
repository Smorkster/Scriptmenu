<#
.Synopsis Helps handle 'Waiting for userlogin'
.Description Clears tasklist for CCMEXEC. This may help errormessage "Waiting for userlogin".
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

try
{
	$CITask = Get-WmiObject -Query "SELECT * FROM CCM_CITask WHERE TaskState != ' PendingSoftReboot' AND TaskState != 'PendingHardReboot' AND TaskState != 'InProgress'" -Namespace root\ccm\CITasks -ComputerName $ComputerName

	if ( $null -ne $CITask )
	{
		$CITask | Remove-WmiObject -Whatif
		$CITask | Remove-WmiObject
		Write-Host ( $ret = $msgTable.StrCleared )
	}
	else
	{
		Write-Host ( $ret = $msgTable.StrEmpty )
	}

	Start-Sleep -Seconds 10
	try
	{
		Get-Service -Name CcmExec -ComputerName $ComputerName -ErrorAction Stop | Restart-Service -Force -ErrorAction Stop
		Write-Host $msgTable.StrDone
	}
	catch
	{
		Write-Host ( $ret = $msgTable.ErrService )
		Write-Host $_
		$eh += WriteErrorlogTest -LogText $_ -UserInput "$ComputerName`n$( $msgTable.LogErrService )" -Severity "OtherFail"
	}
}
catch
{
	Write-Host ( $ret = $msgTable.ErrMsg )
	Write-Host $_
	$eh += WriteErrorlogTest -LogText $_ -UserInput "$ComputerName`n$( $msgTable.LogErrMsg )" -Severity "OtherFail"
}

WriteLog -Text $ret -UserInput $ComputerName -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
EndScript
