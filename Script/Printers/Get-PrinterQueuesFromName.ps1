<#
.Synopsis List printerqueues based on printername (Ex: Pr_F4_00)
.Description List all printerqueues which has a name matching searchword.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$CaseNr = Read-Host "Related casenumber (if any) "
$Input = Read-Host "Printername or printergroup, ex. Pr_F4_00"

if ( $Printers = Get-ADObject -LDAPFilter "(&(ObjectClass=printQueue)(Name=$Input*))" -Properties * | select Name, location, portName, shortServerName, driverName, printColor, url )
{
	$Printers
	$Printers | foreach `
	{
		$output += "$( $_.name )`r`n`tLocation: $( $_.location )`r`n`tIP: $( $_.portname )`r`n`tServer: $( $_.shortservername )`r`n`tDriver: $( $_.drivername )`r`n`tColor print: $( $_.printcolor )`r`n`tURL: $( $_.url )`r`n`r`n"
	}
	$outputFile = WriteOutput -output $output
	$logText = "$Input > $( $Printers.Count ) printer`r`n`tOutput: $outputFile"
}
else
{
	Write-Host "No printerqueues found from searchterm '$Input'"
	$logText = "$Input > No printer"
}

WriteLog -LogText "$CaseNr $logText"
EndScript
