/* IBM370Media.cls - external immutable CKD/CCKD media boundary.
 *
 * Historical disk images are referenced, never embedded in the emulator or
 * checkpoint.  This reader implements the Hercules CCKD container needed by
 * Jay Maynard's MVTRES volume, while exposing ordinary CKD records to devices.
 */

::options digits 30

::class IBM370CKDRecord public

::method init
  expose cyl head rec keyHex dataHex
  use strict arg c,h,r,k,d
  cyl=c; head=h; rec=r; keyHex=k~translate; dataHex=d~translate
::method cylinder; expose cyl; return cyl
::method head; expose head; return head
::method record; expose rec; return rec
::method keyHex; expose keyHex; return keyHex
::method dataHex; expose dataHex; return dataHex
::method keyLength; expose keyHex; return keyHex~length%2
::method dataLength; expose dataHex; return dataHex~length%2
::method idHex
  expose cyl head rec
  return d2x(cyl,4)||d2x(head,4)||d2x(rec,2)
::method countHex
  expose cyl head rec keyHex dataHex
  return d2x(cyl,4)||d2x(head,4)||d2x(rec,2)||d2x(keyHex~length%2,2)||d2x(dataHex~length%2,4)
::method recordZeroPayloadHex
  return self~countHex || self~keyHex || self~dataHex


::class IBM370CCKDMedia public

::method init
  expose path mediaId mediaDigest fileData heads trackSize deviceType cylinders numL1 numL2 trackCache recordCache rawTrackCache
  use strict arg imagePath,identity="MVTRES",digest="UNVERIFIED"
  path=imagePath~string; mediaId=identity~string; mediaDigest=digest~string~translate
  sizeText=stream(path,"C","QUERY SIZE")
  if sizeText="" then raise syntax 40.900 array("cannot stat CCKD media",path)
  size=sizeText+0
  if size<2048 then raise syntax 40.900 array("CCKD media too small",path,size)
  s=.stream~new(path); ignored=s~open("READ BINARY")
  if s~state \= "READY" then raise syntax 40.900 array("cannot open CCKD media",path)
  fileData=s~charIn(1,size); ignored=s~close
  if fileData~length \= size then raise syntax 40.900 array("short CCKD media read",path,fileData~length,size)
  if fileData~substr(1,8) \= "CKD_C370" then raise syntax 40.900 array("not Hercules CKD_C370 media",path,c2x(fileData~substr(1,8)))
  heads=self~le32At(8)
  trackSize=self~le32At(12)
  deviceType=c2d(fileData~substr(17,1))
  numL1=self~le32At(512+4)
  numL2=self~le32At(512+8)
  cylinders=self~le32At(512+40)
  if heads<1 | cylinders<1 | numL1<1 | numL2<>256 then raise syntax 40.900 array("unsupported CCKD geometry",heads,cylinders,numL1,numL2)
  trackCache=.directory~new; recordCache=.directory~new; rawTrackCache=.directory~new

::method stateSchema; return "IBM370_CCKD_MEDIA_REFERENCE/1"
::method mediaId; expose mediaId; return mediaId
::method mediaDigest; expose mediaDigest; return mediaDigest
::method path; expose path; return path
::method heads; expose heads; return heads
::method cylinders; expose cylinders; return cylinders
::method trackSize; expose trackSize; return trackSize
::method deviceType; expose deviceType; return deviceType

::method trackNumber
  expose heads cylinders
  use strict arg cyl,head
  if \datatype(cyl,"W") | \datatype(head,"W") | cyl<0 | cyl>=cylinders | head<0 | head>=heads then raise syntax 93.900 array("CKD CCHH outside media",cyl,head)
  return cyl*heads+head

::method trackHex
  expose trackCache
  use strict arg cyl,head
  key=cyl||":"||head
  cached=trackCache~at(key); if cached \== .nil then return cached
  raw=self~trackBytes(cyl,head)
  h=c2x(raw)
  trackCache[key]=h
  return h

::method records
  expose recordCache
  use strict arg cyl,head
  key=cyl||":"||head
  cached=recordCache~at(key); if cached \== .nil then return cached
  raw=self~trackBytes(cyl,head)
  if raw~length<5 then raise syntax 40.900 array("short CKD track",cyl,head)
  tc=self~be16(raw,2); th=self~be16(raw,4)
  if tc<>cyl | th<>head then raise syntax 40.900 array("CCKD track header identity mismatch",cyl,head,tc,th)
  out=.array~new
  pos=6
  do while pos+7<=raw~length
    hdr=raw~substr(pos,8)
    if hdr='FFFFFFFFFFFFFFFF'x then leave
    rcyl=self~be16(hdr,1); rhead=self~be16(hdr,3); rec=c2d(hdr~substr(5,1)); klen=c2d(hdr~substr(6,1)); dlen=self~be16(hdr,7)
    need=8+klen+dlen
    if pos+need-1>raw~length then raise syntax 40.900 array("truncated CKD record",cyl,head,rec,klen,dlen)
    keyBytes=raw~substr(pos+8,klen); dataBytes=raw~substr(pos+8+klen,dlen)
    out~append(.IBM370CKDRecord~new(rcyl,rhead,rec,c2x(keyBytes),c2x(dataBytes)))
    pos=pos+need
  end
  recordCache[key]=out
  return out

::method recordByNumber
  use strict arg cyl,head,rec
  do r over self~records(cyl,head)
    if r~record=rec then return r
  end
  return .nil

::method firstRecord
  use strict arg cyl,head
  a=self~records(cyl,head); if a~items=0 then return .nil; return a[1]

::method trackBytes private
  expose fileData heads numL1 numL2 rawTrackCache
  use strict arg cyl,head
  key=cyl||":"||head
  cached=rawTrackCache~at(key); if cached \== .nil then return cached
  trk=self~trackNumber(cyl,head)
  l1x=trk%256; l2x=trk//256
  if l1x>=numL1 then raise syntax 40.900 array("CCKD track has no L1 entry",trk,l1x)
  l1pos=1024+l1x*4
  l2base=self~le32At(l1pos)
  if l2base=x2d("FFFFFFFF") then raise syntax 40.900 array("CCKD shadow-file L1 unsupported",trk)
  if l2base=0 then do
    raw=self~nullTrack(cyl,head); rawTrackCache[key]=raw; return raw
  end
  ent=l2base+l2x*8
  pos=self~le32At(ent); len=self~le16At(ent+4)
  if pos=0 then do
    raw=self~nullTrack(cyl,head); rawTrackCache[key]=raw; return raw
  end
  if len<5 | pos+len>fileData~length then raise syntax 40.900 array("invalid CCKD L2 entry",trk,pos,len)
  img=fileData~substr(pos+1,len)
  first=c2d(img~substr(1,1)); comp=first//4
  hdr=d2c(first-comp)||img~substr(2,4)
  select
    when comp=0 then body=img~substr(6)
    when comp=1 then body=.MySQLDeflate~decompressZlib(img~substr(6))
    otherwise raise syntax 40.900 array("unsupported CCKD track compression",comp,trk)
  end
  raw=hdr||body
  rawTrackCache[key]=raw
  return raw

::method nullTrack private
  use strict arg cyl,head
  /* canonical CKD null track: HA + R0 count/data + empty R1 count + EOT */
  return x2c("00"||d2x(cyl,4)||d2x(head,4)||d2x(cyl,4)||d2x(head,4)||"00000008"||copies("00",8)||d2x(cyl,4)||d2x(head,4)||"01000000FFFFFFFFFFFFFFFF")

::method le16At private
  expose fileData
  use strict arg offset
  b=fileData~substr(offset+1,2)
  return c2d(b~substr(1,1))+c2d(b~substr(2,1))*256
::method le32At private
  expose fileData
  use strict arg offset
  b=fileData~substr(offset+1,4)
  return c2d(b~substr(1,1))+c2d(b~substr(2,1))*256+c2d(b~substr(3,1))*65536+c2d(b~substr(4,1))*16777216
::method be16 private
  use strict arg bytes,pos
  return c2d(bytes~substr(pos,1))*256+c2d(bytes~substr(pos+1,1))


::class IBM370MediaRegistry public
::method init
  expose media
  media=.directory~new
::method register
  expose media
  use strict arg obj
  key=obj~mediaId||":"||obj~mediaDigest
  media[key]=obj
  return obj
::method resolve
  expose media
  use strict arg identity,digest
  obj=media~at(identity||":"||digest)
  if obj==.nil then raise syntax 40.900 array("required IBM media reference unavailable",identity,digest)
  return obj

::requires "MySQLDeflate.cls"
