<#
.Synopsis Show installed printers on remote computer
.Description Show installed printers on remote computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]
$Printers = @()


$Printers = Get-CimInstance -ClassName Win32_Printer -ComputerName $ComputerName | Select-Object -ExpandProperty Name | Sort-Object
$Printers | Out-Host

$OFS = "`n"
WriteLogTest -Text "$( $msgTable.LogNumPrinters ): $( $Printers.Count )`n$( $Printers )" -UserInput $ComputerName -Success $true -OutputPath $outputFile | Out-Null
EndScript
