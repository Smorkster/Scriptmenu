#Description = Find printerqueue by IP-address
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$CaseNr = Read-Host "Related casenumber (if any) "
$UserInput = Read-Host "Write IP-address"

if ( $Printers = Get-ADObject -LDAPFilter "(&(objectClass=printQueue)(portName=$UserInput*))" -Properties * )
{
	$Printers | select Name, portName, driverName, location
	$logText = "$UserInput > $( $Printers.Name )"
}
else
{
	Write-Host "No printerqueue registered for IP '$UserInput'"
	$logText = "No printerqueue for '$UserInput'"
}

WriteLog -LogText "$CaseNr $logText"

EndScript
