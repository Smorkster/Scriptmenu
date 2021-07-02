<#
.Synopsis Check if Java is installed, and what version
.Description Checks if Java is installed and with what version. Asks to list all computers at same department that have Java installed.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

Write-Host "`n$( $msgTable.StrTitleScript ) " -NoNewline
Write-Host "$( $args[2] )" -Foreground Cyan

$Computer = Get-ADComputer $args[2] -Properties *

Start-Job -ScriptBlock { Get-CimInstance -ComputerName $args[0] -Filter "Name like '%Java%'" -ClassName win32_product | Select-Object -ExpandProperty Name } -ArgumentList $Computer.Name -Name GetJava | Out-Null

Write-Host $msgTable.StrTitleSysman -Foreground Cyan
if ( $gpos = $Computer.MemberOf | Where-Object { $_ -like "*Java*_I*" } )
{
	Write-Host "`n$( $msgTable.StrIsInstalled ):`n"
	$gpos | ForEach-Object { ( ( $_ -split "=" )[1] -split "," )[0] }
	$logText = $msgTable.LogIsInstalledSysman
}
else
{
	Write-Host "`n$( $msgTable.StrIsNotInstalled )"
	$logText = $msgTable.LogIsNotInstalledSysman
}

try
{
	Write-Host "`n$( $msgTable.StrTitleInstalled )" -Foreground Cyan
	$Installed = Wait-Job -Name GetJava | Receive-Job
	$Installed | Out-Host
	$logText += ", $( $msgTable.LogIsInstalled )"
}
catch
{
	Write-Host "`n$( $msgTable.ErrNoConnect )"
	$logText += ", $( $msgTable.LogIsNotInstalled )"
}

Remove-Job -Name GetJava -ErrorAction SilentlyContinue

if ( ( Read-Host "`n$( $msgTable.QListOtherComp )" ) -eq "Y" )
{
	$logText +="`r`n`t$( $msgTable.LogOtherComp ): "
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
		$logText += $msgTable.LogNoOtherComp
	}
}

WriteLog -LogText "$( $Computer.Name ), $logText" | Out-Null
EndScript
