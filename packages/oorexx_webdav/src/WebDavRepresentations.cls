/* WebDAV representation bridge for Storage Fabric sequential media dev16. */
::class WebDavRepresentationResult public
::attribute body get
::attribute contentType get
::attribute length get
::method init
  expose body contentType length
  use arg bodyArg, typeArg='application/octet-stream'
  body=bodyArg~string; contentType=typeArg~string; length=body~length

::class WebDavSequentialMediaRepository public
::method init
  expose images
  images=.directory~new
::method put
  expose images
  use arg objectIdArg, imageArg
  images[objectIdArg~string]=imageArg
  return imageArg
::method get
  expose images
  use arg objectIdArg
  return images[objectIdArg~string]

::class WebDavRepresentationRegistry public
::method init
  expose mediaRepo
  use arg mediaRepoArg=.nil
  if mediaRepoArg==.nil then mediaRepo=.WebDavSequentialMediaRepository~new; else mediaRepo=mediaRepoArg
::method register
  expose mediaRepo
  use arg refArg, imageArg
  mediaRepo~put(refArg~objectId,imageArg)
  return self
::method imageFor
  expose mediaRepo
  use arg objectArg
  if objectArg==.nil then return .nil
  return mediaRepo~get(objectArg~ref~objectId)
::method render
  use arg objectArg, acceptArg=''
  if objectArg==.nil then return .nil
  family=objectArg~eaValue('storage.media.family','')
  if family='' then return .nil
  image=self~imageFor(objectArg)
  if image==.nil then return .nil
  accept=acceptArg~string~lower
  if family=.StorageSequentialMediaFamily~CARD_DECK then do
    if accept~pos('application/vnd.oorexx.card-deck.ebcdic80')>0 then do
      if image~encoding<>.StorageSequentialMediaEncoding~EBCDIC then return .nil
      return .WebDavRepresentationResult~new(.StorageCardDeckCodec~toFixedBytes(image),'application/vnd.oorexx.card-deck.ebcdic80')
    end
    if image~encoding<>.StorageSequentialMediaEncoding~ASCII then return .nil
    return .WebDavRepresentationResult~new(.StorageCardDeckCodec~toAsciiLines(image),'text/plain; charset=us-ascii')
  end
  if family=.StorageSequentialMediaFamily~PAPER_LISTING then do
    if image~encoding<>.StorageSequentialMediaEncoding~ASCII then return .nil
    return .WebDavRepresentationResult~new(.StoragePaperListingCodec~toAscii(image),'text/plain; charset=us-ascii')
  end
  /* TAPE_VOLUME intentionally has no generic byte rendering. A real HET/AWS
   * codec must register an explicit representation; concatenating blocks would
   * destroy filemark semantics. */
  return .nil
::method import
  use arg mediaIdArg, bodyArg, contentTypeArg
  ct=contentTypeArg~string~lower
  if ct~pos('application/vnd.oorexx.card-deck.ebcdic80')=1 then
    return .StorageCardDeckCodec~fromFixedBytes(mediaIdArg,bodyArg,80,.StorageSequentialMediaEncoding~EBCDIC,.false)
  if ct~pos('application/vnd.oorexx.card-deck.ascii')=1 then return self~importAsciiCards(mediaIdArg,bodyArg)
  if ct~pos('application/vnd.oorexx.paper-listing.ascii')=1 then return self~importAsciiPaper(mediaIdArg,bodyArg)
  return .nil
::method importAsciiCards private
  use arg mediaIdArg, bodyArg
  deck=.StorageCardDeckCodec~newDeck(mediaIdArg,.StorageSequentialMediaEncoding~ASCII,80)
  s=bodyArg~string~changestr('0D0A'x,'0A'x)~changestr('0D'x,'0A'x)
  do while s<>''
    p=s~pos('0A'x)
    if p=0 then do; line=s; s=''; end
    else do; line=s~substr(1,p-1); s=s~substr(p+1); end
    if line='' & s='' then leave
    .StorageCardDeckCodec~addTextCard(deck,line,.false)
  end
  return deck
::method importAsciiPaper private
  use arg mediaIdArg, bodyArg
  listing=.StoragePaperListingCodec~newListing(mediaIdArg,.StorageSequentialMediaEncoding~ASCII)
  s=bodyArg~string~changestr('0D0A'x,'0A'x)~changestr('0D'x,'0A'x)
  buf=''
  do i=1 to s~length
    ch=s~substr(i,1)
    if ch='0C'x then do
      if buf<>'' then do; .StoragePaperListingCodec~addLine(listing,buf); buf=''; end
      .StoragePaperListingCodec~pageBreak(listing)
    end
    else if ch='0A'x then do
      .StoragePaperListingCodec~addLine(listing,buf); buf=''
    end
    else buf=buf||ch
  end
  if buf<>'' then .StoragePaperListingCodec~addLine(listing,buf)
  return listing
::method canonicalSize
  use arg imageArg
  n=0
  do r over imageArg~records
    if r~kind=.StorageSequentialMediaRecordKind~DATA then n+=r~sizeBytes
  end
  return n
::method canonicalDigest
  use arg imageArg
  /* Deterministic identity includes boundaries, unlike a flattened byte view. */
  a=1; b=0; s=imageArg~family||'|'||imageArg~encoding||'|'||imageArg~fixedRecordBytes||'|'
  do r over imageArg~records
    s=s||r~kind||':'||r~data~length||':'||r~data||'|'
  end
  do i=1 to s~length
    a=(a+c2d(c2x(s~substr(i,1))))//65521; b=(b+a)//65521
  end
  return 'media-adler32-'||b||'-'||a||'-'||s~length
::method decorateStorageObject
  use arg objectArg, imageArg
  objectArg~setEA(.StorageEA~new('storage.media','family',imageArg~family,'STRING','storage.fabric.sequential-media','webdav',''))
  objectArg~setEA(.StorageEA~new('storage.media','encoding',imageArg~encoding,'STRING','storage.fabric.sequential-media','webdav',''))
  objectArg~setEA(.StorageEA~new('storage.media','records',imageArg~dataRecordCount,'INTEGER','storage.fabric.sequential-media','webdav',''))
  objectArg~setEA(.StorageEA~new('storage.media','boundaries',imageArg~boundaryCount,'INTEGER','storage.fabric.sequential-media','webdav',''))
  objectArg~setEA(.StorageEA~new('storage.media','fixedRecordBytes',imageArg~fixedRecordBytes,'INTEGER','storage.fabric.sequential-media','webdav',''))
  return objectArg

::requires 'StorageFabric.cls'
::requires 'StorageSequentialMedia.cls'
