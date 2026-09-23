/* ---------------------------------------------------------------------
   CrimeEnterprise.cls

   A single ooRexx class library for modelling a suspected criminal
   enterprise: the people, organisations, places, objects and events
   involved, and how they relate to one another.

   UK-centric defaults (country code "GB", currency "GBP") but every
   place that matters carries an ISO 3166-1 alpha-2 countryCode so the
   model works for other jurisdictions without change.

   This file is a pure class library: it has no top-level executable
   statements, so it is safe to ::requires from other Alchemy code.
   A worked usage example is included as a comment block at the very
   end of the file.

   Class hierarchy
   ----------------
   Entity                       -- common id / audit-trail base class
     Person
     Organisation
       Company
       CriminalEnterprise
     Offence
     Weapon
     Vehicle
     CommunicationDevice
     CommunicationEvent
     FinancialAccount
     Evidence
     MediaReference              -- CCTV / photo / video / audio / document scan
     Sighting                    -- a Person seen at a Moment ("seen at")
     Report                      -- something reported in, from any source
       ExternalReport             -- a report from an external body or member of public
       ExternalIntelligence       -- a graded intelligence product (NIM 5x5x5 style)
     Incident
     Charge
     Investigation

   Address                      -- postal address, any country
     Location                   -- Address + scene-of-incident detail

   Identifier                   -- a single ID document (passport, NI, etc)
   Involvement                  -- Person <-> Incident, with a role
   Relationship                 -- Person <-> Person, with a type
   OffenceCategory              -- a taxonomy entry (drugs, violence, fraud ...), hierarchical
   Moment                       -- a timestamp that can anchor to a map point, a known
                                    Location, and/or a MediaReference (video/CCTV)

   Conventions used throughout
   ----------------------------
   - Every settable attribute is declared "::attribute name unguarded"
     so it can be read and set from outside the defining class.
   - Every method that assigns an instance variable starts with
     "expose" listing every instance variable the method touches, as
     its first executable statement.
   - Superclass constructors are invoked explicitly by scope, e.g.
     self~init:super, self~init:super(...) -- ooRexx does not
     auto-chain ::method init up the hierarchy.
   - Optional constructor arguments use "use arg x = default" so no
     code needs to test an unset argument with symbol("x") = "LIT".
   - Collections are .array unless a keyed lookup is genuinely wanted,
     in which case .directory is used with its dot-attribute access
     (dir~key = value / dir~key).
   - No "&" is used (it does not short-circuit in ooRexx); nested IFs
     are used instead.
   - No variable is ever named "result".
   - No "+ 0" numeric coercion is used anywhere.
   - No DO/LOOP block carries a label.
   - Enumerated fields (role, type, status, category ...) are plain
     strings, not a real enum -- ooRexx has none. The permitted values
     for each are documented next to the attribute in comments.
--------------------------------------------------------------------- */


/* =======================================================================
   Entity -- common base class: identity + audit trail + free-text notes
   ======================================================================= */
::class Entity public

::attribute id unguarded
::attribute createdAt unguarded
::attribute notes unguarded

::method init
  expose id createdAt notes
  id = self~generateId
  createdAt = date('S') time('N')
  notes = .array~new
  return

::method generateId
  return self~class~id"-"date('S')"-"time('L')"-"random(1000,9999)

::method addNote
  expose notes
  use arg noteText
  notes~append(date('S') time('N')": "noteText)
  return self

::method string
  expose id
  return self~class~id"("id")"


/* =======================================================================
   Address -- a postal address in an internationally portable shape.
   Deliberately loose: not every country uses town/region/postcode the
   same way, so every line is optional free text and countryCode (ISO
   3166-1 alpha-2, e.g. "GB", "US", "IE") drives display and lookups.
   ======================================================================= */
::class Address public

::attribute line1 unguarded          -- building / house name or number, street
::attribute line2 unguarded          -- district / locality
::attribute line3 unguarded          -- further locality (rarely needed)
::attribute town unguarded           -- town / city
::attribute region unguarded         -- county / state / province
::attribute postcode unguarded       -- postcode / zip / postal code
::attribute countryCode unguarded    -- ISO 3166-1 alpha-2
::attribute latitude unguarded       -- optional decimal degrees
::attribute longitude unguarded      -- optional decimal degrees

::method init
  expose line1 line2 line3 town region postcode countryCode latitude longitude
  use arg town = "", countryCode = "GB"
  line1 = ""
  line2 = ""
  line3 = ""
  region = ""
  postcode = ""
  latitude = ""
  longitude = ""
  return

::method hasCoordinates
  expose latitude longitude
  if latitude = "" then return .false
  if longitude = "" then return .false
  return .true

::method formatted
  expose line1 line2 line3 town region postcode countryCode
  addressLines = .array~new
  if line1 <> "" then addressLines~append(line1)
  if line2 <> "" then addressLines~append(line2)
  if line3 <> "" then addressLines~append(line3)
  if town <> "" then addressLines~append(town)
  if region <> "" then addressLines~append(region)
  if postcode <> "" then addressLines~append(postcode)
  if countryCode <> "" then addressLines~append(self~countryName(countryCode))
  joinedText = ""
  do currentLine over addressLines
    if joinedText = "" then joinedText = currentLine
    else joinedText = joinedText || "0A"x || currentLine
  end
  return joinedText

::method countryName
  use arg code
  select
    when code = "GB" then return "United Kingdom"
    when code = "IE" then return "Ireland"
    when code = "US" then return "United States"
    when code = "FR" then return "France"
    when code = "DE" then return "Germany"
    when code = "ES" then return "Spain"
    when code = "NL" then return "Netherlands"
    when code = "IT" then return "Italy"
    when code = "PL" then return "Poland"
    when code = "RO" then return "Romania"
    otherwise return code
  end

::method string
  return self~formatted


/* =======================================================================
   Location -- an Address plus the extra detail relevant to a place
   where something happened (a crime scene, a meeting point, a lock-up).
   ======================================================================= */
::class Location public subclass Address

::attribute venueName unguarded          -- e.g. "The Crown public house"
::attribute venueType unguarded          -- RESIDENTIAL, COMMERCIAL, PUBLIC_SPACE,
                                          -- VEHICLE, LOCK_UP, LICENSED_PREMISES, OTHER
::attribute venueDescription unguarded

::method init
  expose venueName venueType venueDescription
  use arg town = "", countryCode = "GB"
  self~init:super(town, countryCode)
  venueName = ""
  venueType = ""
  venueDescription = ""
  return

::method string
  expose venueName
  locationText = self~formatted
  if venueName <> "" then locationText = venueName" -- "locationText
  return locationText


/* =======================================================================
   Identifier -- one piece of identifying documentation for a Person
   (passport, driving licence, National Insurance number, etc).
   ======================================================================= */
::class Identifier public

::attribute identifierType unguarded   -- PASSPORT, DRIVING_LICENCE, NATIONAL_INSURANCE,
                                        -- NATIONAL_ID, TAX_REFERENCE, OTHER
::attribute value unguarded
::attribute issuingCountry unguarded   -- ISO 3166-1 alpha-2
::attribute issuedDate unguarded
::attribute expiryDate unguarded

::method init
  expose identifierType value issuingCountry issuedDate expiryDate
  use arg identifierType, value, issuingCountry = "GB"
  issuedDate = ""
  expiryDate = ""
  return

::method string
  expose identifierType value issuingCountry
  return identifierType": "value" ("issuingCountry")"


/* =======================================================================
   Moment -- a single point in time that can, optionally, be anchored to
   a raw map position (latitude/longitude from a phone, a tag, a plot),
   to a Location already on file, and/or to a piece of MediaReference
   footage that shows it (CCTV, a photo, a video). Any or all of these
   may be blank/.nil -- a Moment can be as thin as just a timestamp.
   ======================================================================= */
::class Moment public

::attribute timestamp unguarded      -- free-text date/time, e.g. "2026-06-14 22:40"
::attribute latitude unguarded       -- raw map position, decimal degrees
::attribute longitude unguarded      -- raw map position, decimal degrees
::attribute knownLocation unguarded  -- a Location already on file, or .nil
::attribute video unguarded          -- a MediaReference, or .nil

::method init
  expose timestamp latitude longitude knownLocation video
  use arg timestamp = ""
  latitude = ""
  longitude = ""
  knownLocation = .nil
  video = .nil
  return

::method hasMapPosition
  expose latitude longitude
  if latitude = "" then return .false
  if longitude = "" then return .false
  return .true

::method string
  expose timestamp knownLocation
  momentText = timestamp
  if knownLocation <> .nil then momentText = momentText" @ "knownLocation~string
  return momentText


/* =======================================================================
   Person -- an individual. Roles are held as a list so the same person
   can be, say, both a WITNESS in one incident and a SUSPECT in another;
   role is really a property of an Involvement, but a person-level
   roles list is kept too as a quick "what is this person, overall" tag.
   ======================================================================= */
::class Person public subclass Entity

::attribute firstName unguarded
::attribute middleNames unguarded
::attribute lastName unguarded
::attribute aliases unguarded            -- .array of strings
::attribute dateOfBirth unguarded
::attribute gender unguarded
::attribute nationality unguarded        -- ISO 3166-1 alpha-2
::attribute occupation unguarded
::attribute addresses unguarded          -- .array of Address
::attribute identifiers unguarded        -- .array of Identifier
::attribute roles unguarded              -- .array of strings, see addRole
::attribute phoneNumber unguarded
::attribute email unguarded
::attribute photographReference unguarded

/* permitted values for roles: VICTIM, SUSPECT, OFFENDER, WITNESS,
   PERSON_OF_INTEREST, ASSOCIATE, INFORMANT, COMPLAINANT */

::method init
  expose firstName middleNames lastName aliases dateOfBirth gender nationality occupation addresses identifiers roles phoneNumber email photographReference
  self~init:super
  use arg firstName, lastName, dateOfBirth = ""
  middleNames = ""
  gender = ""
  nationality = ""
  occupation = ""
  phoneNumber = ""
  email = ""
  photographReference = ""
  aliases = .array~new
  addresses = .array~new
  identifiers = .array~new
  roles = .array~new
  return

::method fullName
  expose firstName middleNames lastName
  fullNameText = firstName
  if middleNames <> "" then fullNameText = fullNameText" "middleNames
  fullNameText = fullNameText" "lastName
  return fullNameText

::method addAlias
  expose aliases
  use arg aliasName
  aliases~append(aliasName)
  return self

::method addAddress
  expose addresses
  use arg anAddress
  addresses~append(anAddress)
  return self

::method addIdentifier
  expose identifiers
  use arg anIdentifier
  identifiers~append(anIdentifier)
  return self

::method addRole
  expose roles
  use arg roleName
  if self~hasRole(roleName) then return self
  roles~append(roleName)
  return self

::method hasRole
  expose roles
  use arg roleName
  do currentRole over roles
    if currentRole = roleName then return .true
  end
  return .false

::method string
  expose dateOfBirth
  descriptionText = self~fullName
  if dateOfBirth <> "" then descriptionText = descriptionText" (DOB "dateOfBirth")"
  return descriptionText


/* =======================================================================
   Organisation -- base class for anything corporate: a legitimate
   company, a charity, a shell, a front, or the criminal enterprise
   itself (see CriminalEnterprise below).
   ======================================================================= */
::class Organisation public subclass Entity

::attribute name unguarded
::attribute tradingNames unguarded       -- .array of strings
::attribute addresses unguarded          -- .array of Address
::attribute organisationType unguarded   -- LEGITIMATE, SHELL, FRONT,
                                          -- CRIMINAL_ENTERPRISE, CHARITY, PARTNERSHIP
::attribute countryCode unguarded        -- ISO 3166-1 alpha-2, jurisdiction

::method init
  expose name tradingNames addresses organisationType countryCode
  self~init:super
  use arg name, countryCode = "GB", organisationType = "LEGITIMATE"
  tradingNames = .array~new
  addresses = .array~new
  return

::method addAddress
  expose addresses
  use arg anAddress
  addresses~append(anAddress)
  return self

::method addTradingName
  expose tradingNames
  use arg tradingName
  tradingNames~append(tradingName)
  return self

::method string
  expose name organisationType
  return name" ("organisationType")"


/* =======================================================================
   Company -- a registered corporate entity. companyNumber is the UK
   Companies House style registration number by default, but nothing
   stops it holding an equivalent foreign registry number alongside
   countryCode (inherited) set to that country.
   ======================================================================= */
::class Company public subclass Organisation

::attribute companyNumber unguarded
::attribute companyType unguarded        -- LTD, PLC, LLP, SOLE_TRADER, PARTNERSHIP, OTHER
::attribute incorporationDate unguarded
::attribute dissolvedDate unguarded
::attribute status unguarded             -- ACTIVE, DISSOLVED, DORMANT, LIQUIDATION
::attribute registeredOfficeAddress unguarded  -- an Address
::attribute sicCodes unguarded           -- .array of strings, standard industrial classification
::attribute directors unguarded          -- .array of Person

::method init
  expose companyNumber companyType incorporationDate dissolvedDate status registeredOfficeAddress sicCodes directors
  use arg name, companyNumber = "", countryCode = "GB"
  self~init:super(name, countryCode, "LEGITIMATE")
  companyType = ""
  incorporationDate = ""
  dissolvedDate = ""
  status = "ACTIVE"
  registeredOfficeAddress = .nil
  sicCodes = .array~new
  directors = .array~new
  return

::method addDirector
  expose directors
  use arg aPerson
  directors~append(aPerson)
  return self

::method addSicCode
  expose sicCodes
  use arg sicCode
  sicCodes~append(sicCode)
  return self


/* =======================================================================
   CriminalEnterprise -- the suspected organised group itself, modelled
   as an Organisation so it can hold addresses, trading fronts etc in
   the same way a legitimate company can. Membership is a list of
   Person/role pairs held in a .directory per member.
   ======================================================================= */
::class CriminalEnterprise public subclass Organisation

::attribute structureType unguarded      -- HIERARCHY, NETWORK, CELL_BASED, FAMILY_BASED
::attribute members unguarded            -- .array of .directory{person, role}
::attribute suspectedActivities unguarded -- .array of strings, e.g. "DRUGS_SUPPLY"
::attribute territory unguarded          -- free text, e.g. "East Glasgow"

/* permitted values for a member's role: LEADER, LIEUTENANT, ENFORCER,
   COURIER, ASSOCIATE, FINANCIER, FACILITATOR, PERIPHERAL */

::method init
  expose structureType members suspectedActivities territory
  use arg name, countryCode = "GB"
  self~init:super(name, countryCode, "CRIMINAL_ENTERPRISE")
  structureType = ""
  territory = ""
  members = .array~new
  suspectedActivities = .array~new
  return

::method addMember
  expose members
  use arg aPerson, roleInGroup
  membershipRecord = .directory~new
  membershipRecord~person = aPerson
  membershipRecord~role = roleInGroup
  members~append(membershipRecord)
  return self

::method addSuspectedActivity
  expose suspectedActivities
  use arg activity
  suspectedActivities~append(activity)
  return self

::method membersWithRole
  expose members
  use arg roleInGroup
  matchingMembers = .array~new
  do membershipRecord over members
    if membershipRecord~role = roleInGroup then matchingMembers~append(membershipRecord~person)
  end
  return matchingMembers


/* =======================================================================
   OffenceCategory -- a taxonomy entry ("Drugs", "Violence against the
   person", "Fraud" ...) that an Offence is filed under. Hierarchical:
   a category can have a parentCategory, so "Firearms - possession" can
   sit under the broader "Firearms" which sits under "Violent".
   ======================================================================= */
::class OffenceCategory public

::attribute code unguarded            -- short code, e.g. "DRUGS", "VIOLENT_GBH"
::attribute categoryName unguarded    -- display name, e.g. "Drug offences"
::attribute categoryDescription unguarded
::attribute parentCategory unguarded  -- an OffenceCategory, or .nil for a top-level category

::method init
  expose code categoryName categoryDescription parentCategory
  use arg code, categoryName = ""
  categoryDescription = ""
  parentCategory = .nil
  return

::method isSubcategoryOf
  expose parentCategory
  use arg anotherCategory
  if parentCategory = .nil then return .false
  if parentCategory~code = anotherCategory~code then return .true
  return parentCategory~isSubcategoryOf(anotherCategory)

::method string
  expose categoryName
  return categoryName


/* =======================================================================
   Offence -- a link to the relevant law, not an occurrence of it (an
   occurrence is recorded via Incident~addOffence and, once someone is
   formally charged, via Charge).
   ======================================================================= */
::class Offence public subclass Entity

::attribute code unguarded               -- short reference, e.g. "CJA1988 S139"
::attribute act unguarded                -- legislation name, e.g. "Criminal Justice Act 1988"
::attribute section unguarded
::attribute shortDescription unguarded
::attribute category unguarded           -- an OffenceCategory, e.g. DRUGS, VIOLENT,
                                          -- ACQUISITIVE, FRAUD, CYBER, SEXUAL,
                                          -- PUBLIC_ORDER, FIREARMS, MOTORING, OTHER
::attribute triable unguarded            -- SUMMARY, EITHER_WAY, INDICTABLE
::attribute maxSentence unguarded        -- free text, e.g. "4 years' imprisonment"

::method init
  expose code act section shortDescription category triable maxSentence
  self~init:super
  use arg code, act = "", shortDescription = ""
  section = ""
  category = ""
  triable = ""
  maxSentence = ""
  return

::method string
  expose code shortDescription
  return code" - "shortDescription


/* =======================================================================
   Weapon
   ======================================================================= */
::class Weapon public subclass Entity

::attribute weaponType unguarded         -- FIREARM, BLADE, BLUNT_INSTRUMENT,
                                          -- CHEMICAL, EXPLOSIVE, OTHER
::attribute weaponDescription unguarded
::attribute make unguarded
::attribute model unguarded
::attribute serialNumber unguarded
::attribute calibre unguarded
::attribute licensed unguarded           -- .true / .false
::attribute licenceHolder unguarded      -- a Person, or .nil
::attribute recoveredLocation unguarded  -- a Location, or .nil
::attribute forensicReference unguarded

::method init
  expose weaponType weaponDescription make model serialNumber calibre licensed licenceHolder recoveredLocation forensicReference
  self~init:super
  use arg weaponType, weaponDescription = ""
  make = ""
  model = ""
  serialNumber = ""
  calibre = ""
  licensed = .false
  licenceHolder = .nil
  recoveredLocation = .nil
  forensicReference = ""
  return

::method string
  expose weaponType weaponDescription
  return weaponType" - "weaponDescription


/* =======================================================================
   Vehicle
   ======================================================================= */
::class Vehicle public subclass Entity

::attribute registration unguarded       -- number plate / licence plate
::attribute make unguarded
::attribute model unguarded
::attribute colour unguarded
::attribute vin unguarded
::attribute vehicleType unguarded        -- CAR, VAN, MOTORCYCLE, HGV, BOAT, OTHER
::attribute registeredKeeper unguarded   -- a Person, or .nil

::method init
  expose registration make model colour vin vehicleType registeredKeeper
  self~init:super
  use arg registration, make = "", model = ""
  colour = ""
  vin = ""
  vehicleType = ""
  registeredKeeper = .nil
  return

::method string
  expose registration make model
  return registration" ("make" "model")"


/* =======================================================================
   CommunicationDevice -- a physical or logical device belonging to
   someone (a phone, a SIM, an email account, a messaging handle).
   ======================================================================= */
::class CommunicationDevice public subclass Entity

::attribute deviceType unguarded         -- MOBILE_PHONE, SIM, LANDLINE, EMAIL_ACCOUNT,
                                          -- MESSAGING_HANDLE, OTHER
::attribute imei unguarded
::attribute phoneNumber unguarded        -- or email address / handle, as applicable
::attribute owner unguarded              -- a Person, or .nil
::attribute seizedDate unguarded

::method init
  expose deviceType imei phoneNumber owner seizedDate
  self~init:super
  use arg deviceType, phoneNumber = ""
  imei = ""
  owner = .nil
  seizedDate = ""
  return

::method string
  expose deviceType phoneNumber
  return deviceType": "phoneNumber


/* =======================================================================
   CommunicationEvent -- one intercepted or recovered call / message
   between two CommunicationDevices, used to build a contact network.
   ======================================================================= */
::class CommunicationEvent public subclass Entity

::attribute fromDevice unguarded         -- a CommunicationDevice
::attribute toDevice unguarded           -- a CommunicationDevice
::attribute dateTimeOccurred unguarded
::attribute communicationType unguarded  -- CALL, SMS, EMAIL, MESSAGING_APP, VOICE_NOTE
::attribute durationSeconds unguarded
::attribute contentSummary unguarded
::attribute intercepted unguarded        -- .true / .false
::attribute legalAuthorityReference unguarded  -- e.g. a warrant reference

::method init
  expose fromDevice toDevice dateTimeOccurred communicationType durationSeconds contentSummary intercepted legalAuthorityReference
  self~init:super
  use arg fromDevice, toDevice, communicationType = "CALL"
  dateTimeOccurred = ""
  durationSeconds = 0
  contentSummary = ""
  intercepted = .false
  legalAuthorityReference = ""
  return

::method string
  expose fromDevice toDevice communicationType dateTimeOccurred
  return communicationType" "fromDevice~phoneNumber" -> "toDevice~phoneNumber" @ "dateTimeOccurred


/* =======================================================================
   FinancialAccount
   ======================================================================= */
::class FinancialAccount public subclass Entity

::attribute accountType unguarded        -- CURRENT, SAVINGS, BUSINESS, CRYPTO, OTHER
::attribute institution unguarded
::attribute accountNumberMasked unguarded -- store only a masked/last-4 form
::attribute sortCode unguarded
::attribute holder unguarded             -- a Person or Organisation
::attribute currency unguarded           -- ISO 4217, e.g. "GBP"

::method init
  expose accountType institution accountNumberMasked sortCode holder currency
  self~init:super
  use arg accountType, institution = ""
  accountNumberMasked = ""
  sortCode = ""
  holder = .nil
  currency = "GBP"
  return

::method string
  expose institution accountNumberMasked
  return institution" ("accountNumberMasked")"


/* =======================================================================
   Evidence -- a physical or digital exhibit, with a chain-of-custody
   log built up over time.
   ======================================================================= */
::class Evidence public subclass Entity

::attribute evidenceType unguarded       -- PHYSICAL, DOCUMENT, DIGITAL, FORENSIC,
                                          -- PHOTOGRAPHIC, TESTIMONIAL, OTHER
::attribute evidenceDescription unguarded
::attribute exhibitReference unguarded
::attribute seizedDate unguarded
::attribute seizedBy unguarded
::attribute chainOfCustody unguarded     -- .array of timestamped strings
::attribute relatedTo unguarded          -- typically an Incident, or .nil
::attribute storageLocation unguarded
::attribute mediaReference unguarded     -- a MediaReference, or .nil, for photographic/AV exhibits

::method init
  expose evidenceType evidenceDescription exhibitReference seizedDate seizedBy chainOfCustody relatedTo storageLocation mediaReference
  self~init:super
  use arg evidenceType, evidenceDescription = ""
  exhibitReference = ""
  seizedDate = ""
  seizedBy = ""
  relatedTo = .nil
  storageLocation = ""
  mediaReference = .nil
  chainOfCustody = .array~new
  return

::method addCustodyEvent
  expose chainOfCustody
  use arg custodyEventText
  chainOfCustody~append(date('S') time('N')": "custodyEventText)
  return self

::method string
  expose evidenceType exhibitReference
  return evidenceType" ["exhibitReference"]"


/* =======================================================================
   MediaReference -- a pointer to a piece of captured media (CCTV
   footage, a photograph, a video, an audio recording, a scanned
   document, a social-media capture). Holds only a reference/path and
   descriptive metadata, not the media itself.
   ======================================================================= */
::class MediaReference public subclass Entity

::attribute mediaType unguarded          -- CCTV, PHOTOGRAPH, VIDEO, AUDIO_RECORDING,
                                          -- DOCUMENT_SCAN, SOCIAL_MEDIA, OTHER
::attribute fileReference unguarded      -- path, URI, or exhibit/store reference
::attribute mediaDescription unguarded
::attribute capturedDateTime unguarded
::attribute capturedLocation unguarded   -- a Location, or .nil, e.g. the camera's site
::attribute sourceOwner unguarded        -- who operates the camera/account, e.g. "Tesco Express, High Street"
::attribute relatesTo unguarded          -- the Person / Incident / etc this media evidences, or .nil

::method init
  expose mediaType fileReference mediaDescription capturedDateTime capturedLocation sourceOwner relatesTo
  self~init:super
  use arg mediaType, fileReference = ""
  mediaDescription = ""
  capturedDateTime = ""
  capturedLocation = .nil
  sourceOwner = ""
  relatesTo = .nil
  return

::method string
  expose mediaType fileReference
  return mediaType": "fileReference


/* =======================================================================
   Sighting -- a Person seen at a Moment ("seen at"): who was seen, when
   and where (via a Moment, which can itself carry a map position, a
   known Location, and/or CCTV/video footage), who reported the sighting
   and how confident that report is.
   ======================================================================= */
::class Sighting public subclass Entity

::attribute personSeen unguarded
::attribute moment unguarded             -- a Moment
::attribute reportedBy unguarded         -- free text, or a Person
::attribute reliability unguarded        -- CONFIRMED, UNCONFIRMED, DISPUTED, ANONYMOUS_TIP
::attribute sightingNotes unguarded

::method init
  expose personSeen moment reportedBy reliability sightingNotes
  self~init:super
  use arg personSeen, moment
  reportedBy = ""
  reliability = "UNCONFIRMED"
  sightingNotes = ""
  return

::method string
  expose personSeen moment reliability
  return personSeen~fullName" seen at "moment~string" ("reliability")"


/* =======================================================================
   Report -- something reported in to the investigation, from any
   source. Base class for the two more specific external inputs below;
   also usable directly for a plain report that doesn't need grading.
   ======================================================================= */
::class Report public subclass Entity

::attribute source unguarded             -- who/where it came from, e.g. "Crimestoppers",
                                          -- "member of the public", "HMRC"
::attribute receivedDate unguarded
::attribute receivedBy unguarded         -- officer/handler who took the report
::attribute reportContent unguarded      -- free-text summary
::attribute relatesTo unguarded          -- a Person / Incident / Organisation / etc, or .nil
::attribute reportReference unguarded    -- internal reference number

::method init
  expose source receivedDate receivedBy reportContent relatesTo reportReference
  self~init:super
  use arg source = "", reportContent = ""
  receivedDate = date('S')
  receivedBy = ""
  relatesTo = .nil
  reportReference = ""
  return

::method string
  expose source receivedDate
  return "Report from "source" on "receivedDate


/* =======================================================================
   ExternalReport -- a report received from an external body or a
   member of the public (as opposed to intelligence developed by, or
   graded within, the investigating agency -- see ExternalIntelligence).
   ======================================================================= */
::class ExternalReport public subclass Report

::attribute reportingAgency unguarded     -- name of the external body/force/organisation
::attribute reportMethod unguarded        -- PHONE, EMAIL, IN_PERSON, PORTAL, LETTER, OTHER
::attribute actionTaken unguarded

::method init
  expose reportingAgency reportMethod actionTaken
  use arg source = "", reportContent = ""
  self~init:super(source, reportContent)
  reportingAgency = ""
  reportMethod = ""
  actionTaken = ""
  return


/* =======================================================================
   ExternalIntelligence -- a formal intelligence product, graded on
   entry in the UK National Intelligence Model "5x5x5" style: how
   reliable the source is, how reliable the information itself is, and
   a handling code governing how it may be used and shared.
   ======================================================================= */
::class ExternalIntelligence public subclass Report

::attribute sourceGrading unguarded         -- A (always reliable) .. E (untested source)
::attribute intelligenceGrading unguarded   -- 1 (known true) .. 5 (suspected false)
::attribute handlingCode unguarded          -- e.g. "3/4/1", or a plain classification
::attribute classification unguarded        -- OFFICIAL, OFFICIAL_SENSITIVE, SECRET
::attribute dissemination unguarded         -- who/where this may be shared with

::method init
  expose sourceGrading intelligenceGrading handlingCode classification dissemination
  use arg source = "", reportContent = ""
  self~init:super(source, reportContent)
  sourceGrading = ""
  intelligenceGrading = ""
  handlingCode = ""
  classification = "OFFICIAL"
  dissemination = ""
  return


/* =======================================================================
   Involvement -- links one Person to one Incident with a role. Kept as
   its own value class (rather than just a directory) so it can grow
   its own notes / confidence later without disturbing Incident.
   ======================================================================= */
::class Involvement public

::attribute person unguarded
::attribute role unguarded               -- VICTIM, SUSPECT, OFFENDER, WITNESS,
                                          -- PERSON_OF_INTEREST, REPORTING_OFFICER
::attribute involvementNotes unguarded

::method init
  expose person role involvementNotes
  use arg person, role
  involvementNotes = ""
  return

::method string
  expose person role
  return person~fullName" ("role")"


/* =======================================================================
   Relationship -- links two Persons together, independent of any one
   Incident (family ties, known associates, employer/employee, etc).
   ======================================================================= */
::class Relationship public

::attribute personA unguarded
::attribute personB unguarded
::attribute relationshipType unguarded   -- FAMILY, ASSOCIATE, EMPLOYER, EMPLOYEE,
                                          -- CO_DEFENDANT, RIVAL, ROMANTIC_PARTNER,
                                          -- KNOWN_CONTACT
::attribute relationshipNotes unguarded
::attribute confidence unguarded         -- free text or a percentage, e.g. "HIGH", "70%"

::method init
  expose personA personB relationshipType relationshipNotes confidence
  use arg personA, personB, relationshipType
  relationshipNotes = ""
  confidence = ""
  return

::method string
  expose personA personB relationshipType
  return personA~fullName" -- "relationshipType" --> "personB~fullName


/* =======================================================================
   Incident -- something that happened: a time, a place, the people
   involved (each with their own role via Involvement), the offences
   suspected, and any weapons / vehicles / evidence tied to it.
   ======================================================================= */
::class Incident public subclass Entity

::attribute incidentNumber unguarded
::attribute dateTimeOccurred unguarded
::attribute dateTimeReported unguarded
::attribute location unguarded           -- a Location
::attribute narrative unguarded
::attribute status unguarded             -- REPORTED, UNDER_INVESTIGATION, CHARGED,
                                          -- WITH_CPS, AT_COURT, CLOSED, NO_FURTHER_ACTION
::attribute involvements unguarded       -- .array of Involvement
::attribute suspectedOffences unguarded  -- .array of Offence
::attribute weaponsInvolved unguarded    -- .array of Weapon
::attribute vehiclesInvolved unguarded   -- .array of Vehicle
::attribute evidenceItems unguarded      -- .array of Evidence

::method init
  expose incidentNumber dateTimeOccurred dateTimeReported location narrative status involvements suspectedOffences weaponsInvolved vehiclesInvolved evidenceItems
  self~init:super
  use arg incidentNumber = "", dateTimeOccurred = ""
  dateTimeReported = ""
  location = .nil
  narrative = ""
  status = "REPORTED"
  involvements = .array~new
  suspectedOffences = .array~new
  weaponsInvolved = .array~new
  vehiclesInvolved = .array~new
  evidenceItems = .array~new
  return

::method addPerson
  expose involvements
  use arg aPerson, roleInIncident
  involvements~append(.Involvement~new(aPerson, roleInIncident))
  return self

::method addOffence
  expose suspectedOffences
  use arg anOffence
  suspectedOffences~append(anOffence)
  return self

::method addWeapon
  expose weaponsInvolved
  use arg aWeapon
  weaponsInvolved~append(aWeapon)
  return self

::method addVehicle
  expose vehiclesInvolved
  use arg aVehicle
  vehiclesInvolved~append(aVehicle)
  return self

::method addEvidence
  expose evidenceItems
  use arg anEvidenceItem
  evidenceItems~append(anEvidenceItem)
  return self

::method peopleWithRole
  expose involvements
  use arg roleInIncident
  matchingPeople = .array~new
  do anInvolvement over involvements
    if anInvolvement~role = roleInIncident then matchingPeople~append(anInvolvement~person)
  end
  return matchingPeople

::method victims
  return self~peopleWithRole("VICTIM")

::method suspects
  return self~peopleWithRole("SUSPECT")

::method string
  expose incidentNumber dateTimeOccurred status
  return "Incident "incidentNumber" ("dateTimeOccurred") - "status


/* =======================================================================
   Charge -- a formal charge brought against a Person for a specific
   Offence, optionally tied back to the Incident that gave rise to it.
   ======================================================================= */
::class Charge public subclass Entity

::attribute chargedPerson unguarded
::attribute offence unguarded
::attribute relatedIncident unguarded    -- an Incident, or .nil
::attribute dateCharged unguarded
::attribute plea unguarded               -- GUILTY, NOT_GUILTY, NO_PLEA_ENTERED
::attribute outcome unguarded            -- PENDING, CONVICTED, ACQUITTED, DROPPED,
                                          -- DIVERTED

::method init
  expose chargedPerson offence relatedIncident dateCharged plea outcome
  self~init:super
  use arg chargedPerson, offence, relatedIncident = .nil
  dateCharged = date('S')
  plea = ""
  outcome = "PENDING"
  return

::method string
  expose chargedPerson offence outcome
  return chargedPerson~fullName" charged with "offence~code" - "outcome


/* =======================================================================
   Investigation -- the overarching case file: the incidents, people,
   organisations and relationships that together make up the picture
   of the suspected criminal enterprise.
   ======================================================================= */
::class Investigation public subclass Entity

::attribute caseNumber unguarded
::attribute title unguarded
::attribute leadOfficer unguarded
::attribute openedDate unguarded
::attribute status unguarded             -- OPEN, ACTIVE, DORMANT, CLOSED
::attribute incidents unguarded          -- .array of Incident
::attribute persons unguarded            -- .array of Person
::attribute organisations unguarded      -- .array of Organisation / Company / CriminalEnterprise
::attribute relationships unguarded      -- .array of Relationship
::attribute sightings unguarded          -- .array of Sighting
::attribute mediaReferences unguarded    -- .array of MediaReference
::attribute reports unguarded            -- .array of Report / ExternalReport / ExternalIntelligence

::method init
  expose caseNumber title leadOfficer openedDate status incidents persons organisations relationships sightings mediaReferences reports
  self~init:super
  use arg caseNumber, title = ""
  leadOfficer = ""
  openedDate = date('S')
  status = "OPEN"
  incidents = .array~new
  persons = .array~new
  organisations = .array~new
  relationships = .array~new
  sightings = .array~new
  mediaReferences = .array~new
  reports = .array~new
  return

::method addIncident
  expose incidents
  use arg anIncident
  incidents~append(anIncident)
  return self

::method addPerson
  expose persons
  use arg aPerson
  if self~knowsPerson(aPerson) then return self
  persons~append(aPerson)
  return self

::method knowsPerson
  expose persons
  use arg aPerson
  do knownPerson over persons
    if knownPerson~id = aPerson~id then return .true
  end
  return .false

::method addOrganisation
  expose organisations
  use arg anOrganisation
  organisations~append(anOrganisation)
  return self

::method addRelationship
  expose relationships
  use arg aRelationship
  relationships~append(aRelationship)
  return self

::method addSighting
  expose sightings
  use arg aSighting
  sightings~append(aSighting)
  return self

::method addMediaReference
  expose mediaReferences
  use arg aMediaReference
  mediaReferences~append(aMediaReference)
  return self

::method addReport
  expose reports
  use arg aReport
  reports~append(aReport)
  return self

::method allSuspects
  expose incidents
  suspectRegister = .array~new
  do anIncident over incidents
    do aSuspect over anIncident~suspects
      alreadyRegistered = .false
      do registeredSuspect over suspectRegister
        if registeredSuspect~id = aSuspect~id then alreadyRegistered = .true
      end
      if alreadyRegistered = .false then suspectRegister~append(aSuspect)
    end
  end
  return suspectRegister

::method string
  expose caseNumber title status
  return "Case "caseNumber" - "title" ("status")"


/* =========================================================================
   Worked example (comment only -- nothing below this point executes).

   suspect1 = .Person~new("Jamie", "Docherty", "1988-04-11")
   suspect1~occupation = "unemployed"
   home1 = .Address~new("Glasgow", "GB")
   home1~line1 = "14 Blythswood Court"
   home1~postcode = "G2 7LX"
   suspect1~addAddress(home1)
   suspect1~addRole("SUSPECT")

   victim1 = .Person~new("Alan", "Reid")
   victim1~addRole("VICTIM")

   frontCompany = .Company~new("Riverside Vehicle Storage Ltd", "SC123456", "GB")
   frontCompany~companyType = "LTD"
   frontCompany~addDirector(suspect1)

   gang = .CriminalEnterprise~new("Unnamed East End Network", "GB")
   gang~structureType = "HIERARCHY"
   gang~addMember(suspect1, "LEADER")
   gang~addSuspectedActivity("DRUGS_SUPPLY")
   gang~addSuspectedActivity("MONEY_LAUNDERING")

   knife = .Weapon~new("BLADE", "Kitchen knife, approx 20cm blade")
   knife~forensicReference = "FR/2026/00417"

   scene = .Location~new("Glasgow", "GB")
   scene~venueName = "Riverside Vehicle Storage lock-up 4"
   scene~venueType = "LOCK_UP"

   assaultOffence = .Offence~new("OAPA1861 S18", "Offences Against the Person Act 1861")
   assaultOffence~shortDescription = "Wounding with intent to cause GBH"
   assaultOffence~category = "VIOLENT"
   assaultOffence~triable = "INDICTABLE"

   incident1 = .Incident~new("GL/2026/0442", "2026-06-14 22:40")
   incident1~location = scene
   incident1~narrative = "Reported altercation at lock-up, victim found with stab wound."
   incident1~addPerson(suspect1, "SUSPECT")
   incident1~addPerson(victim1, "VICTIM")
   incident1~addOffence(assaultOffence)
   incident1~addWeapon(knife)

   charge1 = .Charge~new(suspect1, assaultOffence, incident1)

   theCase = .Investigation~new("STRATH/2026/0091", "Operation Riverside")
   theCase~leadOfficer = "DS Fiona MacRae"
   theCase~addIncident(incident1)
   theCase~addPerson(suspect1)
   theCase~addPerson(victim1)
   theCase~addOrganisation(frontCompany)
   theCase~addOrganisation(gang)

   say theCase~string
   say incident1~string
   do aSuspect over theCase~allSuspects
     say "  suspect: "aSuspect~string
   end
========================================================================= */
