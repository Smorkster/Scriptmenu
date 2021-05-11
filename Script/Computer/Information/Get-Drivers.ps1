<#
.Synopsis Show installed drivers on remote computer
.Description Lists all installed drivers on given computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

Write-Host $msgTable.StrStart
$ComputerName = $args[1]

$a = ( driverquery /s $ComputerName /v /fo list ) -replace [char]8221, "ö" -replace [char]255, ","
$l = New-Object System.Collections.ArrayList
foreach ( $b in $a )
{
	if ( $b -eq "" )
	{
		if ( @( $o | Get-Member -MemberType NoteProperty ).Count -eq 15 ) { [void] $l.add( $o ) }
		$o = [pscustomobject]::new()
	}
	else
	{
		$x = $b -split "`:"
		$o | Add-Member -MemberType NoteProperty -Name $x[0] -Value ( $x[1].Trim() )
	}
}
$l = $l | Sort-Object "Display Name"

$outputFile = WriteOutput -Output ( ( driverquery /s $ComputerName /v /fo table ) -replace [char]8221, "ö" -replace [char]255, "," )

switch ( ( Read-Host ( $msgTable.StrShow ) ) )
{
	"1" { Start-Process notepad $outputFile -Wait ; $View = 1 }
	"2" { $l | Out-GridView -Title $ComputerName -Wait ; $View = 2 }
	"3" { $l | Out-Host ; $View = 2 }
}

WriteLog -LogText "$ComputerName ($View)`r`n`t$outputFile" | Out-Null
EndScript
