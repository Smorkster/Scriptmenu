<#
.Synopsis View logged in users
.Description List all logged in users on the specified computer.
.Depends WinRM
.State Prod
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

$Users = wmic /node:$ComputerName ComputerSystem Get UserName | Where-Object { $_ -notmatch "UserName" -and $_ -ne "" }
$Users

WriteLogTest -Text $Users.Trim() -UserInput $ComputerName -Success $true | Out-Null
EndScript
