<#
.Synopsis Show systeminformation for remote computer
.Description Show system information for given computer, such as operatingsystem, date of installation, installed hotfixes etc.
.Depends WinRM
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

Write-Host "$( $msgTable.StrStart )"
$info = ( systeminfo.exe /s $ComputerName ).Replace( "ÿ", ",").Replace( '„', 'ä' )

$info | Out-Host
$outputFile = WriteOutput -Output $info

WriteLog -LogText "$ComputerName`r`n`t$outputFile" | Out-Null
EndScript
