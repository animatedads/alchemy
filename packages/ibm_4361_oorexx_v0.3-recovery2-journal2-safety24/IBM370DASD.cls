/* IBM370DASD.cls - demand-driven IBM 3330 mechanics. */
::options digits 30

::class IBM3330Device subclass IBM370IODevice public
::method init
  expose media cyl head record orientation indexPasses pendingSenseHex
  use strict arg number,mediaObject
  self~init:super(number,"3330")
  if \mediaObject~isA(.IBM370CCKDMedia) then raise syntax 88.900 array("IBM3330Device requires IBM370CCKDMedia")
  media=mediaObject; cyl=0; head=0; record=0; orientation="INDEX"; indexPasses=0; pendingSenseHex=copies("00",24)
::method stateSchema; return "IBM3330_STATE/2"
::method mediaId; expose media; return media~mediaId
::method mediaDigest; expose media; return media~mediaDigest
::method cylinder; expose cyl; return cyl
::method head; expose head; return head
::method record; expose record; return record
::method orientation; expose orientation; return orientation
::method indexPasses; expose indexPasses; return indexPasses
::method pendingSenseHex; expose pendingSenseHex; return pendingSenseHex

::method iplRead24
  expose cyl head record orientation indexPasses
  if \self~online then raise syntax 40.900 array("3330 IPL device offline",d2x(self~deviceNumber,4))
  cyl=0; head=0; record=0; orientation="INDEX"; indexPasses=0
  r=self~nextRecord; if r==.nil then raise syntax 40.900 array("3330 track 0 has no IPL record")
  data=r~dataHex; if data~length<48 then raise syntax 40.900 array("3330 IPL record shorter than 24 bytes",r~record)
  record=r~record; orientation="AFTER_DATA"; return data~left(48)

::method executeCCW
  use strict arg ccw,storage,program=.nil
  cmd=ccw~commandCode
  select
    when cmd=x2d("06") then return self~readData(ccw,storage,program)
    when cmd=x2d("07") then return self~seek(ccw,storage)
    when cmd=x2d("27") then return self~seekSetSector(ccw,storage)
    when cmd=x2d("31") then return self~searchIdEqual(ccw,storage)
    when cmd=x2d("29") | cmd=x2d("49") | cmd=x2d("69") | cmd=x2d("A9") | cmd=x2d("C9") | cmd=x2d("E9") then return self~searchKey(ccw,storage,program)
    when cmd=x2d("12") | cmd=x2d("92") then return self~readCount(ccw,storage,program)
    when cmd=x2d("1A") then return self~readHomeAddress(ccw,storage,program)
    when cmd=x2d("16") then return self~readRecordZero(ccw,storage,program)
    when cmd=x2d("1F") then return self~setFileMask(ccw,storage,program)
    when cmd=x2d("04") then return self~sense(ccw,storage)
    when cmd=x2d("03") then return self~ioResult(0,ccw~count,x2d("0C"),0,"3330 NOP")
    otherwise return self~unitCheck(ccw,"3330 command not implemented "||ccw~commandHex,"8000")
  end

::method multitrackProhibited private
  use strict arg ccw,program
  if program==.nil then return 0
  if ccw~commandCode<128 then return 0
  /* Hercules 2.17.1 CKDMASK_SKCTL_INHSMT = X'18'.  Other non-zero file
   * mask fields do not, by themselves, prohibit multitrack operation. */
  skctl=x2d(c2x(bitand(d2c(program~fileMask),'18'x)))
  return skctl=x2d("18")

::method readData private
  expose record orientation
  use strict arg ccw,storage,program=.nil
  if self~multitrackProhibited(ccw,program) then return self~unitCheck(ccw,"3330 multitrack prohibited by file mask","0004")
  if orientation="AFTER_COUNT" | orientation="AFTER_KEY" then r=self~currentRecord; else r=self~nextRecord
  if r==.nil then return self~unitCheck(ccw,"3330 Read Data found no record","1000")
  data=r~dataHex; moved=ccw~count; if moved>data~length%2 then moved=data~length%2
  if moved>0 & \ccw~skip then storage~storeHex(ccw~dataAddress,data~left(moved*2))
  record=r~record; orientation="AFTER_DATA"; return self~ioResult(moved,ccw~count-moved,x2d("0C"),0,"3330 READ DATA")

::method seek private
  expose media cyl head record orientation indexPasses
  use strict arg ccw,storage
  if ccw~count<6 then return self~unitCheck(ccw,"3330 Seek count shorter than 6","8000")
  h=storage~fetchHex(ccw~dataAddress,6)
  /* BBCCHH = two-byte bin, two-byte cylinder, two-byte head. */
  bin=x2d(h~substr(1,4)); nc=x2d(h~substr(5,4)); nh=x2d(h~substr(9,4))
  if bin<>0 | nc>=media~cylinders | nh>=media~heads then return self~unitCheck(ccw,"3330 Seek outside media","4000")
  cyl=nc; head=nh; record=0; orientation="INDEX"; indexPasses=0
  return self~ioResult(6,ccw~count-6,x2d("0C"),0,"3330 SEEK")

::method seekSetSector private
  use strict arg ccw,storage
  /* 3330 command 27 is accepted by MVT as positioning/sector advice.  The
   * cylinder/head fields are the same leading BBCCHH form when six bytes are
   * supplied; shorter sector-only forms are timing hints in this model. */
  if ccw~count>=6 then return self~seek(ccw,storage)
  return self~ioResult(ccw~count,0,x2d("0C"),0,"3330 SEEK/SET SECTOR")

::method searchIdEqual private
  expose record orientation indexPasses
  use strict arg ccw,storage
  if ccw~count<5 then return self~unitCheck(ccw,"3330 Search ID count shorter than 5","8000")
  wanted=storage~fetchHex(ccw~dataAddress,5)~translate; r=self~nextRecord
  if r==.nil then do; indexPasses=indexPasses+1; record=0; orientation="INDEX"; return self~ioResult(5,ccw~count-5,x2d("0C"),0,"3330 SEARCH ID mismatch at index"); end
  record=r~record; orientation="AFTER_COUNT"
  if r~idHex=wanted then return self~ioResult(5,ccw~count-5,x2d("4C"),0,"3330 SEARCH ID EQUAL")
  return self~ioResult(5,ccw~count-5,x2d("0C"),0,"3330 SEARCH ID mismatch")

::method searchKey private
  expose media cyl head record orientation indexPasses
  use strict arg ccw,storage,program=.nil

  /* Hercules 2.17.1 ckd_read_key(): if we are not already oriented to
   * COUNT, first obtain the next user-data count field.  Repeating Search
   * Key after KEY therefore advances over the current DATA to the next
   * record rather than comparing the same key again. */
  if orientation="AFTER_COUNT" then r=self~currentRecord
  else r=self~nextSearchRecord(ccw,program)
  if r==.nil then do
    /* nextSearchRecord has already established Unit Check where required.
     * A nil without pending sense is a nonmatching index traversal. */
    if self~pendingSenseHex~left(4)<>"0000" then return self~unitCheck(ccw,"3330 SEARCH KEY positioning failure",self~pendingSenseHex~left(4))
    return self~ioResult(0,ccw~count,x2d("0C"),0,"3330 SEARCH KEY no record")
  end

  record=r~record
  orientation="AFTER_KEY"

  key=r~keyHex~translate
  keyBytes=key~length%2
  num=ccw~count
  if num>keyBytes then num=keyBytes
  residual=ccw~count-num

  /* A zero-length key is a normal completion with no comparison. */
  if keyBytes=0 then return self~ioResult(0,ccw~count,x2d("0C"),0,"3330 SEARCH KEY zero-length key")

  wanted=storage~fetchHex(ccw~dataAddress,num)~translate
  actual=key~left(num*2)
  cmp=self~compareHexBytes(actual,wanted)
  base=ccw~commandCode//128
  match=0
  if base=x2d("29") then match=(cmp=0)
  else if base=x2d("49") then match=(cmp>0)
  else if base=x2d("69") then match=(cmp>=0)

  if match then return self~ioResult(num,residual,x2d("4C"),0,"3330 SEARCH KEY match")
  return self~ioResult(num,residual,x2d("0C"),0,"3330 SEARCH KEY mismatch")

::method compareHexBytes private
  use strict arg leftHex,rightHex
  if leftHex=rightHex then return 0
  bytes=leftHex~length%2
  do i=1 to bytes
    l=x2d(leftHex~substr((i-1)*2+1,2)); r=x2d(rightHex~substr((i-1)*2+1,2))
    if l<r then return -1
    if l>r then return 1
  end
  return 0

::method nextSearchRecord private
  expose media cyl head record orientation indexPasses pendingSenseHex
  use strict arg ccw,program=.nil
  r=self~nextRecord
  if r<>.nil then return r

  /* End of track.  Single-track search wraps once to index; a second EOT
   * in the same chain is No Record Found.  Multitrack search advances only
   * within the cylinder and is subject to SFM seek/MT inhibition. */
  mt=(ccw~commandCode>=128)
  if mt then do
    if self~multitrackProhibited(ccw,program) then do
      pendingSenseHex="0004"||copies("00",22)
      return .nil
    end
    if head>=media~heads-1 then do
      pendingSenseHex="0020"||copies("00",22)
      return .nil
    end
    head=head+1; record=0; orientation="INDEX"
    if program<>.nil then program~setIndexMark(0)
    return self~nextRecord
  end

  if program<>.nil & program~indexMark<>0 then do
    pendingSenseHex="0008"||copies("00",22)
    return .nil
  end
  record=0; orientation="INDEX"; indexPasses=indexPasses+1
  if program<>.nil then program~setIndexMark(1)
  return self~nextRecord

::method readCount private
  expose media cyl head record orientation indexPasses pendingSenseHex
  use strict arg ccw,storage,program=.nil

  /* A multitrack READ COUNT is not file-protected merely because its MT bit
   * is set.  Hercules 2.17.1 reads count fields on the current track first;
   * SFM seek/MT inhibition is tested only if EOT requires mt_advance(). */
  r=self~nextCountRecord(ccw,program)
  if r==.nil then do
    if pendingSenseHex~left(4)<>"0000" then return self~unitCheck(ccw,"3330 Read Count positioning failure",pendingSenseHex~left(4))
    return self~unitCheck(ccw,"3330 Read Count found no record","0008")
  end
  h=r~countHex; moved=ccw~count; if moved>8 then moved=8
  if moved>0 & \ccw~skip then storage~storeHex(ccw~dataAddress,h~left(moved*2))
  record=r~record; orientation="AFTER_COUNT"
  return self~ioResult(moved,ccw~count-moved,x2d("0C"),0,"3330 READ COUNT")

::method nextCountRecord private
  expose media cyl head record orientation indexPasses pendingSenseHex
  use strict arg ccw,program=.nil
  r=self~nextRecord
  if r<>.nil then return r

  mt=(ccw~commandCode>=128)
  if mt then do
    if self~multitrackProhibited(ccw,program) then do
      pendingSenseHex="0004"||copies("00",22)
      return .nil
    end
    if head>=media~heads-1 then do
      pendingSenseHex="0020"||copies("00",22)
      return .nil
    end
    head=head+1; record=0; orientation="INDEX"
    if program<>.nil then program~setIndexMark(1)
    return self~nextRecord
  end

  /* Single-track Read Count wraps once at index.  A second EOT in the same
   * command chain is No Record Found, matching Hercules ckdxmark behavior. */
  if program<>.nil & program~indexMark<>0 then do
    pendingSenseHex="0008"||copies("00",22)
    return .nil
  end
  record=0; orientation="INDEX"; indexPasses=indexPasses+1
  if program<>.nil then program~setIndexMark(1)
  return self~nextRecord

::method readHomeAddress private
  expose cyl head record orientation
  use strict arg ccw,storage,program=.nil
  if self~multitrackProhibited(ccw,program) then return self~unitCheck(ccw,"3330 multitrack Read HA prohibited","0004")
  h="00"||d2x(cyl,4)||d2x(head,4); moved=ccw~count; if moved>5 then moved=5
  if moved>0 & \ccw~skip then storage~storeHex(ccw~dataAddress,h~left(moved*2))
  record=0; orientation="INDEX"; if program<>.nil then program~setIndexMark(0)
  return self~ioResult(moved,ccw~count-moved,x2d("0C"),0,"3330 READ HOME ADDRESS")

::method readRecordZero private
  use strict arg ccw,storage,program=.nil
  if self~multitrackProhibited(ccw,program) then return self~unitCheck(ccw,"3330 multitrack Read R0 prohibited","0004")
  r=self~recordZero; if r==.nil then return self~unitCheck(ccw,"3330 record zero absent","1000")
  h=r~recordZeroPayloadHex; moved=ccw~count; if moved>h~length%2 then moved=h~length%2
  if moved>0 & \ccw~skip then storage~storeHex(ccw~dataAddress,h~left(moved*2))
  return self~ioResult(moved,ccw~count-moved,x2d("0C"),0,"3330 READ RECORD ZERO")

::method setFileMask private
  use strict arg ccw,storage,program=.nil
  if program==.nil then return self~unitCheck(ccw,"3330 SFM outside active channel program","8000")
  if ccw~count<1 then return self~unitCheck(ccw,"3330 SFM count zero","8000")
  mask=x2d(storage~fetchHex(ccw~dataAddress,1)); program~setFileMask(mask); program~setIndexMark(0)
  return self~ioResult(1,ccw~count-1,x2d("0C"),0,"3330 SET FILE MASK "||d2x(mask,2))

::method sense private
  expose pendingSenseHex
  use strict arg ccw,storage
  bytes=ccw~count; if bytes>24 then bytes=24
  if bytes>0 & \ccw~skip then storage~storeHex(ccw~dataAddress,pendingSenseHex~left(bytes*2))
  pendingSenseHex=copies("00",24); return self~ioResult(bytes,ccw~count-bytes,x2d("0C"),0,"3330 SENSE")
::method unitCheck private
  expose pendingSenseHex
  use strict arg ccw,detail,sense="8000"
  pendingSenseHex=sense||copies("00",24-(sense~length%2)); return self~ioResult(0,ccw~count,x2d("0E"),0,detail)
::method currentRecord private; expose media cyl head record; if record<=0 then return .nil; return media~recordByNumber(cyl,head,record)
::method recordZero private; expose media cyl head; return media~recordByNumber(cyl,head,0)
::method nextRecord private
  expose media cyl head record
  a=media~records(cyl,head); best=.nil
  do r over a
    if r~record>record then do
      if best==.nil then best=r
      else if r~record<best~record then best=r
    end
  end
  return best
::method state
  expose media cyl head record orientation indexPasses pendingSenseHex
  d=self~state:super; d["mediaId"]=media~mediaId; d["mediaDigest"]=media~mediaDigest; d["cylinder"]=cyl; d["head"]=head; d["record"]=record; d["orientation"]=orientation; d["indexPasses"]=indexPasses; d["pendingSenseHex"]=pendingSenseHex; return d
::method restoreState
  expose media cyl head record orientation indexPasses pendingSenseHex
  use strict arg d
  if d["mediaId"]<>media~mediaId | d["mediaDigest"]<>media~mediaDigest then raise syntax 40.900 array("IBM3330 media identity mismatch")
  self~restoreState:super(d); cyl=d["cylinder"]; head=d["head"]; record=d["record"]; orientation=d["orientation"]; indexPasses=d["indexPasses"]; pendingSenseHex=d["pendingSenseHex"]; return self
::requires "IBM370IO.cls"
::requires "IBM370Media.cls"
