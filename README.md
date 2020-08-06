# Scriptmenu
A gui for finding and running Powershell-scripts. The gui and available scripts are used by IT-Servicedesk and are thus developed for that purpose.
To adjust for your organisation you will have to adjust the scripts for any specific details.

The main script (SDGUI.ps1) searches for scripts in subdirectories, and creates tabcontrol-tabs for each folder and lists scripts for each folder.
The scripts can take advantage of available modules and thus get more out of the folder structure.

## Development area
The *Development*-folder is used as an area to create new scripts, apply changes or test new functionality. When the development is done, the script **Update-Scripts.ps1** is used to copy scripts to "production", i.e. the *Script*-folder.

## Scripts
Scripts are placed in any appropriate subfolder of the *Script*-folder.
If a script uses WPF for its gui, the XAML-file should have the same name as the script and placed in the *GUI*-folder to take advantage of module-functionality.
New files must follow these rules:
* No spaces in filename
* The script must contain these lines, tentatively at the beginning:
  * #Description = "Short description of what the script does"
  * **Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force**

The description is used when listing scripts.
The import gets the module from module folder.

When scripts are started from the gui, it is initiated with an argument for the root-folder (i.e. *Scriptmenu*-folder). This argument is contained in **$args[0]**.
Any scripts in the *Computer*-folder will also get computername entered in the textbox in the Computer-tab. The computername is contained in **$args[1]**.

### Subfolders for scripts
All folders in the *Script*-folder, will get a tab in the tabcontrol. If a folder contains any subfolder, that in turn will also give another tabcontrol, within that tab and also contain tabs for each folder.
Foldernames must not contain any space.

### *Computer*-folder
Script in the *Computer*-folder is visible from start.
Any script in a subfolder is hidden from start and will be made visible if the computer entered in textbox, is online and reachable. This after check made from the "Fetch info"-button.

## Pictures
Pictures are placed in the *Pictures*-folder

## Other applications
Applications to be used by scripts are placed in the *Apps*-folder

## Additional modules
Any new module for this suite are placed in the *Modules*-folder. They are then imported in the same way as mentioned above:
**Import-Module "$( $args[0] )\Modules\<Module name>.psm1" -Force**

## Available modules
### FileOps
This module is the most used, since it contains functions for handling files for input/output/log.

#### Function *WriteLog*
Writes to logfile for operations in scripts. It writes to a file with path based on year, month and with the same name as the script that is calling.

Each line is preceded with default logdata *"2020-08-01 00:00 Admin1 [Domain] => "* followed by logtext from script.

###### Parameters
  * LogText [string] - Text to be written to log

###### Examples
Function call: **WriteLog -LogText "Comp1 1.8"**
Written text: *2020-08-01 12:34 Admin1 [Domain] => Comp1 1.8*
Filename: *Log\2020\08\Get-InstalledJava - log.txt*

#### Function *GetUserInput*
Creates a file in the *Input*-folder to which the user can enter data for the script. The file will have a default text at the top, defined by the calling script. When the function is called, Notepad will be opened, and will continue when Notepad is closed. Function then returns the filecontent, with the defined default text excluded.

The inputfile is created, if it does not exist, in a folder with the users name in the *Input*-folder. If a file with that name exists, its content will be replaced.

###### Parameters
  * DefaultText [string] - The text to be used in input file.

###### Returns
The text entered in the textfile, with "default text" excluded.

###### Examples
Function call: **GetUserInput -DefaultText "List usernames"**
Filename: *Input\Admin1\Get-Users.txt*

#### Function *GetConsolePasteInput*
Gets input in consolewindow that is entered through Ctrl+V.

###### Parameters
  * Folders [switch] - If the text entered will be list of foldernames.

###### Returns
The text entered in the console, input separated by specified split.

###### Examples
Function call: **GetConsolePasteInput**

#### Function *WriteOutput*
Writes outputtext from script. Usable for when writing output gets to much for a consolewindow, the output is to long for logfile or if output is to be saved for tracing backlog.

###### Parameters
  * Output [string] - Text to be written in output-file.
  * FileNameAddition [string] - Other text to be entered in the outputfile filename. Default is empty
	* FileExtension [string] - Fileextention to be used for the outputfile. Default is *txt*.
	* Scoreboard [switch] - If output is a scoreboard/toplist. Used for skripts in the *Scoreboard*-folder. Outputfile will then be created in *Output\Scoreboard*

###### Returns
Full filepath for the outputfile

###### Examples
Function call: **WriteOutput -Output "List usernames"**
Filename: *Output\Admin1\Get-InstalledJava 2020-08-01 12.34.56.txt*

Function call: **WriteOutput -Output "Users with ..." -FileNameAddition "Java users"**
Filename: *Output\Admin1\Java users Get-InstalledJava 2020-08-01 12.34.56.txt*

Function call: **WriteOutput -Output "Users with ..." -FileExtension "csv"**
Filename: *Output\Admin1\Get-InstalledJava 2020-08-01 12.34.56.csv*

Function call: **WriteOutput -Output $topList -Scoreboard -FileExtension "csv"**
Filename: Output\Scoreboard\Get-InstalledJava 2020-08-01 12.34.56.csv*

#### Function *ShowMessageBox*
Shows a messagebox

###### Returns
Which button in the messagebox that was pressed.

###### Parameters
  * Text [string] - Text to be shown in messagebox.
  * Title [string] - Text to be the title of the messagebox. Default is ""
  * Button [string] - Button/buttons to be used. Default is "OK". See https://docs.microsoft.com/en-us/dotnet/api/system.windows.messageboxbutton
  * Icon [string] - Which icon should be shown. Default is "Info". See https://docs.microsoft.com/en-us/dotnet/api/system.windows.messageboximage

###### Examples
Function call: **ShowMessageBox -Text "Message" -Title "Messagetitle" -Button "Cancel" -Icon "Stop"**

#### Function *EndScript*
Writes to scriptconsole that the script is finished and the consolewindow can be closed.

###### Examples
Function call: **EndScript**

#### Function *WriteErrorlog*
Writes errors to an errorlog. The filename will be formated with year, month, scriptname and date.

###### Parameters
  * LogText - Errormessage to be written.

###### Returns
Filepath to errorlog-file.

###### Examples
Function call: **WriteErrorLog**
Filename: *ErrorLogs\2020\08\Get-InstalledJava - Errorlog 20200801123456.txt*

#### Function *CreateWindow*
Creates a WPF-window based on the XAML-file located in the *GUI*-folder, which have the same name as the calling script.

###### Returns
The object representing the window and an array containing all named controls created in the window.

###### Examples
Function call: **$Window, $vars = CreateWindow**
To get the controls, this will create a variable for each control with the same as the control: **$vars | foreach { Set-Variable -Name $_ -Value $Window.FindName( $_ ) }**

### RemoteOps
Used for functions that works on remote computers

#### Function *RunCycle*
Starts a job that checks for systemupdates after 10 minutes on remote computer.

###### Parameters
  * ComputerName - Name of computer to work on
  * CycleName - Name of the job to start

###### Examples
Function call: **RunCycle -ComputerName Comp1 -CycleName "Updatecheck"**

### SysmanOps
Contains functions for working against SysMan.

#### Function *ChangeOfficeInstallation*
Changes version of Microsoft Office to be installed on computer

###### Parameters
  * ComputerName [string] - Name of computer to change Office for
  * OldVersion [string] - AD-groupname of installationgroup for the old (currently installed) version
  * NewVersion [string] - AD-groupname of installationgroup for the new (to be installed) version

###### Examples
Function call: **ChangeOfficeInstallation -ComputerName Comp1 -OldVersion Office1 -NewVersion Office2**
