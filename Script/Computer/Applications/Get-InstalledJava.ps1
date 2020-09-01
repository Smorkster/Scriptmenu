<#
.Synopsis Check if Java is installed, and what version
.Description Checks if Java is installed and with what version. Asks if all computers at same department, having Java installed, is to be listed.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$CaseNr = Read-Host "Related casenumber (if any) "
$Computer = Get-ADComputer $ComputerName -Properties *

if ( $gpos = $Computer.MemberOf | where { $_ -like "*Java*_I*" } )
{
	Write-Host "`nJava is installed:`n"
	$gpos | foreach { ( ( $_ -split "=" )[1] -split "," )[0] }
	$logText = "installed"
}
else
{
	Write-Host "`nJava is not installed"
	$logText = "not installed"
}

if ( ( Read-Host "Show computers at same department with Java installed? (Y/N)" ) -eq "Y" )
{
	$logText +="`r`n`tOther computers at same department: "
	if ( $sameLocation = Get-ADComputer -LDAPFilter "(depId=$( $Computer.depId ))" -Properties MemberOf | select @{ Name = "Name"; Expression = { $_.Name } }, @{ Name = "Java"; Expression = { ( ( ( ( $_.MemberOf | where { $_ -like "*Java*_I*" } ) -split "=" )[1] ) -split "," )[0] } } | where { $_.Java -ne "" } | sort Name )
	{
		$sameLocation

		$output = @()
		$sameLocation | foreach { $output += "$( $_.Name ) $( $_.Java )`r`n" }
		$outputFile = WriteOutput -Output "Computers at department '$( $Computer.depId )' with Java installed:`r`n$output"
		$logText += $outputFile
	}
	else
	{
		$logText += "No computers"
	}
}

WriteLog -LogText "$CaseNr $ComputerName, $logText"
EndScript
