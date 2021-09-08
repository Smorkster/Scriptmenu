<#
.Synopsis Turn off remote computer
.Description Forces a shutdown of given computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

try { Stop-Computer -ComputerName $ComputerName -Force -ErrorAction Stop }
catch
{
	Write-Host $msgTable.ErrMessage
	Write-Host $_
	$eh = WriteErrorlogTest -LogTest $_ -UserInput $ComputerName -Severity "OtherFail"
}

WriteLogTest -Text "." -UserInput $ComputerName -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
EndScript
