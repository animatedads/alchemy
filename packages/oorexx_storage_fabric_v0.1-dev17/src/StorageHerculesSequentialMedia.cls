/* Hercules edge adapter for Storage Fabric sequential media.
 *
 * Hercules device-file conventions are deliberately kept here, outside the
 * canonical StorageSequentialMedia model.  The canonical object preserves
 * cards as fixed-width records; this adapter renders/consumes the particular
 * host-file forms used by Hercules card reader and punch devices.
 */

::class StorageHerculesSequentialMediaBuild public
::constant VERSION "0.1-dev17"
::constant API "storage.fabric.hercules-sequential-media/0.1"

::class StorageHerculesCardFormat public
::constant ASCII_LINES "ASCII_LINES"
::constant EBCDIC_FIXED_80 "EBCDIC_FIXED_80"

::class StorageHerculesCardBridge public

/* Render a canonical deck into a Hercules reader file.
 * ASCII_LINES corresponds to Hercules reader option `ascii`.
 * EBCDIC_FIXED_80 corresponds to `ebcdic` and is intentionally translation-
 * free: callers must supply an EBCDIC canonical deck. */
::method exportReaderFile class
  use arg deckArg, pathArg, formatArg="ASCII_LINES", crlfArg=.false
  validated=self~validateDeck(deckArg)
  path=pathArg~string
  if path="" then raise syntax 88.900 array("reader path is mandatory")
  format=formatArg~string~strip~upper

  if format=.StorageHerculesCardFormat~ASCII_LINES then do
    if deckArg~encoding<>.StorageSequentialMediaEncoding~ASCII then
      raise syntax 88.900 array("ASCII Hercules reader export requires an ASCII canonical deck")
    if crlfArg==.true then eol="0D0A"x
    else eol="0A"x
    payload=.StorageCardDeckCodec~toAsciiLines(deckArg,eol,.true)
  end
  else if format=.StorageHerculesCardFormat~EBCDIC_FIXED_80 then do
    if deckArg~fixedRecordBytes<>80 then raise syntax 88.900 array("Hercules EBCDIC card image requires 80-byte cards")
    if deckArg~encoding<>.StorageSequentialMediaEncoding~EBCDIC then
      raise syntax 88.900 array("EBCDIC Hercules reader export requires an EBCDIC canonical deck")
    payload=.StorageCardDeckCodec~toFixedBytes(deckArg)
  end
  else raise syntax 88.900 array("unsupported Hercules reader format")

  written=self~writeWholeFile(path,payload)
  return path

/* Import a Hercules 3525 punch file into a canonical card deck.
 * Hercules ASCII punch output removes trailing blanks; import restores the
 * fixed-width canonical 80-column card representation. */
::method importPunchFile class
  use arg mediaIdArg, pathArg, formatArg="ASCII_LINES", sourceRefArg=.nil
  path=pathArg~string
  if path="" then raise syntax 88.900 array("punch path is mandatory")
  payload=self~readWholeFile(path)
  return self~importPunchBytes(mediaIdArg,payload,formatArg,sourceRefArg)

::method importPunchBytes class
  use arg mediaIdArg, payloadArg, formatArg="ASCII_LINES", sourceRefArg=.nil
  format=formatArg~string~strip~upper
  payload=payloadArg~string

  if format=.StorageHerculesCardFormat~ASCII_LINES then do
    deck=.StorageCardDeckCodec~newDeck(mediaIdArg,.StorageSequentialMediaEncoding~ASCII,80,sourceRefArg)
    lines=self~splitAsciiCardLines(payload)
    do line over lines
      if line~length>80 then raise syntax 88.900 array("Hercules ASCII punch record exceeds 80 columns")
      x=.StorageCardDeckCodec~addTextCard(deck,line,.false)
    end
    return deck
  end

  if format=.StorageHerculesCardFormat~EBCDIC_FIXED_80 then
    return .StorageCardDeckCodec~fromFixedBytes(mediaIdArg,payload,80,.StorageSequentialMediaEncoding~EBCDIC,.false,sourceRefArg)

  raise syntax 88.900 array("unsupported Hercules punch format")

/* Generate conservative Hercules configuration fragments.  File paths with
 * whitespace/control characters are rejected rather than trying to invent
 * Hercules quoting rules at this layer. */
::method readerConfig class
  use arg addressArg, pathArg, formatArg="ASCII_LINES", eofModeArg="eof"
  address=addressArg~string~strip
  path=self~safeConfigPath(pathArg)
  format=formatArg~string~strip~upper
  eofMode=eofModeArg~string~strip~lower
  if address="" then raise syntax 88.900 array("Hercules reader address is mandatory")
  if eofMode<>"eof" & eofMode<>"intrq" then raise syntax 88.900 array("invalid Hercules reader EOF mode")
  if format=.StorageHerculesCardFormat~ASCII_LINES then option="ascii"
  else if format=.StorageHerculesCardFormat~EBCDIC_FIXED_80 then option="ebcdic"
  else raise syntax 88.900 array("unsupported Hercules reader format")
  return address||" 3505 "||path||" "||option||" "||eofMode

::method punchConfig class
  use arg addressArg, pathArg, formatArg="ASCII_LINES", crlfArg=.false
  address=addressArg~string~strip
  path=self~safeConfigPath(pathArg)
  format=formatArg~string~strip~upper
  if address="" then raise syntax 88.900 array("Hercules punch address is mandatory")
  if format=.StorageHerculesCardFormat~ASCII_LINES then do
    out=address||" 3525 "||path||" ascii"
    if crlfArg==.true then out=out||" crlf"
    return out
  end
  if format=.StorageHerculesCardFormat~EBCDIC_FIXED_80 then return address||" 3525 "||path
  raise syntax 88.900 array("unsupported Hercules punch format")

::method validateDeck class private
  use arg deckArg
  if deckArg==.nil | deckArg~family<>.StorageSequentialMediaFamily~CARD_DECK then
    raise syntax 88.900 array("canonical card deck required")
  if deckArg~fixedRecordBytes<>80 then
    raise syntax 88.900 array("Hercules card devices require 80-column canonical cards")
  return .true

::method safeConfigPath class private
  use arg pathArg
  path=pathArg~string
  if path="" then raise syntax 88.900 array("Hercules device path is mandatory")
  if path~pos(" ")>0 | path~pos("09"x)>0 | path~pos("0A"x)>0 | path~pos("0D"x)>0 then
    raise syntax 88.900 array("Hercules device path must not contain whitespace")
  return path

::method splitAsciiCardLines class private
  use arg payloadArg
  payload=payloadArg~string
  lines=.array~new
  if payload="" then return lines
  normalized=payload~changestr("0D0A"x,"0A"x)~changestr("0D"x,"0A"x)
  start=1
  do forever
    p=normalized~pos("0A"x,start)
    if p=0 then do
      lines~append(normalized~substr(start))
      leave
    end
    lines~append(normalized~substr(start,p-start))
    start=p+1
    if start>normalized~length then leave
  end
  return lines

::method writeWholeFile class private
  use arg pathArg, payloadArg
  path=pathArg~string; payload=payloadArg~string
  call stream path,"c","open write replace"
  unwritten=charout(path,payload)
  call stream path,"c","close"
  if unwritten<>0 then raise syntax 88.900 array("short write while exporting Hercules media file")
  return payload~length

::method readWholeFile class private
  use arg pathArg
  path=pathArg~string
  call stream path,"c","open read"
  size=stream(path,"c","query size")+0
  if size>0 then payload=charin(path,1,size)
  else payload=""
  call stream path,"c","close"
  return payload



/* Hercules 1403/3211 printer-file adapter.
 *
 * Hercules has already interpreted printer carriage-control CCWs before this
 * file reaches us: host output is variable ASCII lines and form-feed page
 * boundaries, with trailing blanks removed.  Therefore canonical Storage can
 * preserve the observable paper/listing structure, but MUST NOT claim to
 * recover the guest's original carriage-control commands or trailing blanks.
 */
::class StorageHerculesPrinterBridge public
::method importPrinterFile class
  use arg mediaIdArg, pathArg, sourceRefArg=.nil
  path=pathArg~string
  if path="" then raise syntax 88.900 array("printer path is mandatory")
  payload=self~readWholeFile(path)
  return self~importPrinterBytes(mediaIdArg,payload,sourceRefArg)

::method importPrinterBytes class
  use arg mediaIdArg, payloadArg, sourceRefArg=.nil
  listing=.StoragePaperListingCodec~newListing(mediaIdArg,.StorageSequentialMediaEncoding~ASCII,sourceRefArg)
  payload=payloadArg~string~changestr("0D0A"x,"0A"x)~changestr("0D"x,"0A"x)
  buf=""
  do i=1 to payload~length
    ch=payload~substr(i,1)
    if ch="0C"x then do
      /* A form feed is a page boundary.  Preserve any unterminated text
       * immediately before it as a line, but do not invent a blank line. */
      if buf<>"" then do
        .StoragePaperListingCodec~addLine(listing,buf)
        buf=""
      end
      .StoragePaperListingCodec~pageBreak(listing)
    end
    else if ch="0A"x then do
      /* Empty buffer is a real blank printed line. */
      .StoragePaperListingCodec~addLine(listing,buf)
      buf=""
    end
    else buf=buf||ch
  end
  if buf<>"" then .StoragePaperListingCodec~addLine(listing,buf)
  return listing

::method exportListingFile class
  use arg listingArg, pathArg, crlfArg=.false
  if listingArg==.nil | listingArg~family<>.StorageSequentialMediaFamily~PAPER_LISTING then
    raise syntax 88.900 array("canonical paper listing required")
  path=pathArg~string
  if path="" then raise syntax 88.900 array("listing path is mandatory")
  if listingArg~encoding<>.StorageSequentialMediaEncoding~ASCII then
    raise syntax 88.900 array("Hercules printer projection requires an ASCII canonical listing")
  if crlfArg==.true then eol="0D0A"x
  else eol="0A"x
  payload=.StoragePaperListingCodec~toAscii(listingArg,eol,"0C"x)
  x=self~writeWholeFile(path,payload)
  return path

::method printerConfig class
  use arg addressArg, pathArg, deviceTypeArg="1403", crlfArg=.false, noclearArg=.false
  address=addressArg~string~strip
  path=self~safeConfigPath(pathArg)
  device=deviceTypeArg~string~strip~upper
  if address="" then raise syntax 88.900 array("Hercules printer address is mandatory")
  if device<>"1403" & device<>"3211" then raise syntax 88.900 array("unsupported Hercules printer device")
  out=address||" "||device||" "||path
  if crlfArg==.true then out=out||" crlf"
  if noclearArg==.true then out=out||" noclear"
  return out

::method safeConfigPath class private
  use arg pathArg
  path=pathArg~string
  if path="" then raise syntax 88.900 array("Hercules device path is mandatory")
  if path~pos(" ")>0 | path~pos("09"x)>0 | path~pos("0A"x)>0 | path~pos("0D"x)>0 then
    raise syntax 88.900 array("Hercules device path must not contain whitespace")
  return path

::method writeWholeFile class private
  use arg pathArg, payloadArg
  path=pathArg~string; payload=payloadArg~string
  call stream path,"c","open write replace"
  unwritten=charout(path,payload)
  call stream path,"c","close"
  if unwritten<>0 then raise syntax 88.900 array("short write while exporting Hercules printer media")
  return payload~length

::method readWholeFile class private
  use arg pathArg
  path=pathArg~string
  call stream path,"c","open read"
  size=stream(path,"c","query size")+0
  if size>0 then payload=charin(path,1,size)
  else payload=""
  call stream path,"c","close"
  return payload

/* AWSTAPE codec.
 *
 * AWS is an edge representation, not canonical tape identity.  A physical
 * AWS segment has a six-byte header:
 *   current segment length  (U16 little endian)
 *   previous segment length (U16 little endian)
 *   flags1
 *   flags2
 * Logical records may span several <=65535-byte segments.  NEWREC and ENDREC
 * delimit the logical block; TAPEMARK represents a canonical filemark.
 */
::class StorageHerculesAwsTapeCodec public
::constant FLAG_NEWREC 128
::constant FLAG_TAPEMARK 64
::constant FLAG_ENDREC 32
::constant MAX_SEGMENT 65535

::method toBytes class
  use arg tapeArg, maxSegmentArg=65535
  self~validateTape(tapeArg)
  maxseg=maxSegmentArg+0
  if maxseg<1 | maxseg>65535 then raise syntax 88.900 array("invalid AWSTAPE segment size")
  out=""; prevlen=0
  do r over tapeArg~records
    if r~kind=.StorageSequentialMediaRecordKind~FILEMARK then do
      out=out||self~header(0,prevlen,self~FLAG_TAPEMARK,0)
      prevlen=0
    end
    else if r~kind=.StorageSequentialMediaRecordKind~DATA then do
      data=r~data
      /* A zero-length DATA record is distinct from a filemark canonically, but
       * AWSTAPE cannot represent that distinction: a zero current length is a
       * tape mark.  Fail closed rather than aliasing the two meanings. */
      if data~length=0 then raise syntax 88.900 array("AWSTAPE cannot represent an empty data block distinctly from a tape mark")
      pos=1; first=.true
      do while pos<=data~length
        seglen=data~length-pos+1
        if seglen>maxseg then seglen=maxseg
        flags=0
        if first then flags=flags+self~FLAG_NEWREC
        if pos+seglen-1=data~length then flags=flags+self~FLAG_ENDREC
        out=out||self~header(seglen,prevlen,flags,0)||data~substr(pos,seglen)
        prevlen=seglen
        pos+=seglen; first=.false
      end
    end
    else raise syntax 88.900 array("invalid canonical record in tape volume")
  end
  return out

::method fromBytes class
  use arg mediaIdArg, bytesArg, sourceRefArg=.nil
  bytes=bytesArg~string
  tape=.StorageTapeVolumeCodec~newVolume(mediaIdArg,.StorageSequentialMediaEncoding~BINARY,sourceRefArg)
  pos=1; prevlen=0; inrec=.false; record=""
  do while pos<=bytes~length
    if bytes~length-pos+1<6 then raise syntax 88.900 array("truncated AWSTAPE header")
    cur=self~u16le(bytes~substr(pos,2))
    prv=self~u16le(bytes~substr(pos+2,2))
    flags=c2d(bytes~substr(pos+4,1))
    flags2=c2d(bytes~substr(pos+5,1))
    pos+=6
    if prv<>prevlen then raise syntax 88.900 array("AWSTAPE previous-segment length chain mismatch")
    if flags2<>0 then raise syntax 88.900 array("unsupported AWSTAPE flags2 value")
    known=self~FLAG_NEWREC+self~FLAG_TAPEMARK+self~FLAG_ENDREC
    /* Reject unknown bits without relying on arithmetic bit tricks. */
    unknown=c2d(bitand(d2c(flags,1),d2c(255-known,1)))
    if unknown<>0 then raise syntax 88.900 array("unsupported AWSTAPE flags1 bits")

    if c2d(bitand(d2c(flags,1),d2c(self~FLAG_TAPEMARK,1)))<>0 then do
      if cur<>0 then raise syntax 88.900 array("AWSTAPE tape mark has non-zero length")
      if inrec then raise syntax 88.900 array("AWSTAPE tape mark interrupts a logical record")
      .StorageTapeVolumeCodec~filemark(tape)
      prevlen=0
      iterate
    end

    if cur=0 then raise syntax 88.900 array("AWSTAPE zero-length segment without tape mark")
    if bytes~length-pos+1<cur then raise syntax 88.900 array("truncated AWSTAPE data segment")
    isnew=c2d(bitand(d2c(flags,1),d2c(self~FLAG_NEWREC,1)))<>0
    isend=c2d(bitand(d2c(flags,1),d2c(self~FLAG_ENDREC,1)))<>0
    if isnew then do
      if inrec then raise syntax 88.900 array("AWSTAPE NEWREC encountered before prior ENDREC")
      record=""; inrec=.true
    end
    else if \inrec then raise syntax 88.900 array("AWSTAPE continuation segment without NEWREC")
    record=record||bytes~substr(pos,cur)
    pos+=cur
    prevlen=cur
    if isend then do
      .StorageTapeVolumeCodec~addBlock(tape,record)
      record=""; inrec=.false
    end
  end
  if inrec then raise syntax 88.900 array("AWSTAPE logical record missing ENDREC")
  return tape

::method exportFile class
  use arg tapeArg, pathArg, maxSegmentArg=65535
  path=pathArg~string
  if path="" then raise syntax 88.900 array("AWSTAPE path is mandatory")
  payload=self~toBytes(tapeArg,maxSegmentArg)
  call stream path,"c","open write replace"
  unwritten=charout(path,payload)
  call stream path,"c","close"
  if unwritten<>0 then raise syntax 88.900 array("short write while exporting AWSTAPE")
  return path

::method importFile class
  use arg mediaIdArg, pathArg, sourceRefArg=.nil
  path=pathArg~string
  if path="" then raise syntax 88.900 array("AWSTAPE path is mandatory")
  call stream path,"c","open read"
  size=stream(path,"c","query size")+0
  if size>0 then payload=charin(path,1,size)
  else payload=""
  call stream path,"c","close"
  return self~fromBytes(mediaIdArg,payload,sourceRefArg)

::method tapeConfig class
  use arg addressArg, pathArg, deviceTypeArg="3420"
  address=addressArg~string~strip
  device=deviceTypeArg~string~strip~upper
  path=pathArg~string
  if address="" then raise syntax 88.900 array("Hercules tape address is mandatory")
  if path="" then raise syntax 88.900 array("Hercules tape path is mandatory")
  if path~pos(" ")>0 | path~pos("09"x)>0 | path~pos("0A"x)>0 | path~pos("0D"x)>0 then
    raise syntax 88.900 array("Hercules tape path must not contain whitespace")
  return address||" "||device||" "||path

::method validateTape class private
  use arg tapeArg
  if tapeArg==.nil | tapeArg~family<>.StorageSequentialMediaFamily~TAPE_VOLUME then
    raise syntax 88.900 array("canonical tape volume required")
  return .true

::method header class private
  use arg curArg, prevArg, flags1Arg, flags2Arg
  return self~le16(curArg)||self~le16(prevArg)||d2c(flags1Arg,1)||d2c(flags2Arg,1)

::method le16 class private
  use arg nArg
  n=nArg+0
  if n<0 | n>65535 then raise syntax 88.900 array("AWSTAPE 16-bit value out of range")
  return d2c(n//256,1)||d2c(n%256,1)

::method u16le class private
  use arg twoArg
  two=twoArg~string
  if two~length<>2 then raise syntax 88.900 array("AWSTAPE halfword requires two bytes")
  return c2d(two~substr(1,1)) + 256*c2d(two~substr(2,1))

::requires "StorageSequentialMedia.cls"