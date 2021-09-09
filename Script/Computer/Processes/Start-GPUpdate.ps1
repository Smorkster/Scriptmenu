<#
.Synopsis Start Group policy update on remote computer
.Description Updates group policy on given computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

try
{
	Invoke-GPUPDATE -Computer $ComputerName -Force
	Write-Host $msgTable.StrDone
}
catch
{
	$eh = WriteErrorlogTest -LogText $_ -UserInput $ComputerName -Severity "OtherFail"
	Write-Host $msgTable.StrError
	Write-Host $_
}

WriteLogTest -Text "." -UserInput $ComputerName -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
EndScript
