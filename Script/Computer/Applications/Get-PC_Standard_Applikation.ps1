<#
.Synopsis Show core applications on remote computer
.Description List all core-applications installed on given computer.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$Sysman = "http://sysman.domain.com/sysman"

$ComputerName = $args[2]

try
{
	$AD = Get-ADComputer $ComputerName -Property MemberOf
	$ADMember = $AD.MemberOf
	$ADFilter = $ADMember
	$ADResult = $ADFilter | Where-Object {$_ -like "*PC*" } | Sort-Object MemberOf

	foreach ( $ObjectMemberAD in $ADResult )
	{
		$Disc = Get-ADGroup $ObjectMemberAD -Properties *
		$DiscValue = ( $Disc ).CN

		if ( $DiscValue -like "*Org1*" )
		{
			try
			{
				foreach ( $ObjectMemberSysman in $DiscValue )
				{
					$PCRoleID = Invoke-RestMethod -Uri "$( $Sysman )/api/Application?name=$( $ObjectMemberSysman )" -UseDefaultCredentials
					$PCRoleIDResult = ( $PCRoleID ).id

					$ConvertID = Invoke-RestMethod -Uri "$( $Sysman )/api/application/Mapping?applicationId=$( $PCRoleIDResult )" -UseDefaultCredentials
					$ConvertIDResult = ( $ConvertID ).result.id

					$StandardApps = Invoke-RestMethod -Uri "$( $Sysman )/api/reporting/System?systemId=$( $ConvertIDResult )" -UseDefaultCredentials
				}
			}
			catch
			{
				Write-Host -ForegroundColor Red $_.Exception.Message
			}
		}
		else
		{
			try
			{
				foreach ( $ObjectMemberSysman in $DiscValue )
				{
					$PCRoleID = Invoke-RestMethod -Uri "$( $Sysman )/api/System?name=$( $DiscValue )" -UseDefaultCredentials
					$PCRoleIDResult = ( $PCRoleID ).id

					$StandardApps = Invoke-RestMethod -Uri "$( $Sysman )/api/reporting/System?systemId=$( $PCRoleIDResult )" -UseDefaultCredentials
				}
			}
			catch
			{
				Write-Host -ForegroundColor Red $_.Exception.Message
			}
		}
		Write-Host -ForegroundColor Green "Core applications for" -NoNewline
		Write-Host ": $ComputerName".ToUpper() -NoNewline
		Write-Host " ($ObjectMemberSysman)"
		$StandardApps.mappedApplications | Select-Object -ExpandProperty Name | Sort-Object
	}
}
catch
{
	Write-Host -ForegroundColor Yellow "Computername not found, verify the name and try again."
	Write-Host -ForegroundColor Red $_.Exception.Message
}

EndScript
