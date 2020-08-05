# A module for functions operating with SysMan 
# Use this to import module:
# Import-Module "$( $args[0] )\Modules\SysManOps.psm1" -Force

######################################################################################################
# Byter Office version, från Office ProfessionalPlus, till ProPlus (som innehåller Outlook och Skype)
function BytInstallation
{
	param( $ComputerName, $OldVersion, $NewVersion )
	Write-Host "DEBUG: Office funktionen körs"

	$ServerUrl = "http://sysman.sll.se/sysman"
	$Application = ( Get-ADObject -LDAPFilter "(&(objectclass=group)(name=$OldVersion))" | select -ExpandProperty name ).Replace( "_I", "" )
	$NewApplication = ( Get-ADObject -LDAPFilter "(&(objectclass=group)(name=$NewVersion))" | select -ExpandProperty name ).Replace( "_I", "" )

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

$nudate = Get-Date -Format "yyyy-MM-dd HH:mm"
$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.FullName
$CallingScript = ( Get-Item $MyInvocation.PSCommandPath ).BaseName

Export-ModuleMember -Function *
