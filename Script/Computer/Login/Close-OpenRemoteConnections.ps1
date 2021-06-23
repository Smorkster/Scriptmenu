<#
.Synopsis End active remote connection
.Description Ends an active remote connection on given computer.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

Try {
$ComputerName = $args[2]

	Get-Service -ComputerName $Computername -Name CmRcService | Restart-Service
	Write-Host -ForegroundColor Green $msgTable.StrServiceRestarted

}
Catch {

	Write-Host -ForegroundColor Yellow $msgTable.StrComputerNotFound
	Write-Host -ForegroundColor Red $_.Exception.Message
	WriteErrorLog -LogText $_

}

WriteLog -LogText $ComputerName | Out-Null
EndScript
