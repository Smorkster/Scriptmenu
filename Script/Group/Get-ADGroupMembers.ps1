<#
.Synopsis List all AD-objects that are members of AD-group
.Description List all AD-objects, users/groups/computers etc, that are members of given AD-group.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

Write-Host "$( $msgTable.StrTitle )`n"

$grpName = Read-Host "$( $msgTable.QGName ) "

Get-ADGroupMember -Identity $grpName | Foreach-Object { $members += "$_.ObjectClass`t$_.Name`r`n" }

WriteOutput -Output "Grupp $grpName :`r`n$members"
WriteLog -LogText "$grpName`r`n`t$outputFile" | Out-Null
EndScript
