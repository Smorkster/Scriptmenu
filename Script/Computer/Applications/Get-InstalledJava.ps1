<#
.Synopsis Check if Java is installed, and what version
.Description Checks if Java is installed and with what version. Asks to list all computers at same department that have Java installed.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

Write-Host "`n$( $msgTable.StrTitleScript ) " -NoNewline
Write-Host "$( $args[2] )" -Foreground Cyan

$Computer = Get-ADComputer $args[2] -Properties *
$Success = $true

Start-Job -ScriptBlock { Get-CimInstance -ComputerName $args[0] -Filter "Name like '%Java%'" -ClassName win32_product | Select-Object -ExpandProperty Name } -ArgumentList $Computer.Name -Name GetJava | Out-Null

Write-Host "`n$( $msgTable.StrTitleSysman )" -Foreground Cyan
if ( $gpos = $Computer.MemberOf | Where-Object { $_ -like "*Java*_I*" } )
{
	Write-Host "$( $msgTable.StrIsInstalled )`n"
	$gpos | ForEach-Object { ( ( $_ -split "=" )[1] -split "," )[0] }
	$logText = $msgTable.LogIsInstalledSysman
}
else
{
	Write-Host "$( $msgTable.StrIsNotInstalled )"
	$logText = $msgTable.LogIsNotInstalledSysman
}

try
{
	Write-Host "`n$( $msgTable.StrTitleInstalled )" -Foreground Cyan
	$Installed = Wait-Job -Name GetJava | Receive-Job
	if ( -not $Installed )
	{
		Write-Host $msgTable.StrIsNotInstalled
		$logText += ", $( $msgTable.LogIsNotInstalled )"
	}
	else
	{
		$Installed | Out-Host
		$logText += ", $( $msgTable.LogIsInstalled )"
	}
}
catch
{
	Write-Host "`n$( $msgTable.ErrNoConnect )"
	$logText += ", $( $msgTable.ErrNoConnect )"
	$Success = $false
}

Remove-Job -Name GetJava -ErrorAction SilentlyContinue

if ( ( Read-Host "`n$( $msgTable.QListOtherComp )" ) -eq "Y" )
{
	$logText += "`n$( $msgTable.LogOtherComp ):"
	if ( $sameLocation = Get-ADComputer -LDAPFilter "($( $msgTable.CodeDepPropName )=$( $Computer.( $msgTable.CodeDepPropName ) ))" -Properties MemberOf | Select-Object @{ Name = "Name"; Expression = { $_.Name } }, @{ Name = "Java"; Expression = { ( ( ( ( $_.MemberOf | Where-Object { $_ -like "*Java*_I*" } ) -split "=" )[1] ) -split "," )[0] } } | Where-Object { $_.Java -ne "" } | Sort-Object Name )
	{
		$sameLocation | Sort-Object Name | Out-Host
		$logText += " $( @( $sameLocation ).Count )"

		$output = @()
		$sameLocation | ForEach-Object { $output += "$( $_.Name ) $( $_.Java )`n" }
		$outputFile = WriteOutput -Output "$( $msgTable.StrOtherComp ) '$( $Computer.( $msgTable.CodeDepPropName ) )':`n$output"
	}
	else
	{
		$logText += " $( $msgTable.LogNoOtherComp )"
	}
}

WriteLogTest -Text $logText -UserInput $Computer.Name -Success $Success -OutputPath $outputFile | Out-Null
EndScript
