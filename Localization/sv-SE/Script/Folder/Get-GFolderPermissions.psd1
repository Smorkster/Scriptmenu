ConvertFrom-StringData @'
CodeGP = @{ "Org1" = "Org1_Fil_Grp_" ; "Org2" = "Org2_Fil_Grp_" ; "Org3" = "Org3_Fil_Grp_" }
CodeOrgGrpMembers = switch ( $OrgGroup ) { "Org1_Users" { $OrgGroupMembers = "All users withing Org1" }; "Org2_Users" { $OrgGroupMembers = "All users within Org2" } ; "Org3_Users" { $OrgGroupMembers = "All users within Org3" } }
CodeOrgGrpMembersOutput = "Den HR-synkade gruppen $OrgGroup (Avdelning med id $OrgGroupID och dess undergrupper), som innehåller följande person(er):"
CodeOrgList = Org1, Org2, Org3
LogFolders = Mappar:
LogOpenSum = Öppna utfil:
LogOrg = Kund:
QCustomer = Ange kundgrupp ( Org1, Org2, Org3 )
QFolders = Klistra in en lista med de mappar som du vill ha fram behörighererna på. Hela sökvägen, eller enbart mappnamnet, en per rad. Tryck sedan på ENTER två gånger.
QOpenSum = Vill du öppna filen?
StrAdIdPrefix = aidentity
StrAdIdPropPrefix = aidentity
StrGrpNameSuffixRead = _User_R
StrGrpNameSuffixWrite = _User_C
StrNoRead = <Inga läs-behörigheter>
StrNotFound = hittas inte! Kontrollera mappnamnet och kör scriptet igen.
StrNoWrite = <Inga skriv-behörigheter>
StrOutNotFoundTitle = Följande mappar hittades inte, och kommer inte rapporteras:
StrOutSum = Resultat skrivet till
StrOutTitle = Listar behörigheterna för följande mappar under G:\
StrOwner = Ägare
StrOwnerMissing = Ägare saknas
StrReadPerm = Läs-behörighet
StrSearching = Hämtar information och skriver till fil
StrSum = Sammanfattning
StrWritePerm = Skriv-behörighet
'@
