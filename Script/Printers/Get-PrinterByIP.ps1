<#
.Synopsis Find printerqueue by IP-address
.Description Search for IP-address and list the printerqueue connected to it.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$UserInput = Read-Host $msgTable.StrQIp

if ( $Printers = Get-ADObject -LDAPFilter "(&(objectClass=printQueue)(portName=$UserInput*))" -Properties * )
{
	$Printers | Select-Object Name, portName, driverName, location
	$logText = "$UserInput > $( $Printers.Name )"
	Write-Host $logText
}
else
{
	Write-Host "$( $msgTable.ErrNoPrinter ) '$UserInput'"
	$logText = "$( $msgTable.LogNoPrinter ) '$UserInput'"
}

WriteLog -LogText $logText | Out-Null
EndScript
