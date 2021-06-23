<#
.Synopsis Send message to remote computer
.Description Sends a message to the given computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

$Message = Read-Host "$( $msgTable.StrMessage )"

Invoke-Command -ComputerName $ComputerName -ArgumentList $Message -ScriptBlock ` {
	Param( $Message )
	$CmdMessage = { C:\windows\system32\msg.exe * "$Message" }
	$CmdMessage | Invoke-Expression
}

WriteLog -LogText "$ComputerName > '$Message'" | Out-Null
EndScript
