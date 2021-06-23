<#
.Synopsis List printerqueues based on printername (Ex: Pr_F4_00)
.Description List all printerqueues which has a name matching searchword.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -Argumentlist $args[1]

$CaseNr = Read-Host "Related casenumber (if any) "
$NameImput = Read-Host "Printername or printergroup, ex. Pr_F4_00"

if ( $Printers = Get-ADObject -LDAPFilter "(&(ObjectClass=printQueue)(Name=$NameImput*))" -Properties * | Select-Object Name, location, portName, shortServerName, driverName, printColor, url )
{
	$Printers
	$Printers | ForEach-Object `
	{
		$output += "$( $_.name )`r`n`tLocation: $( $_.location )`r`n`tIP: $( $_.portname )`r`n`tServer: $( $_.shortservername )`r`n`tDriver: $( $_.drivername )`r`n`tColor print: $( $_.printcolor )`r`n`tURL: $( $_.url )`r`n`r`n"
	}
	$outputFile = WriteOutput -output $output
	$logText = "$NameImput
 > $( $Printers.Count ) printer`r`n`tOutput: $outputFile"
}
else
{
	Write-Host "No printerqueues found from searchterm '$NameImput
'"
	$logText = "$NameImput
 > No printer"
}

WriteLog -LogText "$CaseNr $logText"
EndScript
