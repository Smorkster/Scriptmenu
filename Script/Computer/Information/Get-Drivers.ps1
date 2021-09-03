<#
.Synopsis Show installed drivers on remote computer
.Description Lists all installed drivers on given computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

Write-Host $msgTable.StrStart
$ComputerName = $args[2]

$l = [System.Collections.ArrayList]::new()
$l = ( driverquery /s $ComputerName /v /fo csv ) -replace [char]8221, "ö" -replace [char]255, "," | ConvertFrom-Csv | Sort-Object "DisplayName"

$outputFile = WriteOutput -Output ( ( driverquery /s $ComputerName /v /fo table ) -replace [char]8221, "ö" -replace [char]255, "," )

switch ( ( Read-Host ( $msgTable.StrShow ) ) )
{
	"1" { Start-Process notepad $outputFile -Wait ; $View = 1 }
	"2" { $l | Out-GridView -Title $ComputerName -Wait ; $View = 2 }
	"3" { $l | Out-Host ; $View = 2 }
}

WriteLogTest -Text "$( $msgTable.LogViewType ) $View" -UserInput $ComputerName -OutputPath $outputFile | Out-Null
EndScript
