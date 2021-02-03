# A module for functions operating on remote computer
# Use this to import module:
# Import-Module "$( $args[0] )\Modules\RemoteOps.psm1" -Force

#############################################################################
# Create a job to in 10 minutes check for updates of distributed applications
function RunCycle
{
	param( $ComputerName, $CycleName )
	try
	{
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
			} | Out-Null
		} -ArgumentList $CycleName -ErrorAction Stop
		Write-Host $IntmsgTable.RunCycle1
	}
	catch [System.Management.Automation.Remoting.PSRemotingTransportException]
	{
		Write-Host $IntmsgTable.RunCycle2
	}
	catch
	{
		Write-Host "$( $IntmsgTable.RunCycle3):`n$( $_.CategoryInfo.Reason )`n$( $_.Exception )"
	}
}

############################################
# Send a toastmessage to designated computer
function SendToast
{
	param ( $Message, $ComputerName )

	try { $WinVersion = ( Get-CimInstance -ComputerName $ComputerName -ClassName win32_operatingsystem -ErrorAction Stop ).Version } catch { return 1 }
	if ( ( $WinVersion.Split( "." ) )[0] -ge 10 )
	{
		$code = {
			$XmlString = "<toast duration=`"Short`" scenario=`"alarm`"><visual><binding template=`"ToastGeneric`"><text>$( $IntmsgTable.SendToast1 )</text><text>$Message</text></binding></visual><audio src=`"ms-winsoundevent:Notification.Default`" /></toast>"

			$AppId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
			$null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
			$null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

			$ToastXml = [Windows.Data.Xml.Dom.XmlDocument]::new()
			$ToastXml.LoadXml($XmlString)

			$Toast = [Windows.UI.Notifications.ToastNotification]::new( $ToastXml )
			[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier( $AppId ).Show( $Toast )
		}

		try
		{
			Invoke-Command -ComputerName $ComputerName -ScriptBlock $code
			return 0
		}
		catch
		{
			return 2
		}
	}
	else
	{
		return 3
	}
}

$nudate = Get-Date -Format "yyyy-MM-dd HH:mm"
$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.FullName
try { $CallingScript = ( Get-Item $MyInvocation.PSCommandPath ).BaseName } catch {}
Import-LocalizedData -BindingVariable IntmsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | select -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function *
