<#
.Synopsis Restart remote computer
.Description Forces a reboot of given computer.
.Depends WinRM
.State Prod
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

try { Restart-Computer -ComputerName $ComputerName -Force -Wait -For PowerShell -Timeout 300 -Delay 2 }
catch
{
	Write-Host $msgTable.ErrMessage
	Write-Host $_
	$eh = WriteErrorlogTest -LogTest $_ -UserInput $ComputerName -Severity "OtherFail"
}

WriteLogTest -Text "." -UserInput $ComputerName -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
EndScript
