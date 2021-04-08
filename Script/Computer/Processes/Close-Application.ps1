<#
.Synopsis Close application on remote computer
.Description Close application on remote computer.
.Depends WinRM
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]
$failed = New-Object System.Collections.ArrayList
$succesfull = New-Object System.Collections.ArrayList

Write-Host $msgTable.StrGetApps
$apps = Get-CimInstance -ComputerName $ComputerName -ClassName win32_process | Select-Object Name, ProcessID | Sort-Object Name
$apps | Out-Host

$ProcIDs = ( Read-Host "$( $msgTable.QPID )" ) -replace " " -split ","

foreach ( $p in $ProcIDs )
{
	if ( $apps.ProcessID -contains $p )
	{
		Write-Host "$( $msgTable.StrTerminatingApp ) '$( $apps.Where( { $_.ProcessID -eq "$p"} ).Name )' ($p)"
		$term = Get-CimInstance -ComputerName $ComputerName -ClassName win32_process -Filter "ProcessID like '$p'" | Invoke-CimMethod -MethodName Terminate
		if ( $term.ReturnValue -ne 0 )
		{
			switch( $term.ReturnValue )
			{
				2 { $t = "CIM Error Access denied" }
				3 { $t = "CIM Error Insufficient privilege" }
				8 { $t = "CIM Error Unknown failure" }
				9 { $t = "CIM Error Path not found" }
				21 { $t = "CIM Error Invalid parameter" }
				default { $t = "CIM Error Other" }
			}
			[void] $failed.Add( [pscustomobject]@{ ID = $p ; $msgTable.StrErrCause = $t } )
		}
		else
		{
			[void] $succesfull.Add( ( $apps.Where( { $_.ProcessID -eq "$p"} ).Name ) )
		}
	}
	else
	{
		[void] $failed.Add( [pscustomobject]@{ ID = $p ; $msgTable.StrErrCause = $msgTable.StrErrNoApp } )
	}
}

if ( $failed.Count -gt 0 )
{
	Write-Host "`n`n$( $msgTable.StrErrTitle )"
	$failed | Out-Host
}

WriteLog -LogText "$ComputerName $succesfull" | Out-Null
EndScript
