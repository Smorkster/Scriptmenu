# Scriptmenu
A GUI for finding and running Powershell-scripts. The currently available scripts are used by IT-Servicedesk and are thus developed for that purpose.
To adjust for your organisation you will have to adjust the scripts for any specific details.
It is suggested that new scripts are first placed in the *Developement*-folder so it first can be fully tested. When ready, use the Update-Scripts-script to copy updated and new scripts to production.

The main script (SDGUI.ps1) searches for scripts in subdirectories, and creates tabcontrol-tabs for each folder and lists scripts for each folder.
The scripts can take advantage of available modules and thus get more out of the folder structure.

<br>

## Development area
The *Development*-folder is used as an area to create new scripts, apply changes or test new functionality. When the development is done, the script `Update-Scripts.ps1` is used to copy scripts to "production", i.e. the *Script*-folder.

<br>

## Scripts
Scripts are placed in any appropriate subfolder of the *Script*-folder.

If a script uses WPF for GUI-purposes, an XAML-file with the same name as the script, is placed in the *GUI*-folder to take advantage of module-functionality.

When the scriptmenu starts, it searches for scripts in the *Script*-folder and reads the comment based help-section at the begining of the file. Parameters in the section are used to create the controls in the scriptmenu. If this is not present, the scripts will not be listed properly and might not be able to run from the GUI.

Scripts must follow these rules:
* Fileextension .ps1
* No spaces in filename
* The filename should start with an approved verb, i.e. "Get-". This is used to group scripts in the GUI
* The script must have a comment based help-section at the begining of the file. The following parameter are mandatory:
```powershell
<#
.Synopsis - A short description of what script does. This is shown in by the button to start the script
.Description - A longer, more detailed description of the script. This will be shown as a tooltip for controls for the script
.State - Define production phase of the script. There are three options for this:
* Dev - The script is in development, only those listed in the admin list, as well as the script creator (see 'Author') can start the script
* Test - The script is highlighted in the maingui to be in the testing phase
* Prod - The script is in production and is not highlighted in the maingui. This also happens if State is omitted
.Author - Who has created the script, i.e. who is responsible. This user will always have access to the script, even if not member of any of the AD-groups specified in "Requires" or listed in "AllowedUsers" (see below)
#>
```
Alternate script parameters:
* **.Requires** - List of AD groups that must have been assigned to the user. If not specified, the script will be available to everyone. Group names are separated by commas (',')
* **.AllowedUsers** - List of users allowed to run the script. Users do not have to be a member of the AD group according to Requires. Usernames are separated by commas (',')
* **.Depends** - Technology that can be controlled by the scriptmenu. For a list of controlled technologies, see section "Dependencies"

To be able to use any of the modules created for the scriptmenu, such as logging, file management or GUI (see section "Available modules"), these are imported as follows:

    Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

<br>

### Scriptstart
When scripts are started, a list of arguments is always sent as an argumentlist. These arguments are available by the automatic variable **$args** at the beginning of the script.

The list contains the following:
* **$args[0]** - The path for the "base folder", i.e. G:\Scriptmenu. This is used to more easily access files in the other folders, such as modules or folders
* **$args[1]** - IetfLanguageTag for the language to be used when locating scripts. The default is sv-SE. For more info, see section Localization
* **$args[2]** - Scripts located in the "**Script\Computer**"-folder always get the computer name specified in GUI by the user. This is not given to scripts in other top folders

<br>

### Subfolders for scripts
All folders in the *Script*-folder, will get a tab in the tabcontrol. If a folder contains any subfolder, that in turn will give another tabcontrol, within that tab and also contain tabs for each folder.
Foldernames must not contain any space. If a foldername should have more than one name, each word should be capitalized. SDGUI will then add a space between the words to then be shown in the tabitem-header.

<br>

### Special folders
#### *Computer*-folder
Script directly in the *Computer*-folder is visible by default.
Any script in a subfolder is hidden by default and will be made visible if the computer entered in textbox, is online and reachable. These are shown after a check made from the "Fetch info"-button.

<br>

#### *O365*-folder
Script directly in the *O365*-folder is visible by default.
Scripts located in any subfolder are made visible after connecting to Office365 online services. These scripts can only use the connection if they are not started in a separate PowerShell window. Therefore, they will be started through Invoke-Command and therefore need to manage visibility themselves or use GUI windows.

<br>

## Pictures
Pictures are placed in the *Pictures*-folder

<br>

## Dependencies
A script can use technology that is not guaranteed to be available at startup, e.g. WinRM to work with remote computer. This can be specified in the help section at the beginning of the script. SDGUI checks if the technology is available and will then make the button to start the script, available or not. To create this dependency, enter ".Depends <technology>" in the help section. Only one technology per script can be used.

The following techniques can be checked at the moment:
* WinRM - Used for remote management of remote computer, e.g. Get-Process or Invoke-Command

<br>

## Other applications
Applications to be used by scripts are placed in the *Apps*-folder

<br>

## Localization
The FileOps-module (see below) has functionality for embedding localization in scripts. Localization means that scripts can have text strings depending on the language specified for the scriptmenu (in SDGUI.ps1). That is, if the language should be swedish, culture will be set as "sv-SE". To see available cultures, run this code:

    [System.Globalization.CultureInfo]::GetCultures( "AllCultures" )

A localization file MUST have the same name as the script file and have the file extension ".psd1". If the filename differs, the locale will not be loaded and no textstrings will be available for the script.

Scripts that use localization MUST have its localization-file placed as follows:
  * In the "Localization" folder
  * Folder with the name of the selected culture. The default for GUI is "sv-SE". If another culture is used for the strings, the culture name needs to be specified in the ArgumentList when importing the FileOps module, like so:

      `Import-Module "$( $args [0] )\Modules\<Module-name>.psm1" -Force -ArgumentList "sv-SE"`

  * Folder structure like that of the script file.

Example:
If the script file "Test.ps1" is located in Script\Computer, and uses swedish for the textstring, the file is located at:

`Localization\sv-SE\Script\Computer\Test.psd1`

The filecontent **MUST** start with:

    ConvertFrom-StringData @ '

and the last line **MUST** be (with no space at the beginning):

    '@

Each line in between is formulated according to:

    VariableName = Text to use

Imported text is accessed through the hashtable `$msgTable` and is used as follows:

    $msgTable.<VariableName>

<br>

## Additional modules
Modules for this suite are placed in the *Modules*-folder. They are then imported in the same way as mentioned above:

    Import-Module "$( $args[0] )\Modules\<Module name>.psm1" -Force -ArgumentList $args[1]

<br>

## Available modules
There are some modules available for scripts to handle logging, get input from user, create WPF-windows and more. To be able to use these, put this code in the beginning of the script; one for each module to import:

    Import-Module "$( $args[0] )\Modules\< Modul-namn >.psm1" -Force

<br>

### Module ConsoleOps
Is imported with:

    Import-Module "$( $args[0] )\Modules\ConsolOps.psm1" -Force -ArgumentList $args[1]

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

<br>

### Module FileOps
Is imported with:

    Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

This module is the one most used, since it contains functions for handling files for input/output/log.
The module also loads any localization file created for scripts. If there is a psd1-file with the same name and under the same folder structure as the calling script, the module will load the file and export the data in a hashtable named $msgTable. From this, scripts can retrieve the text strings.

#### Function *WriteLog* **[Deprecated]**
Writes to logfile for operations in scripts. It writes to a file with path based on year, month and with the same name as the script that is calling.
Each line is preceded with default logdata *"2020-08-01 00:00 Admin1 [Domain] => "* followed by logtext from script.

##### Parameters
  * LogText [string] - Text to be written to log

##### Examples
Function call: `WriteLog -LogText "Comp1 1.8"`<br>
Written text: *2020-08-01 12:34 Admin1 [Domain] => Comp1 1.8*
Returns filepath: *G:\Scriptmenu\Log\2020\08\Get-InstalledJava - log.txt*

#### Function *WriteLogTest*
Writes to log file for the calling script. This must always be used script, to enable seeing how scripts are used. The logging is supplemented by the module with date, time and username and is formatted into a Json-string.

##### Parameters
  * Text [**string**] [**Required**] - Text that describes what is done in the script
  * UserInput [**string**] [**Required**] - What are the procedures for running the script
  * Success [**bool**] [**Required**] - Indicate if the operation was successful or not
  * ErrorLogHash [**hashtable**] - The hashtable returned from *WriteErrorlogTest*. This contains the path for the error log and the logging time for the error log
  * OutputPath [**string**] - Path of output file written at runtime

##### Returns
File path

##### Examples
Function call: `WriteLogTest -Text "Changed user account" -UserInput "ABCD" -Success $ true`<br>
Returns filepath: *G:\ScriptMenu\Logs\2021\01\ScriptName - log.txt*

Function call: `WriteLogTest -Text "Changed user account" -UserInput "ABCD" -Success $false -ErrorLogHash $hash`<br>
Returns filepath: *G:\Scriptmenu\Logs\2021\01\ScriptName - log.txt*

Function call: `WriteLogTest -Text "Modified user account" -UserInput "ABCD" -Success $false -OutputPath`<br>
Returns filepath: *G:\Scriptmenu\Logs\2021\01\ScriptName - log.txt*

#### Function *GetUserInput*
Creates a file in the *Input*-folder to which the user can enter data for the script. The file will have a default text at the top, defined by the calling script. When the function is called, Notepad will be opened, and the script will continue when Notepad is closed. Function then returns the filecontent, with the defined default text excluded.

The inputfile is created, if it does not exist, in a folder with the users name in the *Input*-folder. If a file with that name exists, its content will be replaced.

##### Parameters
  * DefaultText [string] - The text to be used in input file.

##### Returns
The text entered in the textfile, with "default text" excluded.

##### Examples
Function call: `GetUserInput -DefaultText "List usernames"`<br>
Filepath for input: *G:\Scriptmenu\Input\Admin1\Get-Users.txt*<br>
Returns: "ABCD"

#### Function *WriteOutput*
Writes outputtext from script. Usable for when writing output that gets to long for a consolewindow, the output is to long for logfile or if output is to be saved for tracing backlog.

##### Parameters
  * Output [string] - Text to be written in output-file.
  * FileNameAddition [string] - Other text to be entered in the outputfile filename. Default is empty
	* FileExtension [string] - Fileextention to be used for the outputfile. Default is *txt*.
	* Scoreboard [switch] - If output is a scoreboard/toplist. Used for skripts in the *Scoreboard*-folder. Outputfile will then be created in *Output\Scoreboard*

##### Returns
Full filepath for the outputfile

##### Examples
Function call: `WriteOutput -Output "List usernames"`<br>
Returns filepath: *G:\Scriptmenu\Output\Admin1\Get-InstalledJava 2020-08-01 12.34.56.txt*

Function call: `WriteOutput -Output "Users with ..." -FileNameAddition "Java users"`<br>
Return filepath: *G:\Scriptmenu\Output\Admin1\Java users Get-InstalledJava 2020-08-01 12.34.56.txt*

Function call: `WriteOutput -Output "Users with ..." -FileExtension "csv"`<br>
Returns filepath: *G:\Scriptmenu\Output\Admin1\Get-InstalledJava 2020-08-01 12.34.56.csv*

Function call: `WriteOutput -Output $topList -Scoreboard -FileExtension "csv"`<br>
Returns filepath: *G:\Scriptmenu\Output\Scoreboard\Get-InstalledJava 2020-08-01 12.34.56.csv*


#### Function *ShowMessageBox*
Shows a messagebox

##### Parameters
  * Text [string] - Text to be shown in messagebox.
  * Title [string] - Text to be the title of the messagebox. Default is ""
  * Button [string] - Button/buttons to be used. Default is "OK". See https://docs.microsoft.com/en-us/dotnet/api/system.windows.messageboxbutton
  * Icon [string] - Which icon should be shown. Default is "Info". See https://docs.microsoft.com/en-us/dotnet/api/system.windows.messageboximage

##### Returns
Which button in the messagebox that was clicked.

##### Examples
Function call: `ShowMessageBox -Text "Message" -Title "Messagetitle" -Button "OKCancel" -Icon "Stop"`
Returns: OK

#### Function *EndScript*
Writes to scriptconsole that the script is finished and the consolewindow can be closed.

##### Examples
Function call: `EndScript`

#### Function *WriteErrorlog* [**Deprecated**]
Writes errors to an errorlog. The filename will be formated with year, month, scriptname and date.

##### Parameters
  * LogText - Errormessage to be written.

##### Returns
Filepath to errorlog-file.

##### Examples
Function call: `WriteErrorLog -LogText "Error"`<br>
Filename: *G:\Scriptmenu\ErrorLogs\2020\08\Get-InstalledJava - Errorlog 20200801123456.txt*

#### Function *WriteErrorLogTest*
Writes to the error log file for the calling script. This should be used as much as possible in scripts to enable reading and correct any errors or handle errors correctly. The logging is supplemented by the module with date, time and username and formatted into a Json string.

##### Parameters
  * LogText [**string**] [**Required**] - Error message or custom error text from the calling script
  * UserInput [**string**] [**Required**] - Specified by the user when executing the script
  * Severity [**string**] [**Required**] - Category of error that have occurred. This can be any of the following:
    * UserInputFail - Error occurred due to what the administrator specified
    * ScriptLogicFail - Error occurred due to error in the code in the script
    * ConnectionFail - Connection to another computer or server failed
    * PermissionFail - The administrator does not have the right authorization
    * OtherFail - Other, undefined error

##### Returns
File path of the errorlog

##### Example
Function call: `WriteErrorlogTest -LogText "User Account Error" -UserInput "ABCD" -Severity "ScriptLogicFail"`<br>
Returns filepath: *G:\Scriptmenu\ErrorLogs\2021\01\ScriptName - ErrorLog.txt"

<br>

### Module GUIOps
Is imported with:

    Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force -ArgumentList $args[1]

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
  ) } )
```

  * *CName* - Name of the control according to the XAML file
  * *PropName* - Name of property according to .Net. This must exist like
  `[System.Windows.Control.ProgressBar]::ValueProperty`
  * PropVal - Default value for the control. This value will also be the initial value of the control when the GUI starts. That is, in the example above, progressbar will appear as halv filled.

##### Returns
The function returns a synchronized hashtable to use for all controls and any data. The table consists of:
  * *Data* - A hashtable that can be used to save data in various variables
  * *DC* - A hashtable containing all bindings to controller parameters. This list is created from the array that was initially sent to the function (see Parameter)
  * *Output* - A text string that can be used to collect text for output from the script
  * *Vars* - An array with the names of all named controls
  * All controls are also directly available in the hash table. These are accessed by:
    * $ hashtabell.TextBox

##### Example
`$syncHash = CreateWindowExt $var`

<br>

### Module RemoteOps
Is imported with:

    Import-Module "$( $args[0] )\Modules\RemoteOps.psm1" -Force -ArgumentList $args[1]

Used for functions that works on remote computers

#### Function *RunCycle*
Starts a job that checks for systemupdates after 10 minutes on remote computer.

##### Parameters
  * ComputerName - Name of computer to work on
  * CycleName - Name of the job to start

##### Examples
Function call: `RunCycle -ComputerName Comp1 -CycleName "Updatecheck"`

#### Function *SendToast*
Send a Toast-message to remote computer

##### Parameters
  * Message - Message to send, maxlength is 150 characters
  * ComputerName - Computername for the receiving device

##### Returns
Value for if the message was sent:
  * 0 - Message sent
	* 1 - Computername is not registered or the computer can not be reached
	* 2 - Message could not be sent, error when connecting
	* 3 - Message could not be sent, the computer does not have Windows 10

##### Exemples
`SendToast -Message "Message test" -ComputerName TestComp`

<br>

### Module SysManOps
Is imported with:

    Import-Module "$( $args[0] )\Modules\SysManOps.psm1" -Force -ArgumentList $args[1]

Contains functions for working against SysMan.

#### Function *ChangeInstallation*
Changes version of deployed application for the computer

##### Parameters
  * ComputerName [string] - Name of computer
  * OldVersion [string] - AD-groupname of installationgroup for the old (currently installed) version
  * NewVersion [string] - AD-groupname of installationgroup for the new (to be installed) version

##### Examples
Function call: `ChangeOfficeInstallation -ComputerName Comp1 -OldVersion Office1 -NewVersion Office2`

#### Function *GetSysManComputerId*
Gets the internal id for specified computer in SysMan

##### Parameter
  * ComputerName - Computer to get the id for

##### Returns
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
