#Description = Start SMS & CM agents on remote computer
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$CaseNr = Read-Host "Related casenumber (if any) "
Invoke-Command -ComputerName $ComputerName -Scriptblock { Restart-Service -Name 'CcmExec' ; Restart-Service -Name 'CmRcService' }

WriteLog -LogText "$CaseNr $( $ComputerName.ToUpper() )"

EndScript
