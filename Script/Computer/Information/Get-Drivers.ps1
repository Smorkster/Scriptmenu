<#
.Synopsis Show installed drivers on remote computer
.Description Lists all installed drivers on given computer.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

Write-Host $msgTable.StrStart
$ComputerName = $args[1]

$drivers = ( driverquery /s $ComputerName /v /fo list ) -replace [char]8221, "ö" -replace [char]255, ","
$DriverList = New-Object System.Collections.ArrayList
foreach ( $Driver in $drivers )
{
	if ( $Driver -eq "" )
	{
		if ( @( $object | Get-Member -MemberType NoteProperty ).Count -eq 15 ) { [void] $DriverList.Add( $object ) }
		$object = [pscustomobject]::new()
	}
	else
	{
		$x = $Driver -split "`:"
		$object | Add-Member -MemberType NoteProperty -Name $x[0] -Value ( $x[1].Trim() )
	}
}
$DriverList = $DriverList | Sort-Object "Display Name"

$outputFile = WriteOutput -Output ( ( driverquery /s $ComputerName /v /fo table ) -replace [char]8221, "ö" -replace [char]255, "," )

switch ( ( Read-Host ( $msgTable.StrShow ) ) )
{
	"1" { Start-Process notepad $outputFile -Wait ; $View = 1 }
	"2" { $DriverList | Out-GridView -Title $ComputerName -Wait ; $View = 2 }
	"3" { $DriverList | Out-Host ; $View = 2 }
}

WriteLog -LogText "$ComputerName ($View)`r`n`t$outputFile" | Out-Null
EndScript
