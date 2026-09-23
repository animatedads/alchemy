call addPath
p1=.Person~new('CAPONE','AL')
p1~occupation='DEMO PERSON'; p1~photographReference='assets/people/subject-01.png'
p2=.Person~new('CALIGULA','C')
p2~photographReference='assets/people/subject-02.png'
t=.Transcript~new~setText('PERSON A: test' || .endOfLine || 'PERSON B: reply')
t~assignPerson('PERSON A',p1); t~assignPerson('PERSON B',p2)
tm=.TranscriptedMedia~new; tm~title='TEST'; tm~addTranscript(t); tm~addMedia('assets/demo-interview.wav')
r=.Wire3DPresentationRegistry~new; c=.Wire3DLayoutCollection~new('test')
pi=.Wire3DPersonInfoLayout~new; mi=.Wire3DTranscriptedMediaLayout~new
c~put(pi); c~put(mi); r~addCollection(c); r~for(.Person,'inspect',pi); r~for(.TranscriptedMedia,'inspect',mi); .Wire3D~current=r
d=tm~display3d
if d['layout'] <> 'transcriptedMedia' then call fail 'layout'
if d['transcripts'][1]['speakers']~items <> 2 then call fail 'speaker count'
if d['transcripts'][1]['speakers'][1]['headshot']=='' then call fail 'headshot binding'
say 'Wire3D semantic presentation: PASS'; exit 0
fail: say 'FAIL:' arg(1); exit 1
addPath: procedure
 here=filespec('location',parse source . . src)
 call value 'REXX_PATH',here'../src:'here'../examples/domain:'value('REXX_PATH',,'ENVIRONMENT'),'ENVIRONMENT'; return
::requires 'Wire3DAll.cls'
::requires 'CrimeEnterprise.cls'
::requires 'TranscriptedMediaDemo.cls'
