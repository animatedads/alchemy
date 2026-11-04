/* Adverse native input admissions: expected Error 88.900. */
parse arg scenario
provider=.CheckRegistry~new
model=.CheckModel~new
x=.SpashVirtualAudioExecution~new(provider,model)
a=.directory~new;a['FEED_ID']='FC';a['SOURCE_SHA256']=copies('a',64);a['SOURCE_AUTHORITY']='ORIGINAL_OBSERVED_AUDIO'
b=.directory~new;b['FEED_ID']='FD';b['SOURCE_SHA256']=copies('b',64);b['SOURCE_AUTHORITY']='ORIGINAL_OBSERVED_AUDIO'
clock=.directory~new;clock['AUTHORITY']='OBSERVED_CROSS_FEED_ALIGNMENT';clock['CLOCK_MODEL_ID']='clock-measured';clock['UNCERTAINTY_MS']=1
path=.directory~new;path['PATH_ID']='p1';path['METHOD_ID']='AUDIO.MULTIPATH.PATH_ESTIMATE';path['AUTHORITY']='OBSERVED_COHERENT_AUDIO_PATH';path['SOURCE_SHA256']=a['SOURCE_SHA256']
select
  when scenario='SAME_DIGEST' then do
    b['SOURCE_SHA256']=a['SOURCE_SHA256'];ignore=x~plan('p',.array~of(a,b),0,8000,8000,clock,.array~of(path))
  end
  when scenario='NO_HASH' then do
    a['SOURCE_SHA256']='not-a-hash';ignore=x~plan('p',.array~of(a,b),0,8000,8000,clock,.array~of(path))
  end
  when scenario='FAKE_PATH' then do
    path['AUTHORITY']='MODEL_ONLY';ignore=x~plan('p',.array~of(a,b),0,8000,8000,clock,.array~of(path))
  end
  when scenario='WRONG_SOURCE' then do
    path['SOURCE_SHA256']=copies('c',64);ignore=x~plan('p',.array~of(a,b),0,8000,8000,clock,.array~of(path))
  end
  when scenario='GUESS_CLOCK' then do
    clock['AUTHORITY']='FILENAME_TIME';ignore=x~plan('p',.array~of(a,b),0,8000,8000,clock,.array~of(path))
  end
  when scenario='NO_CLOCK_UNCERTAINTY' then do
    clock['UNCERTAINTY_MS']=0;ignore=x~plan('p',.array~of(a,b),0,8000,8000,clock,.array~of(path))
  end
  when scenario='OVERGAIN' then ignore=x~plan('p',.array~of(a,b),0,8000,8000,clock,.array~of(path),65)
  when scenario='VIRTUAL_PROMOTION' then do
    roles=.directory~new
    roles['PREDICTED_SOURCE']='a'; roles['STREET']='b'; roles['STAIRWELL']='c'; roles['OTHER_FLAT']='d'
    ignore=x~virtualField('source',roles)
  end
  when scenario='NO_METHOD' then do
    provider~disable
    ignore=x~plan('p',.array~of(a,b),0,8000,8000,clock,.array~of(path))
  end
  otherwise do; say 'unknown case';exit 7;end
end
say 'INVALID SCENARIO ACCEPTED:' scenario
exit 0
::class CheckRegistry
::method init;expose active;active=.true
::method disable;expose active;active=.false
::method supports;expose active;use strict arg methodId;return active
::method profile;use strict arg methodId;return methodId
::class CheckModel
::method virtualMicrophones
  use strict arg source,positions,emission
  items=.array~new
  do i=1 to positions~items
    d=.directory~new;d['AUTHORITY']='OBSERVED';items~append(d)
  end
  return items
::requires 'SpashVirtualAudioExecution.cls'
