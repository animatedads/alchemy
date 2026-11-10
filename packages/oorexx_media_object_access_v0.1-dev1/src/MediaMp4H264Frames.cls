/* ooRexx H264 codec adapter for the EXISTING MediaMp4SampleTable and MP4
 * MediaMp4Track. No second MP4 atom/stsc/stsz/edit-list parser.
 * Native provider decodes Annex-B NALs only, never opens a file.
 * Frame-exact seek is observationally qualified per sample, not inferred
 * solely from MP4 sync flags. User-requested MP4 hot-seek reads only GOP.
 */
::options digits 30
::class MediaMp4H264Frames public
::attribute movie get
::attribute track get
::attribute sampleMap get
::attribute readBytesLast get
::method init
 expose movie track sampleMap source config nalLength readBytesLast
 use strict arg mp4Movie
 movie=mp4Movie;source=movie~source
 track=.nil
 do i=1 to movie~trackCount
   candidate=movie~track(i)
   if candidate~kind='vide' & candidate~codecTag='avc1' then do
     if track<>.nil then raise syntax 88.900 array('ambiguous MP4 H264 tracks')
     track=candidate
   end
 end
 if track==.nil then raise syntax 88.900 array('no avc1 video track')
 if track~fragmented then raise syntax 88.900 array('fragmented video unsupported')
 sampleMap=track~mapSamples
 if sampleMap~indexStatus<>'CANDIDATE_ONLY' then -
   raise syntax 88.900 array('sample table not fully mapped')
 /* Existing stbl atom owns the raw sample description. */
 descriptions=track~sampleTable~children
 stsd=.nil
 do entry over descriptions
   if entry~kind='stsd' then stsd=entry
 end
 if stsd==.nil then raise syntax 88.900 array('avc1 sample entry absent')
 raw=stsd~exactBytes(0,stsd~length-stsd~headerBytes)
 posAvc=pos('avcC',raw)
 if posAvc<5 then raise syntax 88.900 array('avcC extradata missing')
 config=substr(raw,posAvc+4)
 nalLength=(c2d(substr(config,5,1))//4)+1
 if nalLength<>4 then raise syntax 88.900 array('AVC NAL-size width unsupported')
 spsNum=c2d(substr(config,6,1))//32
 if spsNum<1 | spsNum>8 then raise syntax 88.900 array('invalid SPS count')
 at=7;header=''
 do i=1 to spsNum
   size=self~u16(config,at);at+=2
   if size<2 | at+size-1>config~length then raise syntax 88.900 array('invalid SPS')
   header=header||x2c('00000001')||substr(config,at,size);at+=size
 end
 ppsNum=c2d(substr(config,at,1));at+=1
 if ppsNum<1 | ppsNum>8 then raise syntax 88.900 array('invalid PPS count')
 do i=1 to ppsNum
   size=self~u16(config,at);at+=2
   if size<1 | at+size-1>config~length then raise syntax 88.900 array('invalid PPS')
   header=header||x2c('00000001')||substr(config,at,size);at+=size
 end
 config=header;readBytesLast=0
::method u16
 use strict arg b,i
 if i<1 | i+1>b~length then raise syntax 88.900 array('truncated AVC16')
 return x2d(c2x(substr(b,i,2)))
::method u32
 use strict arg b,i
 if i<1 | i+3>b~length then raise syntax 88.900 array('truncated AVC32')
 return x2d(c2x(substr(b,i,4)))
::method readExact
 expose source
 use strict arg start,count
 if start<0 | count<0 | count>16777216 | start+count>source~sizeBytes then -
   raise syntax 88.900 array('invalid bounded MP4 sample')
 out=''
 do while count>0
   n=min(65536,count)
   out=out||source~readAt(start,n)
   start+=n;count-=n
 end
 return out
::method annexB
 use strict arg encoded
 i=1;data=''
 do while i<=encoded~length
   if i+3>encoded~length then raise syntax 88.900 array('incomplete avc1 prefix')
   n=self~u32(encoded,i);i+=4
   if n<1 | i+n-1>encoded~length then raise syntax 88.900 array('invalid MP4 NAL')
   data=data||x2c('00000001')||substr(encoded,i,n);i+=n
 end
 return data
::method frameAt
 expose sampleMap config track readBytesLast
 use strict arg requested90k,budgetBytes=2097152,maxSamples=240
 if \datatype(requested90k,'W') | requested90k<0 | budgetBytes<4096 | -
    budgetBytes>16777216 | maxSamples<1 | maxSamples>1000 then -
    raise syntax 88.900 array('seek request outside budget')
 scale=sampleMap~timeScale
 wanted=trunc(requested90k*scale/90000)
 plan=sampleMap~planTime(wanted)
 if plan==.nil | plan~anchor==.nil then return .nil
 codec=.MediaH264Decoder~new;found=.nil;readBytesLast=0
 first=plan~anchor~ordinal
 last=min(sampleMap~sampleCount,first+maxSamples-1)
 do i=first to last
   sample=sampleMap~sample(i)
   readBytesLast+=sample~sizeBytes
   if readBytesLast>budgetBytes then leave
   compressed=self~readExact(sample~byteOffset,sample~sizeBytes)
   nal=self~annexB(compressed)
   if i=first then nal=config||nal
   pts=trunc(sample~presentationTicks*90000/scale)
   if \sample~presentationVisible then pts=-1
   decoded=codec~feed(nal,pts)
   do frame over decoded
     if frame~presentationTicks>=requested90k then do
       found=frame;leave
     end
   end
   if found<>.nil then leave
 end
 if found==.nil then do
   decoded=codec~flush
   do frame over decoded
     if frame~presentationTicks>=requested90k then do
       found=frame;leave
     end
   end
 end
 ignore=codec~close
 return found
::requires 'MediaH264Frames.cls'