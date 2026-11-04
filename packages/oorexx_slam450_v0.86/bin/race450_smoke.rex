/* Autonomous two-aircraft observation-only smoke flight. The separate
 * ORACLE_ONLY CSV is written AFTER both pilots have issued controls. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg prefix maxSteps
if prefix=='' then prefix='race450_smoke'
if maxSteps=='' then maxSteps=12
race=.Slam450RaceReferee~new(45042,'LEGACY',.true)
p1=.Slam450LearningPilot~new
p2=.Slam450LearningPilot~new
t1=.Slam450RaceTactics~new('A1',48)
t2=.Slam450RaceTactics~new('A2',48)
avoid1=.Slam450RivalAvoidance~new
avoid2=.Slam450RivalAvoidance~new
call lineout prefix||'_decisions.csv','step,a1_action,a1_target,a1_context,a2_action,a2_target,a2_context,step_result'
call lineout prefix||'_truth_ORACLE_ONLY.csv','step,a1_east_m,a1_north_m,a1_z_m,a1_yaw_deg,a2_east_m,a2_north_m,a2_z_m,a2_yaw_deg,claims'
call lineout prefix||'_wind_observations.csv','step,a1_pitot_mps,a1_cup_mps,a1_sail,a2_pitot_mps,a2_cup_mps,a2_sail'
call lineout prefix||'_claims.csv','step,number,winner,time_within_step,claim_status'
priorEvent=0
rc='RUNNING'
do tick=1 to maxSteps
  current=0;next=0
  do i=1 to 5
    if \race~claimed~hasIndex(i) then do
      if current==0 then current=i
      else if next==0 then do;next=i;leave;end
    end
  end
  if current==0 then leave
  if next==0 then next=current
  f1=race~frame('A1',360,91)
  f2=race~frame('A2',360,91)
  d1=t1~choose(f1,current,next,tick)
  d2=t2~choose(f2,current,next,tick)
  c1=p1~control(f1,d1['TARGET'])
  c2=p2~control(f2,d2['TARGET'])
  c1=avoid1~filter(f1,c1,tick)
  c2=avoid2~filter(f2,c2,tick)
  rc=race~stepBoth(c1,c2)
  call lineout prefix||'_decisions.csv',tick||','||d1['ACTION']||','||d1['TARGET']||','||d1['CONTEXT']||','||d2['ACTION']||','||d2['TARGET']||','||d2['CONTEXT']||','||rc
  /* The oracle receipt must NEVER be fed into decide/control/ingestWind. */
  truth=race~oracleSnapshot
  a=truth['A1'];b=truth['A2']
  call lineout prefix||'_truth_ORACLE_ONLY.csv',truth['STEP']||','||a[1]||','||a[2]||','||a[3]||','||a[4]||','||b[1]||','||b[2]||','||b[3]||','||b[4]||','||truth['CLAIM_COUNT']
  if rc=='RUNNING' | rc=='ALL_TARGETS_CLAIMED' then do
    w1=race~sensors('A1');w2=race~sensors('A2')
    if w1\==.nil & w2\==.nil then do
      ignored=p1~ingestWind(tick,w1,p1~lastVisualEvidence)
      ignored=p2~ingestWind(tick,w2,p2~lastVisualEvidence)
      call lineout prefix||'_wind_observations.csv',tick||','||w1['PITOT_FORWARD_MPS']||','||w1['CUP_AIRSPEED_MPS']||','||w1['SAIL']||','||w2['PITOT_FORWARD_MPS']||','||w2['CUP_AIRSPEED_MPS']||','||w2['SAIL']
    end
    do j=priorEvent+1 to race~events~items
      ev=race~events[j]
      fraction='UNKNOWN'
      if ev~hasIndex('TIME_WITHIN_STEP') then fraction=ev['TIME_WITHIN_STEP']
      call lineout prefix||'_claims.csv',ev['STEP']||','||ev['TARGET']||','||ev['WINNER']||','||fraction||','||ev['STATUS']
      if ev['TARGET']==d1['TARGET'] then do
        if ev['WINNER']=='A1' then ignored=t1~outcome(d1['DECISION_ID'],'SELF_CLAIMED')
        if ev['WINNER']=='A2' then ignored=t1~outcome(d1['DECISION_ID'],'RIVAL_CLAIMED')
      end
      if ev['TARGET']==d2['TARGET'] then do
        if ev['WINNER']=='A2' then ignored=t2~outcome(d2['DECISION_ID'],'SELF_CLAIMED')
        if ev['WINNER']=='A1' then ignored=t2~outcome(d2['DECISION_ID'],'RIVAL_CLAIMED')
      end
    end
    priorEvent=race~events~items
  end
  if rc\=='RUNNING' then leave
end
call stream prefix||'_decisions.csv','C','CLOSE'
call stream prefix||'_truth_ORACLE_ONLY.csv','C','CLOSE'
call stream prefix||'_wind_observations.csv','C','CLOSE'
call stream prefix||'_claims.csv','C','CLOSE'
say 'SLAM450 DUAL AIRCRAFT' rc 'STEPS' race~clock 'CLAIMS' race~claimed~items
say 'A1 PRIVATE MEMORY' p1~memory~slots~items 'WIND' p1~windMemory~slots~items 'TACTICS' t1~notes~items
say 'A2 PRIVATE MEMORY' p2~memory~slots~items 'WIND' p2~windMemory~slots~items 'TACTICS' t2~notes~items
exit 0
::requires 'Slam450RaceReferee.cls'
::requires 'Slam450Learning.cls'
