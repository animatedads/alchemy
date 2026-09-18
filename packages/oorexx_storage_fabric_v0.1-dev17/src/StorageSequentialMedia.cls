/* Sequential/record-media contract for Storage Fabric.
 *
 * Canonical media semantics live above host files and below emulator/device
 * semantics.  A card, printed line, tape block, filemark or page boundary is
 * retained as a logical record so import/export is bidirectional without
 * pretending that every medium is an undifferentiated byte stream.
 */

::class StorageSequentialMediaBuild public
::constant VERSION "0.1-dev17"
::constant API "storage.fabric.sequential-media/0.1"

::class StorageSequentialMediaFamily public
::constant CARD_DECK "CARD_DECK"
::constant PAPER_LISTING "PAPER_LISTING"
::constant TAPE_VOLUME "TAPE_VOLUME"

::class StorageSequentialMediaRecordKind public
::constant DATA "DATA"
::constant FILEMARK "FILEMARK"
::constant PAGE_BREAK "PAGE_BREAK"

::class StorageSequentialMediaEncoding public
::constant ASCII "ASCII"
::constant EBCDIC "EBCDIC"
::constant BINARY "BINARY"
::constant UNKNOWN "UNKNOWN"

::class StorageSequentialMediaRecord public
::attribute ordinal get
::attribute kind get
::attribute data get
::attribute metadata get
::method init
  expose ordinal kind data metadata
  use arg ordinalArg, kindArg, dataArg="", metadataArg=.nil
  ordinal=ordinalArg+0
  kind=kindArg~string~strip~upper
  data=dataArg~string
  if metadataArg==.nil then metadata=.directory~new
  else metadata=metadataArg
  if ordinal<1 then raise syntax 88.900 array("media record ordinal must be positive")
  if kind<>.StorageSequentialMediaRecordKind~DATA & kind<>.StorageSequentialMediaRecordKind~FILEMARK & kind<>.StorageSequentialMediaRecordKind~PAGE_BREAK then
    raise syntax 88.900 array("invalid sequential media record kind")
  if kind<>.StorageSequentialMediaRecordKind~DATA & data<>"" then
    raise syntax 88.900 array("boundary records cannot carry data")
::method sizeBytes
  expose data
  return data~length

::class StorageSequentialMediaImage public
::attribute mediaId get
::attribute family get
::attribute encoding get
::attribute fixedRecordBytes get
::attribute sourceRef get
::attribute records get
::attribute metadata get
::method init
  expose mediaId family encoding fixedRecordBytes sourceRef records metadata
  use arg mediaIdArg, familyArg, encodingArg="UNKNOWN", fixedRecordBytesArg=0, sourceRefArg=.nil, metadataArg=.nil
  mediaId=mediaIdArg~string~strip
  family=familyArg~string~strip~upper
  encoding=encodingArg~string~strip~upper
  fixedRecordBytes=fixedRecordBytesArg+0
  sourceRef=sourceRefArg
  records=.array~new
  if metadataArg==.nil then metadata=.directory~new
  else metadata=metadataArg
  if mediaId="" then raise syntax 88.900 array("sequential media id is mandatory")
  if family<>.StorageSequentialMediaFamily~CARD_DECK & family<>.StorageSequentialMediaFamily~PAPER_LISTING & family<>.StorageSequentialMediaFamily~TAPE_VOLUME then
    raise syntax 88.900 array("invalid sequential media family")
  if fixedRecordBytes<0 then raise syntax 88.900 array("invalid fixed record size")
::method addData
  expose records fixedRecordBytes
  use arg dataArg, metadataArg=.nil
  d=dataArg~string
  if fixedRecordBytes>0 & d~length<>fixedRecordBytes then
    raise syntax 88.900 array("data record does not match fixed media width")
  records~append(.StorageSequentialMediaRecord~new(records~items+1,.StorageSequentialMediaRecordKind~DATA,d,metadataArg))
  return self
::method addFilemark
  expose records family
  if family<>.StorageSequentialMediaFamily~TAPE_VOLUME then raise syntax 88.900 array("filemarks are valid only for tape media")
  records~append(.StorageSequentialMediaRecord~new(records~items+1,.StorageSequentialMediaRecordKind~FILEMARK))
  return self
::method addPageBreak
  expose records family
  if family<>.StorageSequentialMediaFamily~PAPER_LISTING then raise syntax 88.900 array("page breaks are valid only for paper/listing media")
  records~append(.StorageSequentialMediaRecord~new(records~items+1,.StorageSequentialMediaRecordKind~PAGE_BREAK))
  return self
::method dataRecordCount
  expose records
  n=0
  do r over records
    if r~kind=.StorageSequentialMediaRecordKind~DATA then n+=1
  end
  return n
::method boundaryCount
  expose records
  n=0
  do r over records
    if r~kind<>.StorageSequentialMediaRecordKind~DATA then n+=1
  end
  return n

/* Card decks are canonical fixed-width cards.  Text import is explicit and
 * strict: over-width cards fail unless the caller deliberately permits
 * truncation.  This prevents an emulator convenience from silently changing
 * source material. */
::class StorageCardDeckCodec public
::method newDeck class
  use arg mediaIdArg, encodingArg="ASCII", widthArg=80, sourceRefArg=.nil
  return .StorageSequentialMediaImage~new(mediaIdArg,.StorageSequentialMediaFamily~CARD_DECK,encodingArg,widthArg,sourceRefArg)
::method addTextCard class
  use arg deckArg, lineArg, truncateArg=.false
  if deckArg==.nil | deckArg~family<>.StorageSequentialMediaFamily~CARD_DECK then raise syntax 88.900 array("card deck required")
  width=deckArg~fixedRecordBytes
  line=lineArg~string
  if line~length>width then do
    if truncateArg<>.true then raise syntax 88.900 array("card text exceeds fixed width")
    line=line~substr(1,width)
  end
  if line~length<width then line=line||copies(" ",width-line~length)
  deckArg~addData(line)
  return deckArg
::method fromFixedBytes class
  use arg mediaIdArg, bytesArg, widthArg=80, encodingArg="EBCDIC", autopadArg=.false, sourceRefArg=.nil
  bytes=bytesArg~string; width=widthArg+0
  if width<1 then raise syntax 88.900 array("card width must be positive")
  rem=bytes~length//width
  if rem<>0 then do
    if autopadArg<>.true then raise syntax 88.900 array("fixed card image is not a multiple of card width")
    bytes=bytes||copies(" ",width-rem)
  end
  deck=.StorageCardDeckCodec~newDeck(mediaIdArg,encodingArg,width,sourceRefArg)
  p=1
  do while p<=bytes~length
    deck~addData(bytes~substr(p,width)); p+=width
  end
  return deck
::method toFixedBytes class
  use arg deckArg
  if deckArg==.nil | deckArg~family<>.StorageSequentialMediaFamily~CARD_DECK then raise syntax 88.900 array("card deck required")
  out=""
  do r over deckArg~records
    if r~kind<>.StorageSequentialMediaRecordKind~DATA then raise syntax 88.900 array("card deck contains non-card boundary")
    out=out||r~data
  end
  return out
::method toAsciiLines class
  use arg deckArg, lineEndingArg="0A"x, trimRightArg=.true
  if deckArg==.nil | deckArg~family<>.StorageSequentialMediaFamily~CARD_DECK then raise syntax 88.900 array("card deck required")
  out=""; first=.true
  do r over deckArg~records
    line=r~data
    if trimRightArg==.true then line=line~strip("T")
    if \first then out=out||lineEndingArg
    out=out||line; first=.false
  end
  if deckArg~records~items>0 then out=out||lineEndingArg
  return out

::class StoragePaperListingCodec public
::method newListing class
  use arg mediaIdArg, encodingArg="ASCII", sourceRefArg=.nil
  return .StorageSequentialMediaImage~new(mediaIdArg,.StorageSequentialMediaFamily~PAPER_LISTING,encodingArg,0,sourceRefArg)
::method addLine class
  use arg listingArg, lineArg
  if listingArg==.nil | listingArg~family<>.StorageSequentialMediaFamily~PAPER_LISTING then raise syntax 88.900 array("paper listing required")
  listingArg~addData(lineArg~string)
  return listingArg
::method pageBreak class
  use arg listingArg
  listingArg~addPageBreak
  return listingArg
::method toAscii class
  use arg listingArg, lineEndingArg="0A"x, formFeedArg="0C"x
  if listingArg==.nil | listingArg~family<>.StorageSequentialMediaFamily~PAPER_LISTING then raise syntax 88.900 array("paper listing required")
  out=""
  do r over listingArg~records
    if r~kind=.StorageSequentialMediaRecordKind~DATA then out=out||r~data||lineEndingArg
    else if r~kind=.StorageSequentialMediaRecordKind~PAGE_BREAK then out=out||formFeedArg
    else raise syntax 88.900 array("paper listing contains invalid record")
  end
  return out

::class StorageTapeVolumeCodec public
::method newVolume class
  use arg mediaIdArg, encodingArg="BINARY", sourceRefArg=.nil
  return .StorageSequentialMediaImage~new(mediaIdArg,.StorageSequentialMediaFamily~TAPE_VOLUME,encodingArg,0,sourceRefArg)
::method addBlock class
  use arg tapeArg, blockArg, metadataArg=.nil
  if tapeArg==.nil | tapeArg~family<>.StorageSequentialMediaFamily~TAPE_VOLUME then raise syntax 88.900 array("tape volume required")
  tapeArg~addData(blockArg~string,metadataArg)
  return tapeArg
::method filemark class
  use arg tapeArg
  tapeArg~addFilemark
  return tapeArg

/* Edge-format declaration for a device adapter.  It states what must be
 * rendered/consumed without making Hercules (or any emulator) part of the
 * Storage engine. */
::class StorageSequentialMediaAdapterPlan public
::attribute provider get
::attribute deviceFamily get
::attribute externalFormat get
::attribute direction get
::attribute mediaImage get
::attribute target get
::method init
  expose provider deviceFamily externalFormat direction mediaImage target
  use arg providerArg, deviceFamilyArg, formatArg, directionArg, imageArg, targetArg=""
  provider=providerArg~string~strip
  deviceFamily=deviceFamilyArg~string~strip~upper
  externalFormat=formatArg~string~strip~upper
  direction=directionArg~string~strip~upper
  mediaImage=imageArg
  target=targetArg~string
  if provider="" | deviceFamily="" | externalFormat="" | mediaImage==.nil then raise syntax 88.900 array("media adapter plan is incomplete")
  if direction<>"IN" & direction<>"OUT" & direction<>"BIDIRECTIONAL" then raise syntax 88.900 array("invalid media adapter direction")