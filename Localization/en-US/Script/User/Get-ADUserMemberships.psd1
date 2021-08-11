ConvertFrom-StringData @'
ErrID = does not exist
ErrWID = Cannot find any user with ID
MQ1 = The user
MQ2 = has the following authorization groups in AD
MQ3 = These are the folder permissions you want us to assign to
MQ4 = The folder names are after 'Grp' and before 'User'
MQ5 = The letter at the end indicates the type of permission in question, where 'C' is the writing right and 'R' is the reading right.
MQ6 = Do you want us to assign these permissions to the user?
QID = Enter user (ID)
QQID = Enter the ID of the recipient of the permission-cloning
QQuestion = Copy the AD groups, with a question to HR, to the clipboard
WGroupCont = As well as membership in the following HR-synchronized organizational groups and subgroups
WGroupNoCont = No membership in HR-synchronized organizational groups
WGroupTitle = have permissions to the following groups in AD
WNoGroups = does not have any permission to any groups in AD
WQCopy = The message has been copied to the clipboard
WSummaryFile = Results written to file
'@
