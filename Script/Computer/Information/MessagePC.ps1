#Description = Send message to remote computer
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$CaseNr = Read-Host "Related casenumber (if any) "
$Message = Read-Host "Write message"

Invoke-Command -ComputerName $ComputerName -Args $Message -ScriptBlock `
{
	Param( $Message )
	$CmdMessage = { C:\Windows\system32\msg.exe * "$Message" }
	$CmdMessage | Invoke-Expression
}

WriteLog -LogText "$CaseNr $ComputerName > '$Message'"

EndScript
