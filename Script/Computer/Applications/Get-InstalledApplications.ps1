<#
.Synopsis Show installed applications on remote computer
.Description Lists all installed applications on given computer. The list if fetched from the computer, and can thus contain applications installed manually.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

Write-Host "$( $msgTable.StrStart ) $ComputerName`n"

( $applications = Get-CimInstance -ClassName win32_product -ComputerName $ComputerName | Sort-Object Caption ) | Out-Host

$outputFile = WriteOutput -Output ( $applications | Select-Object Caption, Description, Version, InstallDate, InstallLocation | ConvertTo-Csv -NoTypeInformation ) -FileExtension "csv"
WriteLogTest -Text "$( $msgTable.LogAppCount ): $( @( $outputFile ).Count )" -UserInput $ComputerName -Success $true -OutputPath $outputFile | Out-Null
EndScript
