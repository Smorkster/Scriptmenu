ConvertFrom-StringData @'
ErrLogUserNotFound = does not exist in AD
LogSummary = See the respective output file for a summary
LogUserFile = User
QOutputFile = How should the information be exported? As a single file, enter 1, or as individual files, enter 2
StrEnd = The entire script is now complete and all users have their own list written to the Output folder. You can use the Output-tab in the Scriptmenu to open the files.
StrNotepad = Notepad opens, enter users
StrNotepadTitle = Enter user ID, one per line
StrOpenFiles = Do you want to open all the files now? ( Y\\N )
StrOpTitle = Retrieves all groups for
StrOutInfo1 = There may be some errors in the lists below. '_' can be spaces in the actual path.
StrOutInfo2 = The folder names specified for permissions but for G, R and S may be incorrect, or may not exist.
StrOutInfo3 = Some shares may be old and no longer even exist etc.
StrOutPath = A list of permissions has now been saved in the following file
StrOutTitle = has the following permissions, per permissions type
StrOutTitleChange = Change-permission
StrOutTitleFull = Full-permission
StrOutTitleRead = Läs-permission
StrOutTitleUnknown = Unknown permission
StrTitle = This script retrieves and sorts all permission groups for one or more users. All file permissions are then exported to one TXT file per user.
StrUserNotFound = Did not find a user with id:
'@
