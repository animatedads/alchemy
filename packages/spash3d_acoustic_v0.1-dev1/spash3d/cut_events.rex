/* cut_events.rex -- 4 s FD and FC listening cuts (+22 dB, -1 dBFS limiter on export) around located impulses.
 * Coding: Claude (Opus 5.5). usage: cut_events.rex outDir t1 [t2 ...]  (FD-clock hh:mm:ss.sss) */
numeric digits 20
parse arg outDir rest
parse value value('SPASH_CLOCK',,'ENVIRONMENT') with cA cB
ch=fcfdChains(value('SPASH_PCM',,'ENVIRONMENT'),'CONTINUOUS')
do w over rest~space~makeArray(' ')
  parse var w hh ':' mm ':' ss; t=hh*3600+mm*60+ss; off=cA+cB*(t-hms2sec('120000'))/3600
  tag=w~changestr(':','-')
  ch['FD']~writeWindow(t-2,32000,outDir'/'tag'_FD.f32'); ch['FC']~writeWindow(t+off-2,32000,outDir'/'tag'_FC.f32')
  do fd over .array~of('FD','FC')
    f=outDir'/'tag'_'fd; address system 'ffmpeg -v error -nostdin -y -f f32le -ar 8000 -ac 1 -i "'f'.f32" -af "volume=22dB,alimiter=limit=0.89:level=disabled" -c:a pcm_s16le "'f'.wav"'
    call sysFileDelete f'.f32'
  end
end
::requires 'FeedChain.cls'
