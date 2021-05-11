<#
.Synopsis Get local admin registered on remote computer
.Description Get local admin registered on remote computer.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = Read-Host "$( $msgTable.QComputer )"

$Computer = Get-ADComputer $ComputerName -Properties adminDescription

if ( $null -eq $Computer.adminDescription )
{
	Write-Host "$( $msgTable.StrNoLA )"
	$logText = $msgTable.StrLogNoLA
}
else
{
	$logText = $Computer.adminDescription
	foreach ( $data in ( $Computer.adminDescription -split ";" | Where-Object { $_ -ne "" } ) )
	{
		$split = $data -split ":"
		Write-Host "$( $msgTable.StrOutDate ): $( $split[0] )`n$( $msgTable.StrOutUser ): $( $split[1] )"
	}
}

WriteLog -LogText "$( $Computer.Name ) > $logText" | Out-Null
EndScript
