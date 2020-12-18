<#
.Synopsis Translates an IP-address to a computername
.Description Searches for the IP-address, and lists the unit currently using it.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$CaseNr = Read-Host "Casenumber (if any) "
$Destination = Read-Host "IP-address to translate"

$Unit = nslookup $Destination
$Unit | Out-Host

WriteLog -LogText "$CaseNr $Destination > $Unit"
EndScript
