<#
.Synopsis Force logout for all users on remote computer
.Description Forces logout of all users on given computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]
$CaseNr = Read-Host "Related casenumber (if any) "

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
			if ( $session[1].Equals( "SESSIONSNAMN" ) ) { continue }
			# Use [1] because if the user is disconnected there will be no session ID
			$result = logoff $session[1]
			$Info += "User ""$session[0]"" automatically logged off.`n"
		}
		$Info
	}
}
catch [System.Management.Automation.RemoteException]
{
	$Info = "No user logged on."
}

Write-Host $Info
$outputFile = WriteOutput -Output $Info

WriteLog -LogText "$CaseNr $ComputerName > $( $Info.Count ) användare`r`n`t$outputFile"
EndScript
