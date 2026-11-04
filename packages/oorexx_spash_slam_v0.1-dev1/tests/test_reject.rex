/* Run one explicit negative fixture. Expected outcome: Error 88.900. */
parse arg testName
b=.array~of(2,2,1)
select
  when testName=='BAD_SAMPLE' then o=.SpashObservation~new('f','not-a-number',10,1000,0,300,80,200,b,1)
  when testName=='BAD_VECTOR' then o=.SpashObservation~new('f',0,10,1000,0,300,80,200,.array~of(0,0),1)
  when testName=='BAD_PITCH' then o=.SpashObservation~new('f',0,10,1000,0,300,80,'rising',b,1)
  when testName=='DUPLICATE' then do
    g=.SpashGraph~new
    o=.SpashObservation~new('f',0,10,1000,0,300,80,200,b,1)
    g~add(o)
    g~add(o)
  end
  when testName=='UNKNOWN_STEP' then do
    g=.SpashGraph~new
    g~replayPlan(.array~of('unknown'))
  end
  when testName=='NONEDGE_REPLAY' then do
    g=.SpashGraph~new
    x=.SpashObservation~new('f',0,10,1000,0,300,80,200,b,1)
    y=.SpashObservation~new('f',500,10,1000,0,300,80,200,b,1)
    g~add(x);g~add(y)
    g~replayPlan(.array~of(x~id,y~id))
  end
  when testName=='CROSSFEED_REPLAY' then do
    g=.SpashGraph~new
    x=.SpashObservation~new('f',0,10,1000,0,300,80,200,b,1)
    y=.SpashObservation~new('g',20,10,1000,0,300,80,200,b,1)
    g~add(x);g~add(y)
    g~replayPlan(.array~of(x~id,y~id))
  end
  when testName=='INVALID_SPEED' then spatial=.SpashSpatialExperiment~new(0)
  when testName=='INVALID_METHOD' then o=.SpashObservation~new('f',0,10,1000,0,300,80,200,b,1,.nil,'','STFT')
  otherwise do
    say 'Unknown rejection test:' testName
    exit 7
  end
end
say 'UNEXPECTED ADMISSION:' testName
exit 0
::requires 'SpashGraph.cls'
::requires 'SpashSpatial.cls'
