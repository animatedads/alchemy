/* Sydney/Power SLAM v0.35: image-control registration and retrospective
 * occlusion evidence only. User architecture, native ooRexx r13196.
 * Source pixels do NOT provide surveyed 3D pose or ship identity.
 */
numeric digits 18
parse arg source output
if source='' then source='anchor_receipts.psv'
if output='' then output='occlusion_candidate.psv'
if source=output then call fail 'input equals output'
if stream(source,'c','query exists')='' then call fail 'source receipts absent'
refCruise='c3bea629be6f054bafe08d50d03e259f894a97ddeae089dd69d77da0985cae7e'
refBase='58616633e8239ec1f6a0699231f1466279af794d622090086babbc4af01c100d'
refMethod='RETROSPECTIVE_IMAGE_DIFFERENCE_NOT_CAUSAL'
expectHeader='frame|cruise_sha256|baseline_sha256|shift_x_px|shift_y_px|stable_mean_abs_luma|stable_frac_diff_gt35|right_pylon_mean_abs_luma|right_pylon_frac_diff_gt35|waterfront_frac_diff_gt35|channel_frac_diff_gt35|method|evidence_state'
call stream source,'c','open read'
if linein(source)\==expectHeader then call fail 'wrong source schema'
frames=.array~of(150,450,750,900,1050,1350,1650)
evidenceRows=.array~new
n=0;admitted=0;abstain=0;maxControl=0;minTarget=1
/* Use canonical v0.34 CrossSlamEvidence: no mock geographic mapping. */
r=.CrossSlamEvidence~new
if \r~register('CAM3_CRUISE','V5V_VIDEO',refCruise,80,45,'V5V_IMAGE_LATTICE_80x45','OBSERVED_UNTESTED') then call fail 'could not register cruise observation'
if \r~register('CAM3_NORMAL','V5V_VIDEO',refBase,80,45,'V5V_IMAGE_LATTICE_80x45','OBSERVED_UNTESTED') then call fail 'could not register reference observation'
if r~sourceToWorld('CAM3_CRUISE','CAM3_NORMAL')\=='BLOCKED_NO_QUALIFIED_TRANSFORM' then call fail 'unqualified world transform admitted'
do while lines(source)>0
 row=linein(source)
 if countPipes(row)<>12 then call fail 'wrong field count'
 parse var row frame '|' csha '|' bsha '|' dx '|' dy '|' smean '|' sfrac '|' pmean '|' pfrac '|' wfrac '|' chfrac '|' method '|' state
 n=n+1
 if n>7 then call fail 'excess frames'
 if \datatype(frame,'W') | frame<>frames[n] then call fail 'source frame chronology mismatch'
 if csha\==refCruise | bsha\==refBase then call fail 'forged original source SHA'
 if state\=='OBSERVED_UNTESTED' | method\==refMethod then call fail 'authority/cause was promoted'
 if \datatype(dx,'W') | \datatype(dy,'W') then call fail 'non-integer camera offset'
 if abs(dx)>3 | abs(dy)>3 then call fail 'camera translation outside measured search bound'
 values=.array~of(smean,sfrac,pmean,pfrac,wfrac,chfrac)
 do v over values
  if \datatype(v,'N') then call fail 'invalid numeric evidence field'
 end
 if smean<0 | smean>255 | pmean<0 | pmean>255 then call fail 'luma outside physical range'
 if sfrac<0 | sfrac>1 | pfrac<0 | pfrac>1 | wfrac<0 | wfrac>1 | chfrac<0 | chfrac>1 then call fail 'fraction outside physical range'
 if sfrac>maxControl then maxControl=sfrac
 if pfrac<minTarget then minTarget=pfrac
 /* Gate is about mismatched source-visible structure, not ship identity. */
 gate='REVIEW_REGISTRATION_OR_OCCLUSION_UNCERTAIN'
 if smean<20 & sfrac<0.05 & pfrac>max(0.20,sfrac+0.15) then do
  gate='IMAGE_SPACE_STATIC_LANDMARK_DISCREPANCY'
  admitted=admitted+1
 end
 else abstain=abstain+1
 evidenceRows~append(frame||'|'||csha||'|'||bsha||'|'||dx||'|'||dy||'|'||sfrac||'|'||pfrac||'|'||gate||'|RETROSPECTIVE_REFERENCE_ONLY|BLOCKED_NO_QUALIFIED_TRANSFORM|UNVERIFIED|OBSERVED_UNTESTED')
end
call stream source,'c','close'
if n<>7 then call fail 'incomplete source sequence'
call stream output,'c','open write replace'
call lineout output,'frame|cruise_sha256|normal_sha256|offset_x|offset_y|static_control_changed_fraction|pylon_region_changed_fraction|image_space_class|reference_authority|world_position|vessel_identity|evidence_state'
do row over evidenceRows
 call lineout output,row
end
call stream output,'c','close'
say 'IMAGE_SPACE_LANDMARK_PASS frames='n 'consistent_stable_controls_and_pylon_discrepancy='admitted 'abstain='abstain
say 'MAX_STATIC_CONTROL_CHANGED_FRAC='maxControl 'MIN_PYLON_CHANGED_FRAC='minTarget
say 'NO_3D_POSE=BLOCKED_NO_QUALIFIED_TRANSFORM; DIFFERENT_RECORDING_REFERENCE_NOT_CAUSAL; VESSEL_IDENTITY=UNVERIFIED'
exit 0
countPipes: procedure
 use arg s
 n=0
 do j=1 to length(s)
  if substr(s,j,1)=='|' then n=n+1
 end
 return n
fail: procedure
 use arg why
 say 'IMAGE_SPACE_LANDMARK_REJECT:' why
 exit 3
::requires 'CrossSlamEvidence.cls'
