<#
.Synopsis Send message to remote computer
.Description Sends a message to the given computer.
.Depends WinRM
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$Message = Read-Host "$( $msgTable.StrMessage )"

Invoke-Command -computername $ComputerName -Args $Message -ScriptBlock ` {
	Param( $Message )
	$CmdMessage = { C:\windows\system32\msg.exe * "$Message" }
	$CmdMessage | Invoke-Expression
}

WriteLog -LogText "$ComputerName > '$Message'" | Out-Null
EndScript
