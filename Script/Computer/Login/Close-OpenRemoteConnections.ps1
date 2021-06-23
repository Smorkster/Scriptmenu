<#
.Synopsis End active remote connection
.Description Ends an active remote connection on given computer.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$CaseNr = Read-Host "Related casenumber (if any) "
try
{
	$ComputerName = $args[2]

	Get-service -ComputerName $Computername -Name CmRcService | Restart-Service
	Write-Host -ForegroundColor Green "Remote connection closed!"
}
catch
{
	Write-Host -ForegroundColor Yellow "Can't reach $ComputerName"
	Write-Host -ForegroundColor Red $_.Exception.Message

}

WriteLog -LogText "$CaseNr $ComputerName"

EndScript
