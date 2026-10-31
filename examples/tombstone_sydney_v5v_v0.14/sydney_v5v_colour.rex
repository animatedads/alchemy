/* Tombstone ooRexx V5V scene-palette qualification.
   Explicit 26-colour model; quantization before semantic analysis.
   This is a test palette, NOT yet Vision three-curve optimiser.
   FFmpeg is only raw RGB24 source adapter, not classifier. */
parse arg input output sourceHash
if input='' | output='' then exit 2
w=80;h=45;pixels=w*h;ncolors=26
/* Deliberate fixed colour classes: sky, water, ferry yellow, land/structures.
   The actual scheme will be optimized by VisionPaletteSelector in production. */
colours='150,180,214 120,157,207 100,135,185 175,197,222 191,202,217 88,124,175' ,
 '34,67,108 52,84,124 71,105,137 87,121,151 107,140,162 40,92,133 57,104,142 75,128,160' ,
 '229,185,77 212,173,71 245,211,122 192,150,54 225,202,112 174,133,63' ,
 '144,145,143 181,171,155 206,192,166 112,110,103 82,102,79 62,70,72'
r=.array~new(26);g=.array~new(26);b=.array~new(26)
do i=1 to 26
 rgb=word(colours,i)
 parse var rgb rr ',' gg ',' bb
 r[i]=rr;g[i]=gg;b[i]=bb
end
model=.VisionColourModel~new(r,g,b)
/* Quantized 4-bit/channel palette LUT avoids 26 distance tests per sample.
   Source reduction is intentionally lossy; V5V exactness is relative to
   the indexed surface. This LUT is a source adapter, not classification. */
lookup=.array~new(4096)
do ri=0 to 15
 do gi=0 to 15
  do bi=0 to 15
   vr=ri*16+8;vg=gi*16+8;vb=bi*16+8
   nearest=0;minDist=-1
   do q=1 to ncolors
    dr=vr-r[q];dg=vg-g[q];db=vb-b[q]
    d2=dr*dr+dg*dg+db*db
    if minDist=-1 | d2<minDist then do
     minDist=d2;nearest=q-1
    end
   end
   address=(ri*256+gi*16+bi)+1
   lookup[address]=nearest
  end
 end
end
e=.V5VTemporalCodec~new(.V5VCodecPolicy~new(10))
d=.V5VTemporalCodec~new(.V5VCodecPolicy~new(10))
regionExtractor=.VisionChangeRegionExtractor~new(8,3)
call stream input,'c','open read'
call stream output,'c','open write replace'
call lineout output,'frame|record|changed_cells|fraction|regions_ge3|ferry_palette_cells|roundtrip_exact|source_ref|evidence_state'
frame=0;total=0;yellowCells=0
if length(sourceHash)<>64 then do
 say 'FAIL missing authoritative source hash'
 exit 2
end
source='sha256:'||sourceHash
do forever
 data=charin(input,,pixels*3)
 if length(data)=0 then leave
 if length(data)<>pixels*3 then exit 3
 surface=.VisionSurface~new(w,h,5,26,model)
 surface~sourceRef=source;surface~timestamp=frame/5;surface~generation=frame
 ferryCells=0
 do pos=0 to pixels-1
  offset=pos*3
  pr=c2d(substr(data,offset+1,1));pg=c2d(substr(data,offset+2,1));pb=c2d(substr(data,offset+3,1))
  address=(pr%16)*256+(pg%16)*16+(pb%16)+1
  index=lookup[address]
  surface~packed~put(pos,index)
  if index>=14 & index<=19 then ferryCells=ferryCells+1
 end
 rec=e~encodeSurface(surface)
 back=d~decodeRecord(rec)
 exact=1
 do j=0 to pixels-1
  if surface~packed~at(j)<>back~packed~at(j) then do
   exact=0;leave
  end
 end
 if back~sourceRef<>source then exact=0
 if exact<>1 then do
  say 'FAILED EXACT RECONSTRUCTION' frame
  exit 4
 end
 if rec~recordType='DELTA' then do
  regions=regionExtractor~extract(rec~payload)
  reg=regions~items
 end
 else reg=0
 changed=rec~changedCount
 call lineout output,frame||'|'||rec~recordType||'|'||changed||'|'||(changed/pixels)||'|'||reg||'|'||ferryCells||'|'||exact||'|'||source||'|OBSERVED_UNTESTED'
 yellowCells=yellowCells+ferryCells
 total=total+changed
 frame=frame+1
end
call stream input,'c','close';call stream output,'c','close'
say 'VISION V5V REAL COLOUR PASS frames='frame 'mean_changed='total/frame 'ferry_palette_cell_count='yellowCells
exit 0
::requires 'V5VCodec.cls'
