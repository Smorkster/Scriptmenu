<#
.Synopsis Translates an IP-address to a computername
.Description Searches for the IP-address, and lists the unit currently using it.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$Destination = Read-Host $msgTable.QIP

$Unit = nslookup $Destination
$Unit | Out-Host

WriteLog -LogText "$Destination > $Unit" | Out-Null
EndScript
