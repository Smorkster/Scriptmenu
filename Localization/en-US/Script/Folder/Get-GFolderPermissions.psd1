ConvertFrom-StringData @'
CodeGP = @{ "Org1" = "Org1_Fil_Grp_" ; "Org2" = "Org2_Fil_Grp_" ; "Org3" = "Org3_Fil_Grp_" }
CodeOrgGrpMembers = switch ( $OrgGroup ) { "Org1_Users" { $OrgGroupMembers = "All users withing Org1" }; "Org2_Users" { $OrgGroupMembers = "All users within Org2" } ; "Org3_Users" { $OrgGroupMembers = "All users within Org3" } }
CodeOrgGrpMembersOutput = "The HR-synced group $OrgGroup (Department with id $OrgGroupID and its subgroups), containing the following person(s):"
CodeOrgList = Org1, Org2, Org3
LogFolders = Folders:
LogOpenSum = Open output file:
LogOrg = Org:
QCustomer = Enter org group ( Org1, Org2, Org3 )
QFolders = Paste a list of the folders you want the permissions on. The entire path, or just the folder name, one per line. Then press ENTER twice.
QOpenSum = Do you want to open the file?
StrAdIdPrefix = aidentity
StrAdIdPropPrefix = aidentity
StrGrpNameSuffixRead = _User_R
StrGrpNameSuffixWrite = _User_C
StrNoRead = <No read permissions>
StrNotFound = not found! Check the folder name and run the script again.
StrNoWrite = <No write permissions>
StrOutNotFoundTitle = The following folders were not found, and will not be reported:
StrOutSum = Results written to
StrOutTitle = Lists the permissions for the following folders under G:\
StrOwner = Owner:
StrOwnerMissing = Owner not assigned
StrReadPerm = Read permission:
StrSearching = Retrieves information and writes to file
StrSum = Summary
StrWritePerm = Write permission:
'@
