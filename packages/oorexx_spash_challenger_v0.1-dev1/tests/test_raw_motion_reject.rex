/* Rejections must come from the real ooRexx source clock, not shell validation. */
parse arg scenario
if scenario=='' then exit 7
source='tests/fixture.samples.tsv';run='tests/fixture.run.tsv'
tempSamples='tests/reject.samples.'||scenario||'.tmp'
tempRun='tests/reject.run.'||scenario||'.tmp'
call stream tempSamples,'C','CLOSE'
call stream tempRun,'C','CLOSE'
do while lines(source)>0
  l=linein(source)
  select
    when scenario='WRONG_PTS' then l=changestr('151200','151000',l)
    when scenario='SKIPPED_FRAME' then l=changestr('synthetic.mp4'||'09'x||'25'||'09'x,'synthetic.mp4'||'09'x||'29'||'09'x,l)
    when scenario='SOURCE_SWAP' then l=changestr('synthetic.mp4'||'09'x||'24'||'09'x,'alien.mp4'||'09'x||'24'||'09'x,l)
    when scenario='NONMONOTONE' then l=changestr('151200','140000',l)
    otherwise nop
  end
  call lineout tempSamples,l
end
call stream source,'C','CLOSE';call stream tempSamples,'C','CLOSE'
do while lines(run)>0
  l=linein(run)
  select
    when scenario='WRONG_RUN_COUNT' then l=changestr('09'x||'5'||'09'x||'0'||'09'x||'1'||'09'x,'09'x||'4'||'09'x||'0'||'09'x||'1'||'09'x,l)
    when scenario='WRONG_TIME_BASE' then l=changestr('09'x||'90000'||'09'x,'09'x||'100000'||'09'x,l)
    otherwise nop
  end
  call lineout tempRun,l
end
call stream run,'C','CLOSE';call stream tempRun,'C','CLOSE'
obj=.SpashRawMotionClock~new
n=obj~load(tempSamples,tempRun)
say 'FAIL malformed source was accepted:' scenario n
exit 0
::requires 'SpashRawMotionClock.cls'
