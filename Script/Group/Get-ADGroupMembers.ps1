<#
.Synopsis List all AD-objects that are members of AD-group
.Description List all AD-objects, users/groups/computers etc, that are members of given AD-group.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

Write-Host "$( $msgTable.StrTitle )`n"
$searchWord = Read-Host $msgTable.QGName
Write-Host $msgTable.StrSearching
$list = [System.Collections.ArrayList]::new()
[array] $Groups = Get-ADGroup -LDAPFilter "(&(Name=*$searchWord*User*)(|(Name=*_R)(Name=*_C)))"

if ( $Groups.Count -eq 0 )
{
	$logText = "$searchWord $( $msgTable.LogNoGroups )"
	Write-Host $msgTable.StrNoGroups
}
else
{
	[array]$selectedGroups = $Groups | Select-Object Name, @{ Name = $msgTable.StrGrpType; Expression = {
			if ( $_.Name -match "_R" ) { $msgTable.StrRead }
			else { $msgTable.StrWrite } } } | `
		Out-GridView -PassThru -Title $msgTable.StrGrpSelectionTitle
	if ( $selectedGroups.Count -eq 0 )
	{
		$logText = "$searchWord $( $msgTable.LogAborted )"
		Write-Host $msgTable.StrAborted
	}
	else
	{
		$selectedGroups | Sort-Object Name | ForEach-Object {
			[array]$Users = Get-ADGroupMember -Identity $_.Name
			if ( $Users.Count -eq 0 ) { $msgTable.StrNoUsers }
			else { [void] $list.Add( [pscustomobject]@{ "Name" = $_.Name; "Users" = $Users.Name } ) }
		}
		$listOutput = $list | ForEach-Object { "$( $msgTable.StrGrpName ) $( $_.Name )`n$( $_.Users | Sort-Object | ForEach-Object { "`t$_`n" } )" }
		$listOutput
		$logText = "$searchWord $( $selectedGroups.Count ) $( $msgTable.LogSelectedCount ) `r`n`t$( WriteOutput -Output $listOutput )"
	}
}

WriteLog -LogText $logText | Out-Null
EndScript
