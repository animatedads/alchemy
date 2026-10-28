#!/usr/bin/env rexx
c=.AudioV9CoherenceContinuation~new('veh-pass-1','FD',0,41,40,31,40.5,38.13,38.95,37.31,39.7,.true,2000,17)
if c~trajectoryId<>'veh-pass-1' then exit 10
if c~frameCount<>41 then exit 11
s=c~summary
if s==.nil then exit 12
if s['motion_induced_coherence']<=0 then exit 13
m=.AudioV9FencedMemoryBlockRef~new('mf','block-17',3,'provider-mi-4',9)
p=.AudioV9MemoryBlockContinuationPlan~new(m,.nil,c)
if p~authority<>'PLAN_ONLY_MEMORY_FABRIC_OWNS_BLOCKS_JOB_TO_NODE_OWNS_PLACEMENT' then exit 14
if p~currentRef~blockId<>'block-17' then exit 15
say 'PASS AudioV9 continuation object contract under r13196 with directive ordering repaired in qualification harness'
exit 0
::requires 'AudioV9CoherenceContinuation.cls'
::requires 'AudioV9ExecutionIntegration.cls'
