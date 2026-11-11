/* Validate ooRexx API, not native PCM or seek correctness. */
s=.SpashNativeOggSeek~new('mock-bridge')
call require s~catalogue('a.ogg','catalogue.tsv',64)=='catalogue.tsv','catalogue API'
call require s~decode('a.ogg','work.f32','work.tsv',0,0,980000,6000,8000,64)=='work.f32','multistream deep seek API'
say 'PASS ooRexx wrapper API positive contract only; native IO NOT TESTED'
exit 0
require: procedure
  use arg condition,desc
  if \condition then do
    say 'FAIL' desc
    exit 4
  end
  return
::requires 'SpashNativeOggSeek.cls'
