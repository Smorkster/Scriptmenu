<#
.Synopsis A module for functions operating with SysMan
.Description Use this to import module: Import-Module "$( $args[0] )\Modules\SysManOps.psm1" -Force -ArgumentList $args[1]
.State Prod
.Author Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

function ChangeInstallation
{
	<#
	.Description
		Changes installed version of a deployed application for given computer
	.Parameter ComputerName
		Name of the computer where the operations should occur
	.Parameter OldVersion
		Name (including version) of the application to be replaced. This name must be in the AD
	#>

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

function GetSysManComputerId
{
	<#
	.Description
		Get the internal id in SysMan for a given computer
	.Parameter ComputerName
		Name of the computer to check id for
	.Outputs
		Internal SysMan-id of the computer
	#>
	param ( $ComputerName )
	return ( Invoke-RestMethod -uri "$( $ServerUrl )/api/Client?name=$ComputerName" -UseDefaultCredentials ).Id
}

function GetSysManUserId
{
	<#
	.Description
		Get the internal id in SysMan for given user
	.Parameter Id
		UserId (according to AD) of the user to do the lookup for
	.Outputs
		Internal SysMan-id of the user
	#>

	param ( $Id )

	return ( Invoke-RestMethod -uri "$( $ServerUrl )/api/User?name=$Id" -UseDefaultCredentials ).Id
}

$nudate = Get-Date -Format "yyyy-MM-dd HH:mm"
$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.FullName
try { $CallingScript = ( Get-Item $MyInvocation.PSCommandPath ).BaseName } catch { $CallingScript = $null }
Import-LocalizedData -BindingVariable IntmsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization\$culture\Modules"
$ServerUrl = $IntmsgTable.SysManServerUrl

Export-ModuleMember -Function *
