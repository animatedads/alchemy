/* MP4 H.264/avc1 sample access, ooRexx-owned: bounded atom, sample-table and
 * AVC-length->AnnexB conversion. Codec-only provider does not demux.
 * Rejects unsupported fragmentation, altered source and invalid limits.
 */
::options digits 30
::class MediaMp4AvcAccess public
::attribute sampleCount get
::attribute timeScale get
::attribute syncCount get
::attribute frameReadBytes get
::attribute width get
::attribute height get
::method init
 expose source identity sourceSize sampleOffsets sampleSizes sampleDts sampleCts syncFlags -
   sampleCount timeScale syncCount params nalLen frameReadBytes width height
 use strict arg byteSource
 source=byteSource;sourceSize=source~sizeBytes;identity=source~sourceIdentity
 if sourceSize<1000 | sourceSize>9223372036854775807 then raise syntax 88.900 array('MP4 size gate',sourceSize)
 whole=.array~of(0,sourceSize)
 moov=self~child(whole,'moov')
 if moov==.nil then raise syntax 88.900 array('MP4 missing moov')
 moof=self~child(whole,'moof')
 if moof<>.nil then raise syntax 88.900 array('fragmented MP4 unsupported')
 pos=moov[1];top=moov[2];trak=.nil
 do while pos+8<=top
   at=self~atom(pos,top)
   if at[3]='trak' then do
     mdia=self~child(.array~of(at[1],at[2]),'mdia')
     if mdia<>.nil then do
       hdlr=self~child(mdia,'hdlr')
       if hdlr<>.nil then do
         mark=self~readBytes(hdlr[1]+8,4)
         if mark='vide' then do
           if trak<>.nil then raise syntax 88.900 array('ambiguous multiple video tracks')
           trak=.array~of(at[1],at[2])
         end
       end
     end
   end
   pos=at[4]
 end
 if trak==.nil then raise syntax 88.900 array('MP4 video track missing')
 mdia=self~child(trak,'mdia');minf=self~child(mdia,'minf');stbl=self~child(minf,'stbl')
 mdhd=self~child(mdia,'mdhd')
 version=c2d(self~readBytes(mdhd[1],1))
 if version=0 then timeScale=self~uint(self~readBytes(mdhd[1]+12,4),1,4)
 else if version=1 then timeScale=self~uint(self~readBytes(mdhd[1]+20,4),1,4)
 else raise syntax 88.900 array('invalid mdhd version')
 if timeScale<1 then raise syntax 88.900 array('timeScale cannot be zero')
 stsd=self~payload(self~child(stbl,'stsd'))
 if pos('avc1',stsd)=0 then raise syntax 88.900 array('unsupported video codec, require avc1')
 at=pos('avcC',stsd)
 if at<5 then raise syntax 88.900 array('MP4 avcC missing')
 avc=substr(stsd,at+4)
 nalLen=c2d(substr(avc,5,1))//4+1
 if nalLen<>4 then raise syntax 88.900 array('unsupported AVC length format',nalLen)
 spsNum=c2d(substr(avc,6,1))//32;cursor=7;params=''
 if spsNum<1 | spsNum>8 then raise syntax 88.900 array('SPS count invalid')
 do i=1 to spsNum
   count=self~uint(avc,cursor,2);cursor+=2
   if count<2 | count>4096 then raise syntax 88.900 array('SPS length invalid',count)
   params=params||x2c('00000001')||substr(avc,cursor,count);cursor+=count
 end
 ppsNum=c2d(substr(avc,cursor,1));cursor+=1
 if ppsNum<1 | ppsNum>8 then raise syntax 88.900 array('PPS count invalid')
 do i=1 to ppsNum
   count=self~uint(avc,cursor,2);cursor+=2
   if count<1 | count>4096 then raise syntax 88.900 array('PPS length invalid',count)
   params=params||x2c('00000001')||substr(avc,cursor,count);cursor+=count
 end
 sampleBytes=self~payload(self~child(stbl,'stsz'))
 globalSize=self~uint(sampleBytes,5,4);sampleCount=self~uint(sampleBytes,9,4)
 if sampleCount<1 | sampleCount>1000000 then raise syntax 88.900 array('sample count gate',sampleCount)
 sampleSizes=.array~new;sampleOffsets=.array~new;sampleDts=.array~new;sampleCts=.array~new;syncFlags=.array~new
 do i=1 to sampleCount
   if globalSize>0 then size=globalSize
   else size=self~uint(sampleBytes,13+(i-1)*4,4)
   if size<1 | size>16777216 then raise syntax 88.900 array('H264 sample too large',i,size)
   sampleSizes~append(size)
 end
 chunks=self~child(stbl,'stco');co64=.false
 if chunks==.nil then do
   chunks=self~child(stbl,'co64');co64=.true
 end
 if chunks==.nil then raise syntax 88.900 array('MP4 lacks stco/co64')
 chunkBytes=self~payload(chunks)
 chunkCount=self~uint(chunkBytes,5,4)
 if chunkCount<1 | chunkCount>1000000 then raise syntax 88.900 array('chunk count gate')
 chunkOffsets=.array~new
 do i=1 to chunkCount
   if co64 then chunkOffsets~append(self~uint(chunkBytes,9+(i-1)*8,8))
   else chunkOffsets~append(self~uint(chunkBytes,9+(i-1)*4,4))
 end
 sc=self~payload(self~child(stbl,'stsc'))
 scCount=self~uint(sc,5,4)
 if scCount<1 | scCount>100000 then raise syntax 88.900 array('stsc malformed')
 stsc=.array~new
 do i=1 to scCount
   stsc~append(.array~of(self~uint(sc,9+(i-1)*12,4), -
     self~uint(sc,13+(i-1)*12,4),self~uint(sc,17+(i-1)*12,4)))
 end
 sIndex=1;sGroup=1
 do c=1 to chunkCount
   if sGroup<stsc~items then if c>=stsc[sGroup+1][1] then sGroup+=1
   per=stsc[sGroup][2];at=chunkOffsets[c]
   do q=1 to per
     if sIndex>sampleCount then leave
     sampleOffsets~append(at)
     at+=sampleSizes[sIndex];sIndex+=1
   end
 end
 if sampleOffsets~items<>sampleCount then -
   raise syntax 88.900 array('sample offsets incomplete',sampleOffsets~items,sampleCount)
 ts=self~payload(self~child(stbl,'stts'))
 tcount=self~uint(ts,5,4);clock=0
 do i=1 to tcount
   howMany=self~uint(ts,9+(i-1)*8,4);delta=self~uint(ts,13+(i-1)*8,4)
   do j=1 to howMany
     sampleDts~append(clock);clock+=delta
   end
 end
 if sampleDts~items<>sampleCount then raise syntax 88.900 array('DTS count mismatch')
 ctts=self~child(stbl,'ctts')
 if ctts==.nil then do i=1 to sampleCount
   sampleCts~append(sampleDts[i])
 end
 else do
   ct=self~payload(ctts);version=c2d(substr(ct,1,1));count=self~uint(ct,5,4);n=1
   do i=1 to count
     howMany=self~uint(ct,9+(i-1)*8,4);offset=self~uint(ct,13+(i-1)*8,4)
     if version=1 & offset>=2147483648 then offset=offset-4294967296
     do j=1 to howMany
       sampleCts~append(sampleDts[n]+offset);n+=1
     end
   end
 end
 if sampleCts~items<>sampleCount then raise syntax 88.900 array('CTTS count mismatch')
 key=self~child(stbl,'stss');syncCount=0
 if key==.nil then do i=1 to sampleCount
   syncFlags~append(1);syncCount+=1
 end
 else do
   kb=self~payload(key);keycount=self~uint(kb,5,4);sync=.directory~new
   do i=1 to keycount
     ordinal=self~uint(kb,9+(i-1)*4,4)
     sync[ordinal]=1
   end
   do i=1 to sampleCount
     yes=0
     if sync[i]<>.nil then yes=1;syncCount+=yes;syncFlags~append(yes)
   end
 end
 frameReadBytes=0;width=0;height=0
::method atom
 use strict arg position,upper
 hdr=self~readBytes(position,8)
 if hdr~length<>8 then raise syntax 88.900 array('atom truncated')
 count=self~uint(hdr,1,4);kind=substr(hdr,5,4);n=8
 if count=1 then do
   count=self~uint(self~readBytes(position+8,8),1,8);n=16
 end
 if count=0 then count=upper-position
 if count<n | position+count>upper then raise syntax 88.900 array('invalid atom length',kind)
 return .array~of(position+n,position+count,kind,position+count)
::method child
 use strict arg parent,kind
 if parent==.nil then raise syntax 88.900 array('missing parent atom',kind)
 pos=parent[1]
 do while pos+8<=parent[2]
   at=self~atom(pos,parent[2])
   if at[3]=kind then return .array~of(at[1],at[2])
   pos=at[4]
 end
 return .nil
::method payload
 use strict arg atom
 if atom==.nil then raise syntax 88.900 array('missing required atom')
 return self~readBytes(atom[1],atom[2]-atom[1])
::method uint
 use strict arg bytes,at,len
 if at<1 | len<1 | at+len-1>bytes~length then raise syntax 88.900 array('uint out of bounds',at,len)
 return x2d(c2x(substr(bytes,at,len)))
::method readBytes
 expose source sourceSize
 use strict arg pos,n
 if pos<0 | n<0 | pos+n>sourceSize | n>8388608 then -
   raise syntax 88.900 array('MP4 range budget invalid',pos,n)
 data=''
 do while n>0
   count=min(65536,n)
   data=data||source~readAt(pos,count);pos+=count;n-=count
 end
 return data
::method samplePts
 expose sampleCts timeScale
 use strict arg i
 return trunc(sampleCts[i]*90000/timeScale)
::method sampleSeekOrdinal
 expose sampleCount syncFlags
 use strict arg targetTicks
 iTarget=sampleCount
 do i=1 to sampleCount
   if self~samplePts(i)>=targetTicks then do
     iTarget=i;leave
   end
 end
 do i=iTarget to 1 by -1
   if syncFlags[i]=1 then return i
 end
 return 1
::method toAnnexB
 expose nalLen
 use strict arg avcc
 i=1;out=''
 do while i<=avcc~length
   if i+nalLen-1>avcc~length then raise syntax 88.900 array('truncated AVC NAL length')
   count=self~uint(avcc,i,nalLen);i+=nalLen
   if count<1 | i+count-1>avcc~length then raise syntax 88.900 array('invalid AVC NAL size',count)
   out=out||x2c('00000001')||substr(avcc,i,count);i+=count
 end
 return out
::method frameAt
 expose source identity sourceSize sampleCount sampleOffsets sampleSizes params frameReadBytes width height
 use strict arg wantedTicks,budget=3145728,maxSamples=240
 if source~sourceIdentity<>identity | source~sizeBytes<>sourceSize then -
   raise syntax 88.900 array('MP4 source changed')
 if budget<4096 | budget>16777216 | maxSamples<1 | maxSamples>2000 then -
   raise syntax 88.900 array('seek budget invalid')
 start=self~sampleSeekOrdinal(wantedTicks)
 codec=.MediaH264Decoder~new
 found=.nil;frameReadBytes=0
 do i=start to min(sampleCount,start+maxSamples-1)
   count=sampleSizes[i];frameReadBytes+=count
   if frameReadBytes>budget then leave
   sample=self~readBytes(sampleOffsets[i],count)
   nal=self~toAnnexB(sample)
   if i=start then nal=params||nal
   decoded=codec~feed(nal,self~samplePts(i))
   do frame over decoded
     if frame~presentationTicks>=wantedTicks then do
       found=frame;leave
     end
   end
   if found<>.nil then leave
 end
 if found==.nil then do
   decoded=codec~flush
   do frame over decoded
     if frame~presentationTicks>=wantedTicks then do
       found=frame;leave
     end
   end
 end
 ignore=codec~close
 if found<>.nil then do
   width=found~width;height=found~height
 end
 return found
::requires 'MediaH264Frames.cls'