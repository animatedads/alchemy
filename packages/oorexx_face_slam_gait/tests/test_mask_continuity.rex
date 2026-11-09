/* Native ooRexx test: temporal source and observation authority. */
numeric digits 30
passed=0
source='8e236084a0a9068037bd8dde61d0d600f6de27ee6f3d07d83250c3aef287e76c'
model='annotation:manual-review-v1'
track='WOMAN_WHITE_BLOUSE_A'
a=.FaceSlamMaskContinuity~new(source,'camera1',track,model)
call eq .nil,a~event,'no event initially'
call addFrame 94, 'VISIBLE','MOSAIC',1
call eq .nil,a~event,'masked state'
do n=95 to 99
 call addFrame n,'OCCLUDED','UNKNOWN',1
end
call eq .nil,a~event,'occlusion cannot declare unmask'
call addFrame 100,'VISIBLE','UNMASKED',1
call eq 'POST_OCCLUSION_MASK_LOSS_CANDIDATE',a~event~kind,'correct hypothesis'
call eq 3760000,a~event~maskedUntilUs,'last masked microseconds'
call eq 4000000,a~event~unmaskedFromUs,'first unmasked microseconds'
call eq 'REVIEW_CANDIDATE',a~event~status,'one observation not confirmed'
call addFrame 101,'VISIBLE','UNMASKED',1
call eq 'REPEATED_OBSERVATION',a~event~status,'two visible observations'
call eq 2,a~event~observedUnmaskedFrames,'observation count'
call eq 8,a~count,'event count'
call eq source,a~event~sourceDigest,'source retained'
b=.FaceSlamMaskContinuity~new(source,'camera1',track,model)
b~add(.FaceSlamMaskObservation~new(source,'camera1',track,model,1000000,'VISIBLE','MOSAIC',1))
b~add(.FaceSlamMaskObservation~new(source,'camera1',track,model,1040000,'VISIBLE','UNMASKED',1))
call eq 'DIRECT_MASK_LOSS_CANDIDATE',b~event~kind,'direct loss is distinct'
c=.FaceSlamMaskContinuity~new(source,'camera1',track,model)
c~add(.FaceSlamMaskObservation~new(source,'camera1',track,model,1000000,'VISIBLE','MOSAIC',1))
c~add(.FaceSlamMaskObservation~new(source,'camera1',track,model,1040000,'PARTIAL','UNMASKED',1))
call eq .nil,c~event,'partial view abstention'
c~add(.FaceSlamMaskObservation~new(source,'camera1',track,model,1080000,'VISIBLE','UNMASKED',.2))
call eq .nil,c~event,'low confidence abstention'
c~add(.FaceSlamMaskObservation~new(source,'camera1',track,model,1120000,'VISIBLE','UNKNOWN',1))
call eq .nil,c~event,'unknown mask abstention'
c~add(.FaceSlamMaskObservation~new(source,'camera1',track,model,1160000,'VISIBLE','UNMASKED',1))
call eq 'REVIEW_CANDIDATE',c~event~status,'valid observation after low confidence'
call expectInvalid 'a~add(.FaceSlamMaskObservation~new(source,"wrong",track,model,4080000,"VISIBLE","MOSAIC",1))','camera fencing'
call expectInvalid 'a~add(.FaceSlamMaskObservation~new(source,"camera1",track,model,4040000,"VISIBLE","MOSAIC",1))','non-monotonic PTS'
call expectInvalid 'a~add(.FaceSlamMaskObservation~new(source,"camera1",track,model,4080000,"OCCLUDED","MOSAIC",1))','no false mask claim when occluded'
call expectInvalid 'a~add(.FaceSlamMaskObservation~new(source,"camera1",track,"different-model",4080000,"VISIBLE","MOSAIC",1))','model fencing'
call expectInvalid 'a~add(.FaceSlamMaskObservation~new("invalidsha","camera1",track,model,4080000,"VISIBLE","MOSAIC",1))','SHA256 provenance validation'
long=.FaceSlamMaskContinuity~new(source,'camera1','LONG_PTS',model)
long~add(.FaceSlamMaskObservation~new(source,'camera1','LONG_PTS',model,'9007199254740996','VISIBLE','MOSAIC',1))
long~add(.FaceSlamMaskObservation~new(source,'camera1','LONG_PTS',model,'9007199254741996','VISIBLE','UNMASKED',1))
call eq '9007199254741996',long~event~unmaskedFromUs,'source ticks above binary64 integer precision'
say 'MASK CONTINUITY PASS:'passed
exit 0
addFrame: procedure expose a source track model
 parse arg n,vis,mask,confidence
 a~add(.FaceSlamMaskObservation~new(source,'camera1',track,model,n*40000,vis,mask,confidence))
 return
 eq: procedure expose passed
 use strict arg expected,actual,message
 if expected==.nil then do
   if actual\==.nil then call failure message
 end
 else if actual\==expected then call failure message||' expected='||expected||' actual='||actual
 passed=passed+1
 return
 expectInvalid: procedure expose a source track model passed
 use strict arg code,label
 signal on syntax name catchInvalid
 interpret code
 signal off syntax
 call failure 'expected rejection for '||label
 return
 catchInvalid:
 signal off syntax
 passed=passed+1
 return
 failure: procedure
 use strict arg message
 say 'FAIL:'message
 exit 1
::requires 'FaceSlamMaskContinuity.cls'