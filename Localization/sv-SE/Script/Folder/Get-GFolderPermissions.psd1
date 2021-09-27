ConvertFrom-StringData @'
CodeGP = @{ "Kar" = "Kar_Fil_Gainaskar02_Grp_" ; "Sos" = "Sos_Fil_Gainassos01_Grp_" ; "Dan" = "Dan_Fil_Gainasdan01_Grp_" ; "Lit" = "Lit_Fil_Gainaslit01_Grp_" ; "Rev" = "Rev_Fil_Gainasrev01_Grp_" ; "Pnf" = "Pnf_Fil_Gainaspnf01_Grp_" ; "Trf" = "Trf_Fil_Gainastrf01_Grp_" }
CodeOrgGrpMembers = switch ( $OrgGroup ) { "Kar_Org_K_Users" { $OrgGroupMembers = "Alla användare på hela Karolinska Universitetssjukhuset" };"Dan_Org_DS_Users" { $OrgGroupMembers = "Alla användare på hela Danderyds sjukhus" } ;"Sos_Org_Sos_Users" { $OrgGroupMembers = "Alla användare på hela Södersjukhuset" } }
CodeOrgGrpMembersOutput = "Den EK-synkade gruppen $OrgGroup (Enheten med HSA-id $OrgGroupID i EK och dess underenheter) som innehåller följande person(er):"
CodeOrgList = Kar, Sos, Dan, Lit, Rev, Pnf, Trf
LogFolders = Mappar:
LogOpenSum = Öppna utfil:
LogOrg = Kund:
QCustomer = Ange kundgrupp ( Kar, Sos, Dan, Lit, Rev, Pnf, Trf )
QFolders = Klistra in en lista med de mappar som du vill ha fram behörighererna på. Hela sökvägen, eller enbart mappnamnet, en per rad. Tryck sedan på ENTER två gånger.
QOpenSum = Vill du öppna filen?
StrAdIdPrefix = SE2321000016-
StrAdIdPropPrefix = hsaIdentity
StrGrpNameSuffixRead = _User_R
StrGrpNameSuffixWrite = _User_C
StrNoRead = <Inga läs-behörigheter>
StrNotFound = hittas inte! Kontrollera mappnamnet och kör scriptet igen.
StrNoWrite = <Inga skriv-behörigheter>
StrOutNotFoundTitle = Följande mappar hittades inte, och kommer inte rapporteras:
StrOutSum = Resultat skrivet till
StrOutTitle = Listar behörigheterna för följande mappar under G:\
StrOwner = Ägare:
StrOwnerMissing = Ägare saknas
StrReadPerm = Läs-behörighet:
StrSearching = Hämtar information och skriver till fil
StrSum = Sammanfattning
StrWritePerm = Skriv-behörighet:
'@
