<#
.Synopsis Log on to remote computer as admin
.Description Starts a remote connection to computer, loggin in as administrator.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]
$CaseNr = Read-Host "Related casenumber (if any) "

Start-Process -Filepath "C:\Windows\System32\mstsc.exe" -ArgumentList "/v:$ComputerName /f"

WriteLog -LogText "$CaseNr $ComputerName"
EndScript
