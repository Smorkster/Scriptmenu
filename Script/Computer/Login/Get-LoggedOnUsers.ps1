<#
.Synopsis Show logged on users on remote computer
.Description Show logged on users on given computer.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]
$CaseNr = Read-Host "Related casenumber (if any) "

$Users = wmic /node:$ComputerName ComputerSystem Get UserName | where { $_ -notmatch "UserName" -and $_ -ne "" }
$Users

WriteLog -LogText "$CaseNr $( $ComputerName.ToUpper() ) > $( $Users.Trim() )"
EndScript
