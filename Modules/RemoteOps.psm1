<#
.Synopsis A module for functions operating on remote computer
.Description Use this to import module: Import-Module "$( $args[0] )\Modules\RemoteOps.psm1" -Force -ArgumentList $args[1]
.State Prod
.Author Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

function RunCycle
{
	<#
	.Description
		Create a job that will check for updates for distributed applications, the job will start in 10 minutes
	.Parameter ComputerName
		Name of the computer that should run the job
	.Parameter CycleName
		Name of the scheduledjob
	#>

	param( $ComputerName, $CycleName )

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
			} | Out-Null
		} -ArgumentList $CycleName -ErrorAction Stop
		Write-Host $IntmsgTable.RunCycle1
	}
	catch [System.Management.Automation.Remoting.PSRemotingTransportException]
	{
		Write-Host "$( $IntmsgTable.RunCycle2 ):`n$( $_.CategoryInfo.Reason )`n$( $_.Exception )"
	}
	catch
	{
		Write-Host "$( $IntmsgTable.RunCycle3 ):`n$( $_.CategoryInfo.Reason )`n$( $_.Exception )"
	}
}

function SendToast
{
	<#
	.Description
		Send a toastmessage to designated computer
	.Parameter Message
		Text to be shown in the toastmessage
	.Parameter ComputerName
		Name of the computer to receive the toastmessage
	.Outputs
		An integer indicating the success of sending the toastmessage
		0: The toastmessage was send successfully
		1: The remote computer cannot be reached. It is either offline, WinRM is not started, or remote control is active.
		2: An error occured when sending the toastmessage
		3: The receiving computer does not have Windows 10 installed, and can not receive a toastmessage
	#>

	param ( $Message, $ComputerName )

	try { $WinVersion = ( Get-CimInstance -ComputerName $ComputerName -ClassName win32_operatingsystem -ErrorAction Stop ).Version } catch { return 1 }
	if ( ( $WinVersion.Split( "." ) )[0] -ge 10 )
	{
		$code = {
			[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
			$Template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent( [Windows.UI.Notifications.ToastTemplateType]::ToastText02 )

			$RawXml = [xml] $Template.GetXml()
			( $RawXml.Toast.visual.binding.text | Where-Object { $_.id -eq "2" } ).AppendChild( $RawXml.CreateTextNode( $using:Message ) ) > $null

			$SerializedXml = New-Object Windows.Data.Xml.Dom.XmlDocument
			$SerializedXml.LoadXml( $RawXml.OuterXml )

			$Toast = [Windows.UI.Notifications.ToastNotification]::new( $SerializedXml )
			$Toast.Tag = "PowerShell"
			$Toast.Group = "PowerShell"
			$Toast.ExpirationTime = [DateTimeOffset]::Now.AddSeconds( 10 )

			( [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier( $using:IntmsgTable.SendToast1 ) ).Show( $Toast )
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
Import-LocalizedData -BindingVariable IntmsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization\$culture\Modules"

Export-ModuleMember -Function *
