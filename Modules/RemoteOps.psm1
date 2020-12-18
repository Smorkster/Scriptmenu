# A module for functions operating on remote computer
# Use this to import module:
# Import-Module "$( $args[0] )\Modules\RemoteOps.psm1" -Force

######################################################################
# Create a job to check for applicationupgrades in 10 minutes
function RunCycle
{
	param( $ComputerName, $CykelName )
	try
	{
		Invoke-Command -ComputerName $ComputerName -ScriptBlock `
		{
			param ( $Name )
			Import-Module PSScheduledJob
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
	catch [System.Management.Automation.Remoting.PSRemotingTransportException]
	{
		Write-Host "Could not reach computer."
	}
	catch
	{
		Write-Host "Error upon trying to reach computer:`n$( $_.CategoryInfo.Reason )`n$( $_.Exception )"
	}
}

############################################
# Send a toastmessage to designated computer
function SendToast
{
	param ( $Message , $ComputerName )
	$code = {
		$XmlString = @"
<toast duration="Long">
	<visual>
		<binding template="ToastGeneric">
			<text>Message from Servicedesk</text>
			<text>$Message</text>
		</binding>
	</visual>
	<audio src="ms-winsoundevent:Notification.Default" />
</toast>
"@

		$AppId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
		$null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
		$null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

		$ToastXml = [Windows.Data.Xml.Dom.XmlDocument]::new()
		$ToastXml.LoadXml($XmlString)

		$Toast = [Windows.UI.Notifications.ToastNotification]::new( $ToastXml )
		[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier( $AppId ).Show( $Toast )
	}

	Invoke-Command -ComputerName $ComputerName -ScriptBlock $code
}

$nudate = Get-Date -Format "yyyy-MM-dd HH:mm"
$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.FullName
$CallingScript = ( Get-Item $MyInvocation.PSCommandPath ).BaseName

Export-ModuleMember -Function *
