<#
.Synopsis List all AD-objects that are members of AD-group
.Description List all AD-objects, users/groups/computers etc, that are members of given AD-group.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

Write-Host "Listing alla members (users, computers, printers etc)`n"

$CaseNr = Read-Host "Related casenumber (if any) "
$Input = Read-Host "Groupname to search for "

Get-ADGroupMember -Identity $Input | % { $members += "$_.ObjectClass`t$_.Name`r`n" }

WriteOutput -Output "Group $Input:`r`n$members"
WriteLog -LogText "$CaseNr $Input`r`n`t$outputFile"
EndScript
