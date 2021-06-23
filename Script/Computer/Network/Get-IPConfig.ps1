<#
.Synopsis Show IP configuration on remote computer
.Description Runs command 'ipconfig /all' on given computer. The Information is then listed in consolewindow.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

$conf = Invoke-Command -Computername $ComputerName -Scriptblock { ipconfig /all }

$outputFile = WriteOutput -Output $conf

Start-Process notepad $outputFile -Wait

WriteLog -LogText "$ComputerName`r`n`t$outputFile" | Out-Null
EndScript
