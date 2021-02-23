<#
.Synopsis Check if Java is installed, and what version
.Description Checks if Java is installed and with what version. Asks if all computers at same department, having Java installed, is to be listed.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]
$Computer = Get-ADComputer $ComputerName -Properties *

if ( $gpos = $Computer.MemberOf | Where-Object { $_ -like "*Java*_I*" } )
{
	Write-Host "`n$( $msgTable.StrIsInstalled ):`n"
	$gpos | ForEach-Object { ( ( $_ -split "=" )[1] -split "," )[0] }
	$logText = $msgTable.StrIsInstalledLog
}
else
{
	Write-Host "`n$( $msgTable.StrIsNotInstalled )"
	$logText = StrIsNotInstalledLog
}

if ( ( Read-Host $msgTable.QListOtherComp ) -eq "Y" )
{
	$logText +="`r`n`t$( $msgTable.StrOtherCompLog ): "
	if ( $sameLocation = Get-ADComputer -LDAPFilter "($( $msgTable.CodeDepPropName )=$( $Computer.( $msgTable.CodeDepPropName ) ))" -Properties MemberOf | Select-Object @{ Name = "Name"; Expression = { $_.Name } }, @{ Name = "Java"; Expression = { ( ( ( ( $_.MemberOf | Where-Object { $_ -like "*Java*_I*" } ) -split "=" )[1] ) -split "," )[0] } } | Where-Object { $_.Java -ne "" } | Sort-Object Name )
	{
		$sameLocation | Sort-Object Name | Out-Host

		$output = @()
		$sameLocation | ForEach-Object { $output += "$( $_.Name ) $( $_.Java )`r`n" }
		$outputFile = WriteOutput -Output "$( $msgTable.StrOtherComp ) '$( $Computer.( $msgTable.CodeDepPropName ) )':`r`n$output"
		$logText += $outputFile
	}
	else
	{
		$logText += $msgTable.StrNoOtherComp
	}
}

WriteLog -LogText "$ComputerName, $logText" | Out-Null
EndScript
