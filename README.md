# Scriptmenu
A GUI for finding and running Powershell-scripts. The currently available scripts are used by IT-Servicedesk and are thus developed for that purpose.
To adjust for your organisation you will have to adjust the scripts for any specific details.
It is suggested that new scripts are first placed in the *Developement*-folder so it first can be fully tested. When ready, use the Update-Scripts-script to copy updated and new scripts to production.

The main script (SDGUI.ps1) searches for scripts in subdirectories, and creates tabcontrol-tabs for each folder and lists scripts for each folder.
The scripts can take advantage of available modules and thus get more out of the folder structure.

## Development area
The *Development*-folder is used as an area to create new scripts, apply changes or test new functionality. When the development is done, the script `Update-Scripts.ps1` is used to copy scripts to "production", i.e. the *Script*-folder.

## Scripts
Scripts are placed in any appropriate subfolder of the *Script*-folder.
If a script uses WPF for GUI-purposes, an XAML-file with the same name as the script, is placed in the *GUI*-folder to take advantage of module-functionality.
New files must follow these rules:
* Fileextension .ps1
* No spaces in filename
* The script must contain these lines, at the beginning:
  <#
		.Synopsis - A short description of what script does [Necessary]
		.Description - A longer, more detailed description of the script. This will be shown as a tooltip for controls for the script [Necessary]
		.Requires - A list of AD-groups the user must be member of. If the user is not a member, this script will not be available. If this is not specified, the script will be available for all users. Groupnames are separated by commas (',')
		.AllowedUsers - List of users allowed to run the script. This can be used if the user/-s are not member of required AD-group, or if only specific users should be able to use the script. Usernames are separated by commas (',')
		.Author - Who has created the script, i.e. who is responsible
		#>
	* To be able to use logging, availabe functions for handling files or other common uses, there are modules available. These are imported with:
    `Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force`

When scripts are started from the GUI, it is initiated with an argument for the root-folder (i.e. *Scriptmenu*-folder). This argument is contained in `$args[0]`.
Any scripts in the *Computer*-folder will also get computername entered in the textbox in the Computer-tab. The computername is contained in `$args[1]`.

### Subfolders for scripts
All folders in the *Script*-folder, will get a tab in the tabcontrol. If a folder contains any subfolder, that in turn will give another tabcontrol, within that tab and also contain tabs for each folder.
Foldernames must not contain any space. If a foldername should have more than one name, each word should be capitalized. SDGUI will then add a space between the words to then be shown in the tabitem-header.

### *Computer*-folder
Script directly in the *Computer*-folder is visible by default.
Any script in a subfolder is hidden by default and will be made visible if the computer entered in textbox, is online and reachable. These are shown after a check made from the "Fetch info"-button.

## Pictures
Pictures are placed in the *Pictures*-folder

## Other applications
Applications to be used by scripts are placed in the *Apps*-folder

## Localization
The FileOps module (see below) has functionality for embedding localization in scripts. Localization means that scripts can have text strings depending on the language installed in the operating system. That is, if the language in the operatingsystem is Swedish, "sv-SE" will be culture to import.
A localization file MUST have the same name as the script file and have the file extension ".psd1". If the file name differs, the file will not be loaded.

Scripts that use localization MUST have its localization-file placed as follows:
  * In the "Localization" folder
  * Folder with the name of the selected culture. The default for SDGUI is "sv-SE". If another culture is used for the strings, the culture name needs to be specified in the ArgumentList when importing the FileOps module, like so:
    `Import-Module "$( $args [0] )\Modules\<Module-name>.psm1" -Force -ArgumentList "sv-SE"`
  * Folder structure according to the location of the script file.

Example:
If the script file "Test.ps1" is located in Script\Computer, there should be a file located according to:
  `Localization\sv-SE\Computer\Test.psd1`

The file **MUST** start with:
`ConvertFrom-StringData @ '`
and the last line **MUST** be (with no space at the beginning):
`'@`
Each line in between is formulated according to:
VariableName = Text to use

Imported text is accessed through the hashtable `$msgTable` and is used as follows:
`$msgTable.VariableName`

## Additional modules
Any new module for this suite are placed in the *Modules*-folder. They are then imported in the same way as mentioned above:
`Import-Module "$( $args[0] )\Modules\<Module name>.psm1" -Force`

## Available modules
There are some modules available for scripts to handle logging, get input from user, create WPF-windows and more. To be able to use these, put this code in the beginning of the script. One for each module to import.
`Import-Module "$( $args[0] )\Modules\< Modul-namn >.psm1" -Force`

### Module ConsoleOps
A module for adding functions for operating in the console.

#### Function *GetConsolePasteInput*
Reads input from the console window pasted with Ctrl + V.

##### Parameter
  * Folders - If input will be list of folders.

##### Returns
Input as an array

#### Function *StartWait*
Starts a wait process and shows a progressbar for set time.

##### Parameters
  * SecondsToWait - Number of seconds to wait
  * MessageText - Text to be displayed in progressbar. This text is always preceded by "Please wait in $SecondsToWait seconds ", note the space after "seconds".

##### Example
StartWait -SecondsToWait 3 -MessageText "until everything is ready"

### Module FileOps
This module is the most used, since it contains functions for handling files for input/output/log.

#### Function *WriteLog*
Writes to logfile for operations in scripts. It writes to a file with path based on year, month and with the same name as the script that is calling.
Each line is preceded with default logdata *"2020-08-01 00:00 Admin1 [Domain] => "* followed by logtext from script.

#### Parameters
  * LogText [string] - Text to be written to log

###### Examples
Function call: `WriteLog -LogText "Comp1 1.8"`
Written text: *2020-08-01 12:34 Admin1 [Domain] => Comp1 1.8*
Filename: *Log\2020\08\Get-InstalledJava - log.txt*

#### Function *GetUserInput*
Creates a file in the *Input*-folder to which the user can enter data for the script. The file will have a default text at the top, defined by the calling script. When the function is called, Notepad will be opened, and the script will continue when Notepad is closed. Function then returns the filecontent, with the defined default text excluded.

The inputfile is created, if it does not exist, in a folder with the users name in the *Input*-folder. If a file with that name exists, its content will be replaced.

###### Parameters
  * DefaultText [string] - The text to be used in input file.

###### Returns
The text entered in the textfile, with "default text" excluded.

###### Examples
Function call: `GetUserInput -DefaultText "List usernames"`
Filename: *Input\Admin1\Get-Users.txt*

#### Function *WriteOutput*
Writes outputtext from script. Usable for when writing output that gets to long for a consolewindow, the output is to long for logfile or if output is to be saved for tracing backlog.

###### Parameters
  * Output [string] - Text to be written in output-file.
  * FileNameAddition [string] - Other text to be entered in the outputfile filename. Default is empty
	* FileExtension [string] - Fileextention to be used for the outputfile. Default is *txt*.
	* Scoreboard [switch] - If output is a scoreboard/toplist. Used for skripts in the *Scoreboard*-folder. Outputfile will then be created in *Output\Scoreboard*

###### Returns
Full filepath for the outputfile

###### Examples
Function call: `WriteOutput -Output "List usernames"`
Filename: *Output\Admin1\Get-InstalledJava 2020-08-01 12.34.56.txt*

Function call: `WriteOutput -Output "Users with ..." -FileNameAddition "Java users"`
Filename: *Output\Admin1\Java users Get-InstalledJava 2020-08-01 12.34.56.txt*

Function call: `WriteOutput -Output "Users with ..." -FileExtension "csv"`
Filename: *Output\Admin1\Get-InstalledJava 2020-08-01 12.34.56.csv*

Function call: `WriteOutput -Output $topList -Scoreboard -FileExtension "csv"`
Filename: Output\Scoreboard\Get-InstalledJava 2020-08-01 12.34.56.csv*

#### Function *ShowMessageBox*
Shows a messagebox

##### Parameters
  * Text [string] - Text to be shown in messagebox.
  * Title [string] - Text to be the title of the messagebox. Default is ""
  * Button [string] - Button/buttons to be used. Default is "OK". See https://docs.microsoft.com/en-us/dotnet/api/system.windows.messageboxbutton
  * Icon [string] - Which icon should be shown. Default is "Info". See https://docs.microsoft.com/en-us/dotnet/api/system.windows.messageboximage

##### Returns
Which button in the messagebox that was clicked.

###### Examples
Function call: `ShowMessageBox -Text "Message" -Title "Messagetitle" -Button "Cancel" -Icon "Stop"`

#### Function *EndScript*
Writes to scriptconsole that the script is finished and the consolewindow can be closed.

##### Examples
Function call: `EndScript`

#### Function *WriteErrorlog*
Writes errors to an errorlog. The filename will be formated with year, month, scriptname and date.

##### Parameters
  * LogText - Errormessage to be written.

##### Returns
Filepath to errorlog-file.

##### Examples
Function call: `WriteErrorLog`
Filename: *ErrorLogs\2020\08\Get-InstalledJava - Errorlog 20200801123456.txt*

### Module GUIOps

#### Function *CreateWindow*
Creates a WPF-window based on the XAML-file located in the *GUI*-folder, which have the same name as the calling script.

##### Returns
The object representing the window and an array containing all named controls created in the window.

##### Examples
Function call: `$Window, $vars = CreateWindow`
To get the controls, this will create a variable for each control with the same as the control: `$vars | foreach { Set-Variable -Name $_ -Value $Window.FindName( $_ ) }`

#### Function CreateWindowExt
Reads and loads XAML-file with the same name as the script calling, located in the *GUI*-folder. It creates a synchronized hashtable that contains an object for the window, a variable for each named control according to the XAML file, and has created binding for specified properties of the controls.

##### Parameters
  * ControlsToBind - An ArrayList with hashtables for each control to have bindings. In each hashtable, an array of hashtables is placed for each parameter, with parameter name and default value. This must be formulated as follows:
```powershell
$var = New-Object Collections.ArrayList
[void] $var.Add( @{ CName = "MyProgressBar"
  Props = @(
    @{ PropName = "Value"; PropVal = [double] 50 }
    @{ PropName = "IsIndeterminate"; PropVal = $false }
  )})
```

  * *CName* - Name of the control according to the XAML file
  * *PropName* - Name of property according to .Net. This must exist like [System.Windows.Control.ProgressBar]::ValueProperty
  * PropVal - Default value for the control. This value will also be the initial value of the control when the GUI starts. That is, in the example above, progressbar will appear as halv filled.

##### Returns
The function returns a synchronized hashtable to use for all controls and any data. The table consists of:
  * *Data* - A hashtable that can be used to save data in various variables
  * *DC* - A hashtable containing all bindings to controller parameters. This list is created from the array that was initially sent to the function (see Parameter)
  * *Output* - A text string that can be used to collect text for output from the script
  * *Vars* - An array with the names of all named controls
  * All controls are also directly available in the hash table. These are accessed by:
    * $ hashtabell.TextRuta

##### Example
`$syncHash = CreateWindowExt $var`

### Module RemoteOps
Used for functions that works on remote computers

#### Function *RunCycle*
Starts a job that checks for systemupdates after 10 minutes on remote computer.

##### Parameters
  * ComputerName - Name of computer to work on
  * CycleName - Name of the job to start

##### Examples
Function call: `RunCycle -ComputerName Comp1 -CycleName "Updatecheck"`

#### Function SendToast
Send a Toast-message to remote computer

##### Parameters
  * Message - Message to send, maxlength is 150 characters
  * ComputerName - Computername for the receiving device

##### Returnerar
Value for if the message was sent:
  * 0 - Meddelandet skickades
	* 1 - Datornamn finns inte registrerat eller datorn kan inte nås
	* 2 - Meddelandet kunde inte skickas, problem att ansluta
	* 3 - Meddelandet kunde inte skickas, dator har inte Windows 10

##### Exemples
`SendToast -Message "Meddelande test" -ComputerName TestComp`

### Module SysManOps
Contains functions for working against SysMan.

#### Function *ChangeInstallation*
Changes version of deployed application for the computer

###### Parameters
  * ComputerName [string] - Name of computer
  * OldVersion [string] - AD-groupname of installationgroup for the old (currently installed) version
  * NewVersion [string] - AD-groupname of installationgroup for the new (to be installed) version

###### Examples
Function call: `ChangeOfficeInstallation -ComputerName Comp1 -OldVersion Office1 -NewVersion Office2`

#### Function *GetSysManComputerId*
Gets the internal id for specified computer in SysMan

##### Parameter
  * ComputerName - Computer to get the id for

#### Returns
Id in SysMan for the computerobject

##### Example
Function call: `GetSysManComputerId -ComputerName Comp1`

#### Function *GetSysManUserId*
Get the internal id for specified user in SysMan

##### Parameter
  * Id - UserId of the user to get the id for

##### Returns
Id in SysMan for the userobject

##### Example
Function call: `GetSysManUserId -Id ABCD`
