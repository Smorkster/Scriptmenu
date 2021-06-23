<#
.Synopsis Release remote computers IP-address and requests new
.Description Release remote computers IP-address and request new.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

Invoke-Command -Computername $ComputerName -Scriptblock { ipconfig /release | ipconfig /renew }

WriteLog -LogText "$ComputerName" | Out-Null
EndScript
