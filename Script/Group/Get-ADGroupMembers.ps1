<#
.Synopsis List all AD-objects that are members of AD-group
.Description List all AD-objects, users/groups/computers etc, that are members of given AD-group.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

Write-Host "$( $msgTable.StrTitle )`n"
$searchWord = Read-Host "$( $msgTable.QGName )"
Write-Host "$( $msgTable.StrSearching )`n"
$list = [System.Collections.ArrayList]::new()
if ( -not ( [array] $Groups = Get-ADGroup -LDAPFilter "(Name=$searchWord)" ) )
{
	[array] $Groups = Get-ADGroup -LDAPFilter "(Name=*$searchWord*)"
}

if ( $Groups.Count -eq 0 )
{
	$logText = $msgTable.LogNoGroups
	Write-Host $msgTable.StrNoGroups
}
else
{
	if ( $Groups.Count -gt 1 )
	{
		[array]$selectedGroups = $Groups | Select-Object Name, @{ Name = $msgTable.StrGrpType; Expression = {
				if ( $_.Name -match "_R" ) { $msgTable.StrRead }
				else { $msgTable.StrWrite } } } | `
			Out-GridView -PassThru -Title $msgTable.StrGrpSelectionTitle
	}
	else { $selectedGroups = $Groups }

	if ( $selectedGroups.Count -eq 0 )
	{
		$logText = $msgTable.LogAborted
		Write-Host $msgTable.StrAborted
	}
	else
	{
		$selectedGroups | Sort-Object Name | ForEach-Object {
			[array]$Users = Get-ADGroupMember -Identity $_.Name
			$g = [pscustomobject]@{ "Name" = $_.Name; "Users" = "" }
			if ( $Users.Count -eq 0 ) { $g.Users = $msgTable.StrNoUsers }
			else { $g.Users = $Users.Name }
			[void] $list.Add( $g )
		}

		$list | ForEach-Object {
			Write-Host $msgTable.StrGrpName -NoNewline
			Write-Host " $( $_.Name )" -ForegroundColor Green
			$_.Users | Sort-Object | ForEach-Object { Write-Host "`t$_" }
		}
		$OFS = "`n"
		$logText = "$( $selectedGroups.Count ) $( $msgTable.LogSelectedCount )`n$( $list.Name )"
	}
}
$outputFile = WriteOutput -Output ( $list | ForEach-Object { "$( $msgTable.StrGrpName ) $( $_.Name )`n$( $_.Users | Sort-Object | ForEach-Object { "`t$_" } )" } )

WriteLogTest -Text $logText -UserInput "$( $msgTable.LogSearchWord ) $searchWord" -OutputPath $outputFile -Success $true | Out-Null
EndScript
