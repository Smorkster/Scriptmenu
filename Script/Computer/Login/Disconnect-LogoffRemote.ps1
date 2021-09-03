<#
.Synopsis Force logout for all users on remote computer
.Description Forces logout of all users on given computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]
$Success = $true

try
{
	$ErrorActionPreference = "Stop"
	$Info = Invoke-Command -ComputerName $ComputerName -ScriptBlock `
	{
		function RemoveSpace( [string]$text )
		{
			$private:array = $text.Split( " ", [StringSplitOptions]::RemoveEmptyEntries )
			[string]::Join( " ", $array )
		}

		$quser = quser
		foreach ( $sessionString in $quser )
		{
			$sessionString = RemoveSpace( $sessionString )
			$session = $sessionString.Split()
			if ( $session[1].Equals( $( $msgTable.StrSessionTitle ) ) ) { continue }
			# Use [1] because if the user is disconnected there will be no session ID
			$null = logoff $session[1]
			$Info += "$( $session[0] ) $( $msgTable.StrLoggedOff ).`n"
		}
		$Info
	}
}
catch [System.Management.Automation.RemoteException]
{
	$eh = WriteErrorlogTest -LogText $_ -UserInput $ComputerName -Severity "ConnectionFail"
	$Info = "No user logged on."
	$Success = $false
}
catch
{
	$eh = WriteErrorlogTest -LogText $_ -UserInput $ComputerName -Severity "OtherFail"
	$Success = $false
}

Write-Host $Info
$outputFile = WriteOutput -Output $Info

WriteLogTest -Text $Info -UserInput $ComputerName -Success $Success -OutputPath $outputFile -ErrorLogHash $eh | Out-Null
EndScript
