<#
.Synopsis A module for functions operating with SysMan
.Description Use this to import module: Import-Module "$( $args[0] )\Modules\SysManOps.psm1" -Force -ArgumentList $args[1]
.State Prod
.Author Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

########################################################################
# Changes installed version of a deployed application for given computer
function ChangeInstallation
{
	param( $ComputerName, $OldVersion, $NewVersion )

	$Application = ( Get-ADObject -LDAPFilter "(&(objectclass=group)(name=$OldVersion))" | Select-Object -ExpandProperty name ).Replace( "_I", "" )
	$NewApplication = ( Get-ADObject -LDAPFilter "(&(objectclass=group)(name=$NewVersion))" | Select-Object -ExpandProperty name ).Replace( "_I", "" )

	$SystemID = ( ( Invoke-WebRequest -Uri "$( $ServerUrl )/api/System?name=$( $Application )" -UseDefaultCredentials -ContentType "application/json" ) | ConvertFrom-Json).ID
	$NewSystemID = ( ( Invoke-WebRequest -Uri "$( $ServerUrl )/api/System?name=$( $NewApplication )" -UseDefaultCredentials -ContentType "application/json" ) | ConvertFrom-Json).ID
	$ComputerID = ( ( Invoke-WebRequest -Uri "$( $ServerUrl )/api/Client?name=$( $ComputerName )" -UseDefaultCredentials -ContentType "application/json" ) | ConvertFrom-Json).ID

	$ComputerCollection = @( "$ComputerID" )
	$SystemCollection = @( "$SystemID" )
	$RequestInput = @{ "Targets" = $ComputerCollection; "Systems" = $SystemCollection }

	$StateResult = ( Invoke-WebRequest -Uri "$( $ServerUrl )/api/application/Uninstall" -Method Post -Body ( ConvertTo-Json -InputObject $RequestInput ) -UseDefaultCredentials -ContentType "application/json" -ErrorAction Stop )

	$SystemCollection = @( "$NewSystemID" )
	$RequestInput = @{ "Targets"=$ComputerCollection; "Softwares"=$SystemCollection }

	$StateResult = ( Invoke-WebRequest -Uri "$( $ServerUrl )/api/application/Install" -Method Post -Body ( ConvertTo-Json -InputObject $RequestInput ) -UseDefaultCredentials -ContentType "application/json" -ErrorAction Stop )
}

#########################################################
# Return the internal id in SysMan for given computername
function GetSysManComputerId
{
	param ( $ComputerName )
	return ( Invoke-RestMethod -uri "$( $ServerUrl )/api/Client?name=$ComputerName" -UseDefaultCredentials ).Id
}

####################################################
# Return the internal id in SysMan for given user id
function GetSysManUserId
{
	param ( $Id )
	( Invoke-RestMethod -uri "$( $ServerUrl )/api/User?name=$Id" -UseDefaultCredentials ).Id
}

$nudate = Get-Date -Format "yyyy-MM-dd HH:mm"
$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.FullName
$CallingScript = ( Get-Item $MyInvocation.PSCommandPath ).BaseName
Import-LocalizedData -BindingVariable IntmsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization\$culture\Modules"
$ServerUrl = $IntmsgTable.SysManServerUrl

Export-ModuleMember -Function *
