<#
.Synopsis List printerqueues based on printername (Ex: Pr_F4_00)
.Description List all printerqueues which has a name matching searchword.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

Write-Host "$( $msgTable.StrScriptTitle )`n"
$prtName = Read-Host $msgTable.StrQName

if ( $Printers = Get-ADObject -LDAPFilter "(&(ObjectClass=printQueue)(Name=$prtName*))" -Properties * | Select-Object Name, location, portName, shortServerName, driverName, printColor, url )
{
	$Printers
	$Printers | Foreach-Object `
	{
		$output += "$( $_.name )`r`n`t$( $msgTable.StrPropLoc ): $( $_.location )`r`n`t$( $msgTable.StrPropIp ): $( $_.portname )`r`n`t$( $msgTable.StrPropServ ): $( $_.shortservername )`r`n`t$( $msgTable.StrPropDriv ): $( $_.drivername )`r`n`t$( $msgTable.StrPropClr ): $( $_.printcolor )`r`n`t$( $msgTable.StrPropUrl ): $( $_.url )`r`n`r`n"
	}
	$outputFile = WriteOutput -Output $output
	$logText = "$prtName > $( $Printers.Count )`r`n`tOutput: $outputFile"
}
else
{
	Write-Host "$( $msgTable.ErrNoFound ) '$prtName'"
	$logText = "$prtName > $( $msgTable.StrLogNoFound )"
}

WriteLog -LogText $logText | Out-Null
EndScript
