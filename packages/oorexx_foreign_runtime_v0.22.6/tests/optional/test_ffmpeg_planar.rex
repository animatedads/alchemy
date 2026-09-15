ff=.foreign~load('ffmpeg_planar.bridge.json')
fixture=.foreign~load('../../examples/test.bridge.json')
a=.foreign~buffer(16); b=.foreign~buffer(16)
ignored=fixture~fill_bytes(a,16); ignored=fixture~fill_bytes(b,16)
if a~hex='00000000000000000000000000000000' then do; say 'FAIL precondition plane A'; exit 1; end
planes=.foreign~pointerArray(2,'u8')
planes~put(a,1); planes~put(b,2)
rc=ff~samples_set_silence(planes,0,4,2,8)
if rc<0 then do; say 'FAIL av_samples_set_silence rc='rc; exit 2; end
zeros='00000000000000000000000000000000'
if a~hex<>zeros then do; say 'FAIL plane A not silenced:' a~hex; exit 3; end
if b~hex<>zeros then do; say 'FAIL plane B not silenced:' b~hex; exit 4; end
say 'PASS Foreign Runtime -> FFmpeg planar uint8_t **'
planes~close; a~close; b~close; fixture~close; ff~close
exit 0
::requires '../../rexx/foreign.cls'
