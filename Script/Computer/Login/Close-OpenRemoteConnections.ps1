<#
.Synopsis End active remote connection
.Description Ends an active remote connection on given computer.
.State Prod
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]
$Success = $true

try
{
	Get-Service -ComputerName $Computername -Name CmRcService -ErrorAction Stop | Restart-Service
	Write-Host -ForegroundColor Green $msgTable.StrServiceRestarted
}
catch [Microsoft.PowerShell.Commands.ServiceCommandException]
{
	Write-Host -ForegroundColor Yellow $msgTable.StrComputerNotFound
	Write-Host -ForegroundColor Red $_.Exception.Message
	$eh = WriteErrorlogTest -LogText $_ -UserInput $ComputerName -Severity "ConnectionFail"
}
catch
{
	Write-Host -ForegroundColor Yellow $msgTable.StrOtherError
	Write-Host -ForegroundColor Red $_.Exception.Message
	$eh = WriteErrorlogTest -LogText $_ -UserInput $ComputerName -Severity "OtherFail"
}

WriteLogTest -Text "." -UserInput $ComputerName -Success $Success -ErrorLogHash $eh | Out-Null

[console]::ForegroundColor = "yellow"
Read-Host("<press enter to exit>")
[console]::ResetColor()