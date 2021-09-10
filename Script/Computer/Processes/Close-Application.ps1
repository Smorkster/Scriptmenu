<#
.Synopsis Close application on remote computer
.Description Close application on remote computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]
$failed = [System.Collections.ArrayList]::new()
$successfull = [System.Collections.ArrayList]::new()

Write-Host $msgTable.StrGetApps
$apps = Get-CimInstance -ComputerName $ComputerName -ClassName win32_process | Select-Object Name, ProcessID | Sort-Object Name
$apps | Out-Host

$ProcIDs = ( Read-Host "$( $msgTable.QPID )" ) -split "\W" | Where-Object { $_ }

foreach ( $p in $ProcIDs )
{
	if ( $apps.ProcessID -contains $p )
	{
		Write-Host "$( $msgTable.StrTerminatingApp ) '$( $apps.Where( { $_.ProcessID -eq "$p" } ).Name )' ($p)"
		$term = Get-CimInstance -ComputerName $ComputerName -ClassName win32_process -Filter "ProcessID like '$p'" | Invoke-CimMethod -MethodName Terminate
		if ( $term.ReturnValue -eq 0 )
		{
			[void] $successfull.Add( ( $apps.Where( { $_.ProcessID -eq "$p"} ).Name ) )
		}
		else
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
	}
	else
	{
		[void] $failed.Add( [pscustomobject]@{ ID = $p ; $msgTable.StrErrCause = $msgTable.StrErrNoApp } )
	}
}

$OFS = ", "
if ( $failed.Count -gt 0 )
{
	Write-Host "`n`n$( $msgTable.StrErrTitle )"
	$failed | Sort-Object $msgTable.StrErrCause | Out-Host
	$eh = WriteErrorlogTest -LogText ( $failed | Out-String ) -UserInput ( [string]$ProcIDs ) -Severity "OtherFail"
}

WriteLogTest -UserInput ( [string]$ProcIDs ) -Text "$( $successfull.Count ) $( $msgTable.LogAppsClosed )`n$( $successfull )$( if ( $failed.Count -gt 0 ) { "`n$( $failed.Count ) $( $msgTable.LogAppsFails )" } )" -ComputerName $ComputerName -Success ( $failed.Count -eq 0 ) -ErrorLogHash $eh | Out-Null
EndScript
