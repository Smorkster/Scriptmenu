<#
.Synopsis Show installed applications on remote computer
.Description Lists all installed applications on given computer. The list if fetched from the computer, and can thus contain applications installed manually.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

Write-Host "$( $msgTable.StrStart ) $ComputerName`n"

$applications = wmic /node:$ComputerName product get name | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" -and $_ -ne "Name" } | Sort-Object
$applications

$outputFile = WriteOutput -Output $applications
WriteLog -LogText "$ComputerName`r`n`t$outputFile" | Out-Null
EndScript
