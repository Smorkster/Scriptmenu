<#
.Synopsis Translates an IP-address to a computername
.Description Searches for the IP-address, and lists the unit currently using it.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$Destination = Read-Host $msgTable.QIP

try
{
	$Response = Resolve-DnsName -Name $Destination -Type A_AAAA -ErrorAction Stop
	$Device = ( $Response.NameHost -split "\w" )[0].ToUpper()
}
catch
{
	$Device = $msgTable.NoDevice
}

Write-Host $Device
WriteLog -LogText "$Destination > $Device" | Out-Null
EndScript
