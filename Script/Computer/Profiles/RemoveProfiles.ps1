#Description = Remove one or more profiles on remote computer

##########################
# Remove multiple profiles
function MultipleProfiles
{
	try
	{
		#Remotely access computer
		Invoke-Command -ErrorAction Stop -ComputerName $Script:ComputerName -ScriptBlock `
		{
			[void][runspacefactory]::CreateRunspacePool()
			$SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
			$RunspacePool = [runspacefactory]::CreateRunspacePool(
				1, #Min Runspaces
				10 #Max Runspaces
			)

			$FolderRunspace = [System.Management.Automation.PowerShell]::Create()
			$FolderRunspace.RunspacePool = $RunspacePool
			$RunspacePool.Open()

			#Creates a variable for holding the old folder, does not matter if it exists.
			$old = New-Item -Path 'C:\Users\Old' -ItemType Directory -Force -ErrorAction SilentlyContinue
			#Gets date for use as name in subfolder in old
			$day = "\$( Get-Date -format 'yyyy-MM-dd' )"
			#Removes old folder if older than 30 days
			if ( ( Get-Date ).AddDays( -30 ) -gt $old.CreationTime )
			{
				Remove-Item $old -Recurse
				$old = New-Item -Path 'C:\Users\Old' -ItemType Directory -Force -ErrorAction SilentlyContinue
				$tbOutputBox.Text += "'Old-folder'is older than 30 days, folder removed and recreated.`n"
			}
			#Converts the path of old to a string
			$old = Convert-Path $old
			#Adds the date to the old string for use in subfolder creation
			$old += $day
			#Creates the subfolder with name of current date, does not matter if it exists.
			New-Item -Path $old -ItemType Directory -Force | Out-Null
			$tbOutputBox.Text += "Date folder created.`n"
			$Currentuser = $env:USERNAME
			#Gets all folders except excluded folders, then moves them to the date subfolder in old.
			$Folders = Get-ChildItem -Path 'C:\Users\' -ErrorAction SilentlyContinue -Exclude $Currentuser, '*ADMINI~1*', '*Public*', '*Default*', '*Delat*', '*Old*'
			pushd 'HKLM:'
			$RegistryKeys = Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' -ErrorAction SilentlyContinue -Include 'S-1-5-21-*' -Recurse
			popd
			$Currentuser = 'C:\Users\'+$Currentuser
			$jobs = New-Object System.Collections.ArrayList
			foreach ( $Folder in $Folders )
			{
				$FolderRunspace = [System.Management.Automation.PowerShell]::Create()
				$FolderRunspace.RunspacePool = $RunspacePool
				[void]$FolderRunspace.AddScript(
				{
					param ( $Folder, $Old, $RegistryKeys, $Currentuser )
					try
					{
						Move-Item -Path $Folder -Destination $Old -ErrorAction Stop
						pushd 'HKLM:'
						foreach ( $RegistryKey in $RegistryKeys )
						{
							$KeyUser = ( Get-ItemProperty $RegistryKey ).ProfileImagePath
							if ( ( $KeyUser -ne $Currentuser ) -and ( $KeyUser -eq $Folder.FullName ) )
							{
								Remove-Item $RegistryKey -Recurse -ErrorAction Stop
							}
						}
						popd
					}
					catch {}
				} ).AddArgument( $Folder ).AddArgument( $Old ).AddArgument( $RegistryKeys ).AddArgument( $CurrentUser )
				$Handle = $FolderRunspace.BeginInvoke()
				$temp = '' | select FolderRunspace, Handle
				$temp.FolderRunspace = $FolderRunspace
				$temp.handle = $Handle
				$tbOutputBox.Text += "Folder $Folder moved to $Old and registrykey removed.`n"
				$tbOutputBox.Text += "Verify that folders have been moved, since locked profiles can't be removed.`n"
				[void]$jobs.Add($temp)
			}
			$jobs | foreach { do { Start-Sleep -m 1 } while ( !$_.handle.IsCompleted ); $_.FolderRunspace.Dispose() }
			$jobs.Clear()
		}
	}
	catch
	{
		$tbOutputBox.Text = "Errormessage: " + $_.Exception.Message
	}
}

#########################
# Remove a single profile
function SingleProfile
{
	$User = $tbID.Text
	try
	{
		# Remotely access computer
		Invoke-Command -ErrorAction Stop -ComputerName $Script:ComputerName -ArgumentList $User -ScriptBlock `
		{
			param ( $UserName )

			$old = New-Item -Path "C:\Users\Old" -ItemType Directory -Force -ErrorAction SilentlyContinue # Folder for profilebackup
			$day = "\$( Get-Date -Format 'yyyy-MM-dd' )"
			# Removes old folder if older than 30 days
			if ( ( Get-Date ).AddDays( -30 ) -gt $old.CreationTime )
			{
				Remove-Item $old -Recurse
				$old = New-Item -Path 'C:\Users\Old' -ItemType Directory -Force -ErrorAction SilentlyContinue
				$tbOutputBox.Text += "'Old folder' is older than 30 days. Folder removed and recreated.`n"
			}
			# Converts the path of old to a string
			$old = Convert-Path $old
			# Adds the date to the old string for use in subfolder creation
			$old += $day
			# Creates the subfolder with name of current date
			New-Item -Path $old -ItemType Directory -Force | Out-Null
			$tbOutputBox.Text += "Folder created with todays date.`n"

			# Variable for path to profiles in the registry
			$HKLMprofile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\"
			# Gets Keys/Profiles from the path in the registry
			$keys = Get-ChildItem $HKLMprofile -Name -Recurse
			# Adds the path to the users folder to the specified username
			$UserName = 'C:\Users\' + $UserName
			# Sets a counter incase the profile does not exist
			$Removed = $true
			foreach ( $key in $keys )
			{
				$key = Join-Path -Path $HKLMprofile -ChildPath $key # Gets the current path for current key
				$profileName = ( Get-ItemProperty $key ).ProfileImagePath # Gets the username from that key
				if ( $profileName -eq $UserName )
				{
					# Moves folder and deletes registry key if the current keys username matches the specified one.
					try {
						Move-Item -Path $profileName -Destination $old -ErrorAction Stop
						$tbOutputBox.Text += "Folder: $profileName moved to 'today' folder.`n"
						Remove-Item $key -Recurse -ErrorAction Stop
						$tbOutputBox.Text += "Registrykey matched profile. $profileName removed.`n"
					}
					catch {
						$tbOutputBox.Text += "Failed to remove profile, verify if userfolder is locked.`n"
					}
					# Breaks the loop and sets the counter to true since a profile was deleted
					$Removed = $false
					break
				}
			}

			if ( $Removed )
			{
				$tbOutputBox.Text += "Profile for $UserName have now been removed from remote computer.`n"
			}
			else 
			{
				$tbOutputBox.Text += "Profile for $UserName does not exist on remote computer.`n"
			}
		}
	}
	catch
	{
		$temp += "Errormessage: " + $_.Exception.Message
		return $temp
	}
}

########################################
# Log off all users from remote computer
function LogoffRemote
{
	$LogoffRunspace = [System.Management.Automation.PowerShell]::Create()
	[void]$LogoffRunspace.AddScript( {
		try 
		{
			$ErrorActionPreference = "Stop"
			Invoke-Command -ComputerName $ComputerName -ScriptBlock `
			{
				$quser = quser
				function RemoveSpace( [string]$text )
				{
					$private:array = $text.Split( " ", [StringSplitOptions]::RemoveEmptyEntries )
					[string]::Join(" ", $array) }
			
				$quser = quser
				foreach ( $sessionString in $quser )
				{
					$sessionString = RemoveSpace( $sessionString )
					$session = $sessionString.Split()
					if ( $session[1].Equals( "SESSIONSNAME" ) ) { continue }
					# Use [1] because if the user is disconnected there will be no session ID. 
					$result = logoff $session[1]
				}
			}
		}
		catch [System.Management.Automation.RemoteException]{}
	}).AddArgument( $Script:ComputerName )
	$Logoff = $LogoffRunspace.BeginInvoke()
	do { Start-sleep 1 } while ( !$Logoff.IsCompleted )
	$Logoff = $LogoffRunspace.EndInvoke( $Logoff )
	$LogoffRunspace.Dispose()

	$lblId.IsEnabled = $tbID.IsEnabled = $btnOne.IsEnabled = $btnAll.IsEnabled = $true
	$btnLogOutAll.IsEnabled = $false
}

########################### Scriptet start
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$Window, $vars = CreateWindow
$vars | foreach { Set-Variable -Name $_ -Value $Window.FindName( $_ ) }

$Script:GUIAddr = $args[0]
$Script:ComputerName = $args[1]
$Window.Title += "'$ComputerName'"

$tbID.Add_TextChanged( {
	if ( $this.Text.Length -eq 0 ) { $btnAll.Visibility = [System.Windows.Visibility]::Visible ; $btnOne.Visibility = [System.Windows.Visibility]::Collapsed}
	else { $btnOne.Visibility = [System.Windows.Visibility]::Visible ; $btnAll.Visibility = [System.Windows.Visibility]::Collapsed}
	if ( $this.Text.Length -gt 3 ) { $btnOne.IsEnabled = $false } else { $btnOne.IsEnabled = $true }
} )
$btnOne.Add_Click( { SingleProfile } )
$btnAll.Add_Click( { MultipleProfiles } )
$btnLogOutAll.Add_Click( { LogoffRemote } )
$Window.Add_ContentRendered( { $Window.Top = 80; $Window.Activate() } )

[void] $Window.ShowDialog()
$Window.Close()
