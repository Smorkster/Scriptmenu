<#
.Synopsis Show logged on users on remote computer
.Description Show logged on users on given computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]
$CaseNr = Read-Host "Related casenumber (if any) "

$Users = wmic /node:$ComputerName ComputerSystem Get UserName | Where-Object { $_ -notmatch "UserName" -and $_ -ne "" }
$Users

WriteLog -LogText "$CaseNr $( $ComputerName.ToUpper() ) > $( $Users.Trim() )"
EndScript
