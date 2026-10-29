/* Standard MIDI File reader for ooRexx Guitar Tab Audio.
 * v0.1-dev6: Type 0/1 SMF, PPQ timing, tempo map, channel voice events,
 * paired note durations, program/controller/pitch-bend preservation.
 *
 * MIDI is performance/control truth only.  It does not synthesize audio.
 */
numeric digits 30

::class MidiInputGuard public
::method number class
  use strict arg value,label
  if datatype(value,'N')=0 then raise syntax 88.900 array('numeric MIDI value required',label,value)
  return value
::method whole class
  use strict arg value,label
  if datatype(value,'W')=0 then raise syntax 88.900 array('whole-number MIDI value required',label,value)
  return value

::class MidiRawEvent public
::method init
  expose _tick _track _kind _channel _a _b _status
  use strict arg tick,track,kind,channel=0,a=0,b=0,status=0
  _tick=.MidiInputGuard~whole(tick,'tick')
  _track=.MidiInputGuard~whole(track,'track')
  _kind=kind
  _channel=.MidiInputGuard~whole(channel,'channel')
  _a=.MidiInputGuard~whole(a,'a')
  _b=.MidiInputGuard~whole(b,'b')
  _status=.MidiInputGuard~whole(status,'status')
::method tick; expose _tick; return _tick
::method track; expose _track; return _track
::method kind; expose _kind; return _kind
::method channel; expose _channel; return _channel
::method a; expose _a; return _a
::method b; expose _b; return _b
::method status; expose _status; return _status

::class MidiTempoEvent public
::method init
  expose _tick _usq
  use strict arg tick,microsecondsPerQuarter
  _tick=.MidiInputGuard~whole(tick,'tick')
  _usq=.MidiInputGuard~whole(microsecondsPerQuarter,'microsecondsPerQuarter')
::method tick; expose _tick; return _tick
::method microsecondsPerQuarter; expose _usq; return _usq
::method bpm; expose _usq; return 60000000/_usq

::class MidiNoteEvent public
::method init
  expose _track _channel _program _note _velocity _startTick _endTick _startSeconds _durationSeconds
  use strict arg track,channel,program,note,velocity,startTick,endTick,startSeconds,durationSeconds
  _track=.MidiInputGuard~whole(track,'track')
  _channel=.MidiInputGuard~whole(channel,'channel')
  _program=.MidiInputGuard~whole(program,'program')
  _note=.MidiInputGuard~whole(note,'note')
  _velocity=.MidiInputGuard~whole(velocity,'velocity')
  _startTick=.MidiInputGuard~whole(startTick,'startTick')
  _endTick=.MidiInputGuard~whole(endTick,'endTick')
  _startSeconds=.MidiInputGuard~number(startSeconds,'startSeconds')
  _durationSeconds=.MidiInputGuard~number(durationSeconds,'durationSeconds')
::method track; expose _track; return _track
::method channel; expose _channel; return _channel
::method program; expose _program; return _program
::method note; expose _note; return _note
::method velocity; expose _velocity; return _velocity
::method startTick; expose _startTick; return _startTick
::method endTick; expose _endTick; return _endTick
::method startSeconds; expose _startSeconds; return _startSeconds
::method durationSeconds; expose _durationSeconds; return _durationSeconds
::method frequencyHz
  expose _note
  ratio=1.05946309435929526456182529495; f=440; d=_note-69
  if d>0 then do i=1 to d; f*=ratio; end
  else if d<0 then do i=1 to -d; f/=ratio; end
  return f

::class MidiControlEvent public
::method init
  expose _kind _track _channel _tick _seconds _a _b
  use strict arg kind,track,channel,tick,seconds,a=0,b=0
  _kind=kind
  _track=.MidiInputGuard~whole(track,'track')
  _channel=.MidiInputGuard~whole(channel,'channel')
  _tick=.MidiInputGuard~whole(tick,'tick')
  _seconds=.MidiInputGuard~number(seconds,'seconds')
  _a=.MidiInputGuard~whole(a,'a')
  _b=.MidiInputGuard~whole(b,'b')
::method kind; expose _kind; return _kind
::method track; expose _track; return _track
::method channel; expose _channel; return _channel
::method tick; expose _tick; return _tick
::method seconds; expose _seconds; return _seconds
::method a; expose _a; return _a
::method b; expose _b; return _b

::class MidiSong public
::method init
  expose _format _tracks _division _tempos _notes _controls _duration _performanceDuration _noteOns _unclosed _unmatchedOffs
  use strict arg format,tracks,division,tempos,notes,controls,duration,performanceDuration,noteOns,unclosed,unmatchedOffs
  _format=.MidiInputGuard~whole(format,'format')
  _tracks=.MidiInputGuard~whole(tracks,'tracks')
  _division=.MidiInputGuard~whole(division,'division')
  _tempos=tempos; _notes=notes; _controls=controls
  _duration=.MidiInputGuard~number(duration,'duration')
  _performanceDuration=.MidiInputGuard~number(performanceDuration,'performanceDuration')
  _noteOns=.MidiInputGuard~whole(noteOns,'noteOns')
  _unclosed=.MidiInputGuard~whole(unclosed,'unclosed')
  _unmatchedOffs=.MidiInputGuard~whole(unmatchedOffs,'unmatchedOffs')
::method format; expose _format; return _format
::method tracks; expose _tracks; return _tracks
::method division; expose _division; return _division
::method tempos; expose _tempos; return _tempos
::method notes; expose _notes; return _notes
::method controls; expose _controls; return _controls
::method durationSeconds; expose _duration; return _duration
::method performanceDurationSeconds; expose _performanceDuration; return _performanceDuration
::method noteOnCount; expose _noteOns; return _noteOns
::method unclosedNoteOns; expose _unclosed; return _unclosed
::method unmatchedNoteOffs; expose _unmatchedOffs; return _unmatchedOffs

::class MidiBinaryCursor
::method init
  expose _data _pos
  use strict arg data
  _data=data; _pos=1
::method remaining; expose _data _pos; return _data~length-_pos+1
::method pos; expose _pos; return _pos
::method byte
  expose _data _pos
  if _pos>_data~length then raise syntax 88.900 array('unexpected end of MIDI data')
  v=c2d(_data~substr(_pos,1)); _pos+=1; return v
::method bytes
  expose _data _pos
  use strict arg count
  if count<0 | _pos+count-1>_data~length then raise syntax 88.900 array('unexpected end of MIDI data',count)
  s=_data~substr(_pos,count); _pos+=count; return s
::method u16
  b1=self~byte; b2=self~byte; return b1*256+b2
::method u24
  b1=self~byte; b2=self~byte; b3=self~byte; return b1*65536+b2*256+b3
::method u32
  b1=self~byte; b2=self~byte; b3=self~byte; b4=self~byte
  return ((b1*256+b2)*256+b3)*256+b4
::method vlq
  value=0; count=0
  do forever
    b=self~byte; count+=1
    if count>4 then raise syntax 88.900 array('invalid MIDI variable-length quantity')
    value=value*128+(b//128)
    if b<128 then leave
  end
  return value

::class MidiFileReader public
::method read class
  use strict arg path
  opened=stream(path,'c','open read')
  size=chars(path)
  data=charin(path,1,size)
  call stream path,'c','close'
  if data~length<14 then raise syntax 88.900 array('MIDI file too short',path)
  c=.MidiBinaryCursor~new(data)
  if c~bytes(4)<>"MThd" then raise syntax 88.900 array('not a Standard MIDI File',path)
  hlen=c~u32
  if hlen<6 then raise syntax 88.900 array('invalid MThd length',hlen)
  format=c~u16; tracks=c~u16; division=c~u16
  if hlen>6 then junk=c~bytes(hlen-6)
  if format<>0 then if format<>1 then raise syntax 88.900 array('unsupported MIDI format',format)
  if division>=32768 then raise syntax 88.900 array('SMPTE MIDI division not supported in dev6',division)

  raw=.array~new; tempos=.array~new
  tempos~append(.MidiTempoEvent~new(0,500000))
  do tr=1 to tracks
    if c~remaining<8 then raise syntax 88.900 array('missing MIDI track chunk',tr)
    if c~bytes(4)<>"MTrk" then raise syntax 88.900 array('expected MTrk',tr)
    tlen=c~u32; tdata=c~bytes(tlen)
    self~parseTrack(tdata,tr,raw,tempos)
  end
  raw=self~mergeSortRaw(raw)
  tempos=self~normalizeTempos(tempos)
  return self~buildSong(format,tracks,division,raw,tempos)

::method parseTrack class
  use strict arg data,trackNo,raw,tempos
  c=.MidiBinaryCursor~new(data); tick=0; running=0
  do while c~remaining>0
    tick+=c~vlq
    b=c~byte
    if b<128 then do
      if running=0 then raise syntax 88.900 array('running status without prior status',trackNo,tick)
      status=running; first=b; haveFirst=.true
    end
    else do
      status=b; haveFirst=.false
      if status<240 then running=status
      else if status=240 | status=247 | status=255 then running=0
    end

    if status=255 then do
      meta=c~byte; len=c~vlq; payload=c~bytes(len)
      if meta=81 then if len=3 then do
        us=c2d(payload~substr(1,1))*65536+c2d(payload~substr(2,1))*256+c2d(payload~substr(3,1))
        tempos~append(.MidiTempoEvent~new(tick,us))
      end
      if meta=47 then do
        raw~append(.MidiRawEvent~new(tick,trackNo,'TRACK_END',0,0,0,255))
        leave
      end
      iterate
    end
    if status=240 | status=247 then do
      len=c~vlq; skip=c~bytes(len); iterate
    end
    if status>=248 then iterate

    hi=status%16*16; ch=(status//16)+1
    if hi=192 | hi=208 then need=1
    else need=2
    if haveFirst then d1=first
    else d1=c~byte
    if need=2 then d2=c~byte
    else d2=0

    select
      when hi=128 then raw~append(.MidiRawEvent~new(tick,trackNo,'NOTE_OFF',ch,d1,d2,status))
      when hi=144 then do
        if d2=0 then raw~append(.MidiRawEvent~new(tick,trackNo,'NOTE_OFF',ch,d1,d2,status))
        else raw~append(.MidiRawEvent~new(tick,trackNo,'NOTE_ON',ch,d1,d2,status))
      end
      when hi=176 then raw~append(.MidiRawEvent~new(tick,trackNo,'CONTROL',ch,d1,d2,status))
      when hi=192 then raw~append(.MidiRawEvent~new(tick,trackNo,'PROGRAM',ch,d1,0,status))
      when hi=224 then raw~append(.MidiRawEvent~new(tick,trackNo,'PITCH_BEND',ch,d1+d2*128,0,status))
      when hi=160 then raw~append(.MidiRawEvent~new(tick,trackNo,'POLY_PRESSURE',ch,d1,d2,status))
      when hi=208 then raw~append(.MidiRawEvent~new(tick,trackNo,'CHANNEL_PRESSURE',ch,d1,0,status))
      otherwise nop
    end
  end

::method normalizeTempos class
  use strict arg tempos
  a=self~mergeSortTempo(tempos); out=.array~new
  do t over a
    if out~items>0 then do
      if out[out~items]~tick=t~tick then out[out~items]=t
      else out~append(t)
    end
    else out~append(t)
  end
  return out

::method tickToSeconds class
  use strict arg tick,division,tempos
  secs=0; lastTick=0; usq=500000
  do t over tempos
    if t~tick>tick then leave
    if t~tick>lastTick then secs += (t~tick-lastTick)*usq/(division*1000000)
    lastTick=t~tick; usq=t~microsecondsPerQuarter
  end
  if tick>lastTick then secs += (tick-lastTick)*usq/(division*1000000)
  return secs

::method buildSong class
  use strict arg format,tracks,division,raw,tempos
  notes=.array~new; controls=.array~new; active=.directory~new
  programs=.array~new(16); do i=1 to 16; programs[i]=0; end
  lastSeconds=0; performanceSeconds=0; noteOns=0; unmatchedOffs=0
  do ev over raw
    sec=self~tickToSeconds(ev~tick,division,tempos)
    if sec>lastSeconds then lastSeconds=sec
    if ev~kind<>'TRACK_END' then if sec>performanceSeconds then performanceSeconds=sec
    ch=ev~channel
    select
      when ev~kind='PROGRAM' then do
        programs[ch]=ev~a
        controls~append(.MidiControlEvent~new('PROGRAM',ev~track,ch,ev~tick,sec,ev~a,0))
      end
      when ev~kind='CONTROL' then controls~append(.MidiControlEvent~new('CONTROL',ev~track,ch,ev~tick,sec,ev~a,ev~b))
      when ev~kind='PITCH_BEND' then controls~append(.MidiControlEvent~new('PITCH_BEND',ev~track,ch,ev~tick,sec,ev~a,0))
      when ev~kind='CHANNEL_PRESSURE' | ev~kind='POLY_PRESSURE' then controls~append(.MidiControlEvent~new(ev~kind,ev~track,ch,ev~tick,sec,ev~a,ev~b))
      when ev~kind='NOTE_ON' then do
        noteOns+=1
        key=ev~track':'ch':'ev~a
        q=active[key]; if q==.nil then do; q=.queue~new; active[key]=q; end
        rec=.directory~new; rec['event']=ev; rec['program']=programs[ch]; q~queue(rec)
      end
      when ev~kind='NOTE_OFF' then do
        key=ev~track':'ch':'ev~a; q=active[key]
        if q==.nil then do; unmatchedOffs+=1; iterate; end
        if q~items=0 then do; unmatchedOffs+=1; iterate; end
        rec=q~pull; on=rec['event']; st=self~tickToSeconds(on~tick,division,tempos)
        dur=sec-st; if dur<0 then dur=0
        notes~append(.MidiNoteEvent~new(on~track,ch,rec['program'],on~a,on~b,on~tick,ev~tick,st,dur))
      end
      otherwise nop
    end
  end
  unclosed=noteOns-notes~items
  return .MidiSong~new(format,tracks,division,tempos,notes,controls,lastSeconds,performanceSeconds,noteOns,unclosed,unmatchedOffs)

::method mergeSortRaw class
  use strict arg a
  n=a~items
  if n<2 then return a
  width=1; cur=a
  do while width<n
    out=.array~new; i=1
    do while i<=n
      leftStart=i; leftEnd=i+width-1; if leftEnd>n then leftEnd=n
      rightStart=i+width; rightEnd=i+2*width-1; if rightEnd>n then rightEnd=n
      p=leftStart; q=rightStart
      do while p<=leftEnd | q<=rightEnd
        if p>leftEnd then do; out~append(cur[q]); q+=1; iterate; end
        if q>rightEnd then do; out~append(cur[p]); p+=1; iterate; end
        if self~rawLe(cur[p],cur[q]) then do; out~append(cur[p]); p+=1; end
        else do; out~append(cur[q]); q+=1; end
      end
      i+=2*width
    end
    cur=out; width*=2
  end
  return cur

::method rawLe class
  use strict arg a,b
  if a~tick<b~tick then return .true
  if a~tick>b~tick then return .false
  if a~track<b~track then return .true
  if a~track>b~track then return .false
  return .true

::method mergeSortTempo class
  use strict arg a
  n=a~items
  if n<2 then return a
  width=1; cur=a
  do while width<n
    out=.array~new; i=1
    do while i<=n
      leftStart=i; leftEnd=i+width-1; if leftEnd>n then leftEnd=n
      rightStart=i+width; rightEnd=i+2*width-1; if rightEnd>n then rightEnd=n
      p=leftStart; q=rightStart
      do while p<=leftEnd | q<=rightEnd
        if p>leftEnd then do; out~append(cur[q]); q+=1; iterate; end
        if q>rightEnd then do; out~append(cur[p]); p+=1; iterate; end
        if cur[p]~tick<=cur[q]~tick then do; out~append(cur[p]); p+=1; end
        else do; out~append(cur[q]); q+=1; end
      end
      i+=2*width
    end
    cur=out; width*=2
  end
  return cur

::class MidiGuitarVoice public
::method init
  expose _noteEvent _string _fret _cost
  use strict arg noteEvent,stringNumber,fret,cost=0
  _noteEvent=noteEvent
  _string=.MidiInputGuard~whole(stringNumber,'stringNumber')
  _fret=.MidiInputGuard~whole(fret,'fret')
  _cost=.MidiInputGuard~number(cost,'cost')
::method noteEvent; expose _noteEvent; return _noteEvent
::method stringNumber; expose _string; return _string
::method fret; expose _fret; return _fret
::method cost; expose _cost; return _cost

::class MidiGuitarVoicer public
::method standardOpenMidi class
  return .array~of(64,59,55,50,45,40)
::method voiceNote class
  use strict arg noteEvent,maxFret=24,preferredFret=5
  opens=self~standardOpenMidi; best=.nil; bestCost=1E99
  do s=1 to 6
    fret=noteEvent~note-opens[s]
    if fret<0 | fret>maxFret then iterate
    cost=abs(fret-preferredFret)+s*.03
    if cost<bestCost then do
      best=.MidiGuitarVoice~new(noteEvent,s,fret,cost); bestCost=cost
    end
  end
  return best
::method voiceSong class
  use strict arg song,maxFret=24,preferredFret=5
  out=.array~new; rejected=.array~new
  do n over song~notes
    v=self~voiceNote(n,maxFret,preferredFret)
    if v==.nil then rejected~append(n)
    else out~append(v)
  end
  rdir=.directory~new; rdir['voices']=out; rdir['rejected']=rejected; return rdir

::class MidiEventSelector public
::method notesForProgram class
  use strict arg song,program
  out=.array~new
  do n over song~notes
    if n~program=program then out~append(n)
  end
  return out
::method notesForChannel class
  use strict arg song,channel
  out=.array~new
  do n over song~notes
    if n~channel=channel then out~append(n)
  end
  return out
::method voiceNotes class
  use strict arg notes,maxFret=24,preferredFret=5
  out=.array~new; rejected=.array~new
  do n over notes
    v=.MidiGuitarVoicer~voiceNote(n,maxFret,preferredFret)
    if v==.nil then rejected~append(n)
    else out~append(v)
  end
  d=.directory~new; d['voices']=out; d['rejected']=rejected; return d

::class MidiBassVoice public
::method init
  expose _noteEvent _string _fret _cost
  use strict arg noteEvent,stringNumber,fret,cost=0
  _noteEvent=noteEvent
  _string=.MidiInputGuard~whole(stringNumber,'stringNumber')
  _fret=.MidiInputGuard~whole(fret,'fret')
  _cost=.MidiInputGuard~number(cost,'cost')
::method noteEvent; expose _noteEvent; return _noteEvent
::method stringNumber; expose _string; return _string
::method fret; expose _fret; return _fret
::method cost; expose _cost; return _cost

::class MidiBassVoicer public
::method standardOpenMidi class
  return .array~of(43,38,33,28)
::method voiceNote class
  use strict arg noteEvent,maxFret=24,preferredFret=5
  opens=self~standardOpenMidi; best=.nil; bestCost=1E99
  do s=1 to 4
    fret=noteEvent~note-opens[s]
    if fret<0 | fret>maxFret then iterate
    cost=abs(fret-preferredFret)+(5-s)*.025
    if cost<bestCost then do
      best=.MidiBassVoice~new(noteEvent,s,fret,cost); bestCost=cost
    end
  end
  return best
::method voiceNotes class
  use strict arg notes,maxFret=24,preferredFret=5
  out=.array~new; rejected=.array~new
  do n over notes
    v=self~voiceNote(n,maxFret,preferredFret)
    if v==.nil then rejected~append(n)
    else out~append(v)
  end
  d=.directory~new; d['voices']=out; d['rejected']=rejected; return d
