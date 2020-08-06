#Description = Translate IP-address to computername
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$CaseNr = Read-Host "Casenumber (if any) "
$Destination = Read-Host "IP-address to translate"

$Unit = nslookup $Destination
WriteLog -LogText "$CaseNr $Destination > $Unit"

EndScript
