ConvertFrom-StringData @'
QCustomer = Ange kundgrupp ( Org1, Org2, Org3 )
QFolders = Klistra in en lista med de mappar som du vill ha fram behörighererna på. Hela sökvägen, eller enbart mappnamnet. Tyck sedan på ENTER två gånger.
CodeCustomerList = Org1, Org2, Org3
StrNotFound = hittas inte! Kontrollera mappnamnet och kör scriptet igen.
StrSearching = Hämtar information och skriver till fil
StrOutTitle = Listar behörigheterna för följande mappar under G:\
StrOutNotFoundTitle = Följande mappar hittades inte, och kommer inte rapporteras:
CodeGP = @{ "Org1" = "Org1_Fil_Grp_" ; "Org2" = "Org2_Fil_Grp_" ; "Org3" = "Org3_Fil_Grp_" }
StrGrpNameSuffixWrite = _User_C
StrGrpNameSuffixRead = _User_R
StrOwner = Ägare:
StrOwnerMissing = Ägare saknas
StrReadPerm = Läs-behörighet:
StrWritePerm = Skriv-behörighet:
StrNoRead = <Inga läs-behörigheter>
StrNoWrite = <Inga skriv-behörigheter>
StrAdIdPropPrefix = adentity
StrAdIdPrefix = aidentity
CodeOrgGrpMembers = switch ( $OrgGroup ) { "Org1_Users" { $OrgGroupMembers = "Alla användare inom Org1" }; "Org2_Users" { $OrgGroupMembers = "Alla användare inom Org2" } ;"Org3_Users" { $OrgGroupMembers = "Alla användare inom Org3" } }
CodeOrgGrpMembersOutput = "Den EK-synkade gruppen $OrgGroup (Enheten med HSA-id $OrgGroupID i EK och dess underenheter) som innehåller följande person(er):"
StrOutSum = Resultat skrivet till
QOpenSum = Vill du öppna filen?
StrSum = Sammanfattning
'@
