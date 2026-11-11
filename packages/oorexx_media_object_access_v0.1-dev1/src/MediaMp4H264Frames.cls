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
 expose movie track sampleMap source config nalLength readBytesLast sourceIdentity sourceSize
 use strict arg mp4Movie
 movie=mp4Movie;source=movie~source
 sourceIdentity=source~sourceIdentity;sourceSize=source~sizeBytes
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
 /* The single avc1 sample entry is parsed as structured child boxes;
  * never search arbitrary stsd bytes for the letters avcC. */
 descriptions=track~sampleTable~children
 stsd=.nil
 do entry over descriptions
   if entry~kind='stsd' then stsd=entry
 end
 if stsd==.nil then raise syntax 88.900 array('avc1 sample entry absent')
 header=.MediaMp4AvcConfig~new(stsd)
 config=header~annexBPrefix
 nalLength=header~nalLengthBytes
 readBytesLast=0
::method u16
 use strict arg b,i
 if i<1 | i+1>b~length then raise syntax 88.900 array('truncated AVC16')
 return x2d(c2x(substr(b,i,2)))
::method u32
 use strict arg b,i
 if i<1 | i+3>b~length then raise syntax 88.900 array('truncated AVC32')
 return x2d(c2x(substr(b,i,4)))
::method assertSource
 expose source sourceIdentity sourceSize
 if source~sourceIdentity<>sourceIdentity | source~sizeBytes<>sourceSize then -
   raise syntax 88.900 array('MP4 video source identity or size changed')
 return self
::method readExact
 expose source sourceSize
 use strict arg start,count
 self~assertSource
 if \datatype(start,'W') | \datatype(count,'W') | -
    start<0 | count<0 | count>16777216 | start+count>sourceSize then -
   raise syntax 88.900 array('invalid bounded MP4 sample')
 out=''
 do while count>0
   n=min(65536,count)
   part=source~readAt(start,n)
   if part~length<>n then raise syntax 88.900 array('short MP4 media source range',start,n)
   out=out||part
   start+=n;count-=n
 end
 self~assertSource
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
 self~assertSource
 scale=sampleMap~timeScale
 wanted=(requested90k*scale+89999)%90000
 plan=sampleMap~planTime(wanted)
 if plan==.nil then return .nil
 if plan~anchor==.nil then return .nil
 codec=.MediaH264Decoder~new;found=.nil;readBytesLast=0
 first=plan~anchor~ordinal
 last=min(sampleMap~sampleCount,first+maxSamples-1)
 exhausted=.false
 do i=first to last
   sample=sampleMap~sample(i)
   if sample~descriptionIndex<>1 then -
     raise syntax 88.900 array('AVC sample description switched without decoder reinitialization',i)
   if \sample~presentationVisible then -
     raise syntax 88.900 array('MP4 video sample hidden by edit-list preroll: decoder PTS concealment is not qualified',i)
   if sample~sizeBytes>4194304 then -
     raise syntax 88.900 array('MP4 access unit exceeds native decoder feed cap',i)
   if readBytesLast+sample~sizeBytes>budgetBytes then do
     exhausted=.true
     leave
   end
   compressed=self~readExact(sample~byteOffset,sample~sizeBytes)
   readBytesLast+=sample~sizeBytes
   nal=self~annexB(compressed)
   if i=first then nal=config||nal
   if nal~length>4194304 then -
     raise syntax 88.900 array('MP4 AVC access unit plus SPS/PPS exceeds codec feed budget',i,nal~length)
   numerator=sample~presentationTicks*90000
   if numerator//scale<>0 then -
     raise syntax 88.900 array('MP4 PTS cannot be represented exactly at 90 kHz',i)
   pts=numerator%scale
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
 if found==.nil then do
   if exhausted then raise syntax 88.900 array('MP4 hot seek compressed-byte budget exhausted',readBytesLast,budgetBytes)
   if last<sampleMap~sampleCount then -
     raise syntax 88.900 array('MP4 hot seek sample budget exhausted',maxSamples)
 end
 return found
::requires 'MediaH264Frames.cls'
::requires 'Mp4File.cls'
::requires 'MediaMp4AvcConfig.cls'
