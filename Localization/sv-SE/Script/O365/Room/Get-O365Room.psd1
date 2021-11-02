ConvertFrom-StringData @'
ContentbtnAddAdmin = Lägg till administratör
ContentbtnAddMember = Lägg till användare
ContentbtnAddRoomlist = Lägg till i markerad rumslista
ContentbtnBookingInfo = Spara
ContentbtnCheck = Sök
ContentbtnConfirmMessage = Spara ändring
ContentbtnConfirmMessageReset = Återställ meddelande
ContentbtnCopyAdmins = Kopiera administratörer
ContentbtnCopyAll = Kopiera
ContentbtnCopyMembers = Kopiera användare
ContentbtnCopyOtherRoom = Starta kopiering
ContentbtnExport = Exportera
ContentbtnFetchAdmins = Läs in administratörer
ContentbtnFetchMembers = Läs in användare
ContentbtnFetchRLMembership = Hämta medlemskap
ContentbtnLocation = Spara ny plats
ContentbtnRemoveMembersAzure = Ta bort användare i Azure
ContentbtnRemoveMembersExchange = Ta bort användare i Exchange
ContentbtnRemoveRoomlist = Ta bort från markerad rumslista
ContentbtnRemoveSelectedAdmins = Ta bort
ContentbtnReset = Återställ
ContentbtnRoomName = Byt namn / adress
ContentbtnRoomOwner = Byt ägare
ContentbtnRoomSearch = Sök rum
ContentbtnSelectAll = Markera alla
ContentbtnSyncToExchange = Starta synk
ContentdgAdminsColMail = Mailadress
ContentdgAdminsColName = Namn
ContentdgMembersAzureColMail = Mailadress
ContentdgMembersAzureColName = Namn
ContentdgMembersAzureColSync = Synkad till Exchange
ContentdgMembersExchangeColMail = Mailadress
ContentdgMembersExchangeColName = Namn
ContentdgMembersExchangeColSync = Finns i Azure
ContentdgMembersOtherRoomColMail = Mailadress
ContentdgMembersOtherRoomColName = Namn
ContentdgSuggestionsColMail = Mailadress
ContentdgSuggestionsColName = Namn
ContentexpAddMember = Lägg till användare
ContentexpAddRemAdm = Lägg till/ta bort administratör/-er
ContentgAddAdmin = Lägg till administratör
ContentgAddMember = Lägg till medlem
ContentgMembersAzure = Medlemmar enligt Azure
ContentgMembersExchange = Medlemmar enligt Exchange
ContentgRemoveSelectedAdmins = Ta bort administratörer
ContentlblAddAdmin = Ange användare
ContentlblAddMember = Ange användare
ContentlblCheckRoomTitle = Ange rumsnamn
ContentlblCopyAll = Kopiera användare och administratörer
ContentlblExport = Exportera information och användare till Excel-fil
ContentlblLocation = Plats
ContentlblLogTitle = Log
ContentlblRemoveSelectedAdmins = Ta bort markerade administratörer
ContentlblRoomAddress = Adress
ContentlblRoomName = Namn
ContentlblRoomOwner = Ägare
ContentlblRoomOwnerAddr = Adress
ContentlblRoomOwnerID = Id
ContentlblRoomSearchTitle = Ange rum att kopiera behörigheter från:
ContentlblSuggestionsTitle = Flera rum matchar söktermen, välj önskat rum genom att dubbelklicka
ContentlblSyncToExchange = Starta synkronisering till Exchange
ContentrbBookingInfoNotPublic = Ej publik
ContentrbBookingInfoPublic = Publik
ContenttblBookingInfo = Ska information om bokningar i rummets kalender vara publikt synlig?
ContenttbMemberInfo = Det finns användare som har bokningsbehörigheter för detta rum, som inte är listade i Azure. Dessa har troligen fått behörigheten tilldelad manuellt. De anges genom 'False' i den tredje kolumnen.
ContenttiAdmins = Administratörer
ContenttiConfirmMessage = Bekräftelsemeddelande
ContenttiCopyOtherRoom = Kopiera från annat rum
ContenttiInfo = Info
ContenttiListMembership = Medlemskap i rumslista
ContenttiMembers = Medlemmar
ContentttAddNewMembers = Exporten kommer enbart göras för den information som har lästs in. Har t.ex. medlemmar inte hämtats, kommer de inte listas i Excel-filen
ErrAclTooBig = kan inte synkroniseras till Exchange. För många medlemmar i Azure-gruppen.
ErrAclTooBigQuit = kan inte synkroniseras till Exchange. För många medlemmar i Azure-gruppen. Synkroniseringen avslutas.
ErrGen = Problem vid skapande av behörighet i kalendern:
ErrInvalidExternalUserId = finns inte. Personen har troligen slutat.
ErrLogAccessRights = Sätta policy för access rights
ErrLogAccessRightsUIPolicy = Policy:
ErrLogAccessRightsUIRoom = Rum:
ErrLogAddAdminAdd = Lägg till admin
ErrLogAddAdminSet = Sätt grupp
ErrLogAddAdminUIGrp = Grupp
ErrLogAddAdminUIUsr = Användare
ErrLogAddMemCalProc = Lägg till medlem
ErrLogAddToRoomlist = Lägg till i rumslista
ErrLogAddToRoomlistUIRoom = Rum:
ErrLogAddToRoomlistUIRoomlist = Rumslista:
ErrLogCopyOtherRoom = Kopiera behörigheter annat rum
ErrLogCopyPermUIOtherRoom = Kopiera från
ErrLogCopyPermUIUsers = Användare:
ErrLogNewLoc = Ändra plats
ErrLogNewNameAddr = Nytt namn / adress
ErrLogNewNameAddrUIGrp = AzureAD-grupp
ErrLogNewOwner = Ny ägare
ErrLogRemAdmGrp = Ta bort admin
ErrLogRemoveUserAzure = Ta bort medlem i Azure
ErrLogRemRoomList = Tog bort från rumslista
ErrLogRemRoomListUIRoomList = Rumslista:
ErrLogRemUsrAzUIRoom = Grupp:
ErrLogRemUsrExcRemMbPerm = Ta bort anv Exchange
ErrLogRemUsrExcSetCalProc = Ta bort användare Exchange
ErrLogSetConfirmMsg = Uppdatera verifieringsmeddelande
ErrLogSync = Synkronisering av behörigheter
ErrMsgNewOwnerNotActive = Inte aktiv i AD
ErrMsgNewOwnerNotAddr = Mailadress saknar i AD
ErrMsgNewOwnerNotInAd = Hittas inte i AD
ErrMsgNoAdAccountOwner = Inget aktivt AD-konto för angiven ägare
ErrMsgNoMailAccountOwner = Ingen mailbox aktiv för angiven ägare
ErrNotFound = Inget rum hittades
ErrRoomNotFound = Rum hittas inte
ExcelAdmMailTitle = Mailadress
ExcelAdmTitle = Administratörer
ExcelManUserMailTitle = Mailadress
ExcelManUserTitle = Bokningsbehörighet, ej synkade
ExcelNoAdm = <Inga administratörer angivna>
ExcelNoAdmMail = -
ExcelNoConfirmMess = <Inget bekräftelsemeddelande angivet>
ExcelNoRoomList = <Inte med i någon rumslista>
ExcelNoUser = <Inga användare angivna>
ExcelNoUserMail = -
ExcelRoomConfirmMess = Bekräftelsemeddelande vid bokning
ExcelRoomLocTitle = Plats
ExcelRoomMailTitle = Mailadress
ExcelRoomNameTitle = Rumsnamn
ExcelRoomRoomListTitle = Rumslista
ExcelUserMailTitle = Mailadress
ExcelUserTitle = Bokningsbehörighet
LogAccessRights = Sätta policy för access rights
LogAddAdmin = Lägg till admin
LogAddMemUIRoom = Rum:
LogAddMemUIUser = Användare:
LogAddRoomList = La till i rumslista
LogAddRoomListUIRoom = Rum:
LogAdmPerm = Administratörsbehörighet
LogBookInfoNonPub = Bokningsinfo ej publik
LogBookInfoPub = Bokningsinfo publik
LogBookingPerm = Bokningsbehörighet
LogCopyAdmin = Kopierat admins
LogCopyMembers = Kopierat medlemmar
LogCopyOtherRoom = Kopierat behörigheter
LogCopyOtherRoomUIFrom = Från rum:
LogCopyOtherRoomUIUsers = Användare:
LogExported = Exporterade data
LogMsgOpRemoveAdmAz = togs bort från admingruppen i Azure
LogNewLoc = Ny plats
LogNewLocUILoc = Angiven plats
LogNewLocUIRoom = Rum:
LogNewOwner = Ny ägare
LogNewResponseMessage = Nytt bekräftelsemeddelande
LogRemAdmGrp = Ta bort administratörer
LogRemRoomListUIRoomList = Rumslista:
LogRemUsersAz = Ta bort användare Azure
LogRemUsersEx = Ta bort anv Exchange
LogRoomSearch = Sökning
LogSync = Synkroniserad till Exchange
StrAdminsCopied = Lista över administratörer kopierade
StrAzureADGrpNameAdmSuffix = -Admins
StrAzureADGrpNameBookSuffix = -Book
StrAzureADGrpNamePrefix = RES-
StrConfirmNewName = byta namn på rummet
StrConfirmNewOwner = byta ägare för rummet
StrConfirmPrefix = Du är på väg att
StrConfirmSuffix = Är du säker på att du vill fortsätta?
StrExportFileName = Export rumsinfo
StrGettingRoomListMembership = Hämtar medlemskap i rumslistor
StrLogNewNameAddr = Nytt namn/adress
StrNameOrAddrNotUpd = Vid byte av namn eller adress behöver detta även reflekteras i det andra värdet. Detta verkar inte ha gjorts. Ska de nuvarande värdena i textrutorna användas för rummet?
StrNoAdmins = <Inga administratörer listade>
StrNoMembersAzure = <Inga användare angivna i Azure>
StrNoMembersExchange = <Inga användare angivna i Exchange>
StrNoOwner = Ingen ägare angiven
StrNoUpdate = Rummet uppdaterades inte
StrNoUser = Ingen användare hittades som stämmer överens med
StrOpBookInfoNonPub = Bokningsinformation har ändrats till icke publik
StrOpBookInfoPub = Bokningsinformation har ändrats till publik
StrOpCopyOtherRoomDone = Kopiering av behörigheter från annat rum klar.
StrOpExportBegin = Startar export
StrOpExportEnd = Export utförd. Data skriven till fil
StrOpNameAddrChangeDone = Byte av namn och adress utförd
StrOpNewAdmin = tillagd som administratör i Azure
StrOpNewOwnerDone = Ägarebyte utförd
StrOpNewUser = tillagd med bokningsbehörighet
StrOpNoRoom = Inget rum hittades med namnet
StrOpRemoveUserAz = togs bort från Azure-gruppen
StrOpRemoveUserExc = togs bort från Exchange-gruppen
StrOpSyncDone = Synkroniseringen är utförd
StrOpSynched = synkroniserad
StrOwnerAttrPrefix = Owner:
StrUsersCopied = Lista över användare kopierade
'@
