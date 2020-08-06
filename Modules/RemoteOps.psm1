# A module for functions operating on remote computer
# Use this to import module:
# Import-Module "$( $args[0] )\Modules\RemoteOps.psm1" -Force

######################################################################
# Create a job to check for applicationupgrades in 10 minutes
function RunCycle
{
	param( $ComputerName, $CykelName )
	Invoke-Command -ComputerName $ComputerName -ScriptBlock `
	{
		param ( $Name )
		ipmo PSScheduledJob
		$z = ( Get-Date ).AddMinutes( 10 ).ToString( "HH:mm:ss" )
		$T = New-JobTrigger -Once -At $z
		Register-ScheduledJob -Name $Name -Trigger $T -ScriptBlock `
		{
			Invoke-WmiMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000113}"
			Unregister-ScheduledJob Test-OpenIE
		}
	} -ArgumentList $CycleName
	Write-Host "In 10 minutes the computer will check for updates." 
}

$nudate = Get-Date -Format "yyyy-MM-dd HH:mm"
$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.FullName
$CallingScript = ( Get-Item $MyInvocation.PSCommandPath ).BaseName

Export-ModuleMember -Function *
