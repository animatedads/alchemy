/* acoustic_map_table.rex -- Physics World predictions for every candidate source position.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * For each grid point: F11 v0.4 scene impulse response at FD and FC (direct/transmitted + first-order
 * specular reflections, 150 ms), per-band pressure magnitude for the seven SPASH bands.
 * Geometry is static, so this table is computed once and reused for every analysis window.
 * usage: acoustic_map_table.rex outTsv shard nShards
 */
numeric digits 20
parse arg outTsv shard nShards .
if shard='' then do; shard=1; nShards=1; end
/* Arrival delays are frequency independent; three representative bands carry the amplitude pattern. */
freq=.array~of(400,1000,2150)
sc=.F11SceneV04~new(freq)
e=.AcousticEmissionSpectrum~new; do f over freq; e~addBand(.AcousticEmissionBand~new(f,0.001)); end
pts=.array~new
step=value('SPASH_MAP_STEP',,'ENVIRONMENT'); if step='' then step=1.0
do y=step/2 to 10.0 by step; do x=step/2 to 20.0 by step; pts~append(x y 4.8 'INTERIOR'); end; end
do y=10.5 to 14.0 by 1.0; do x=0.5 to 20.0 by 1.0; pts~append(x y 1.6 'STREET'); end; end
do y=-3.5 to -0.5 by 1.0; do x=0.5 to 20.0 by 1.0; pts~append(x y 1.6 'REAR'); end; end
do z over .array~of(0.8,1.6,2.4); do y=0.5 to 3.5 by 1.0; do x over .array~of(5.75,6.25,6.75); pts~append(x y z 'STAIRWELL_SHAFT'); end; end; end
o=.stream~new(outTsv); o~open('WRITE REPLACE')
hdr='point_id'||'09'x||'x_m'||'09'x||'y_m'||'09'x||'z_m'||'09'x||'region'||'09'x||'room'||'09'x||'receiver'||'09'x||'rank'||'09'x||'delay_ms'||'09'x||'kind'
do f over freq; hdr=hdr||'09'x||'amp_'f; end
o~lineout(hdr||'09'x||'path')
t0=time('E'); done=0
do i=1 to pts~items
  if (i-1)//nShards<>shard-1 then iterate
  parse value pts[i] with x y z region
  room=.F11SceneV04~roomAt(x,y); if region<>'INTERIOR' then room=region
  r=sc~solver~solve(sc~point(x,y,z),e,sc~receivers,0.150)
  do rn over .array~of('FD','FC')
    k=0
    do a over r~receiver(rn)~arrivals
      k+=1
      line=i'09'x||x'09'x||y'09'x||z'09'x||region'09'x||room'09'x||rn'09'x||k'09'x||format(a~delay*1000,,4)'09'x||a~kind
      do f over freq; ph=a~phasorAt(f); if ph==.nil then m=0; else m=ph~magnitude; line=line||'09'x||format(m,,,,3); end
      o~lineout(line||'09'x||a~pathSignature)
    end
  end
  done+=1
  if done//25=0 then say 'shard' shard 'points' done 'elapsed' format(time('E')-t0,,0)'s'
end
o~close
say 'shard' shard 'DONE points' done 'of' pts~items 'elapsed' format(time('E')-t0,,0)'s'
exit 0
::requires 'F11SceneV04.cls'
