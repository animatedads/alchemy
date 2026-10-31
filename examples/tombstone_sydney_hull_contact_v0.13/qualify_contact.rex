/* Tombstone Sydney 0.13: fail-closed contact-proxy evidence admission.
   Requires the independent blind detection, CV-derived edge audit and
   exact corresponding geometrical pixel observations in chronological order.
   Checks provenance linkage, not pixel truth or geographic survey accuracy. */
numeric digits 18
parse arg detections audit pixels output
if detections='' | audit='' | pixels='' | output='' then call bad 'USAGE detections audit pixels output'
if output=detections | output=audit | output=pixels then call bad 'output overlaps input'
if stream(detections,'c','query exists')='' | stream(audit,'c','query exists')='' | stream(pixels,'c','query exists')='' then call bad 'missing input'
if linein(detections)<>'frame|time_s|status|x_center|y_center|x|y|width|height|yellow_motion_area_half|n_candidates' then call bad 'detections header'
if linein(audit)<>'frame|time_s|centre_x|centre_y|edge_x|edge_y|offset_px|row_support|method|model_state' then call bad 'audit header'
if linein(pixels)<>'frame|time_s|u_px|v_px' then call bad 'geometry header'
n=0; lastFrame=-1;lastTime=-1; minOffset=100000; maxOffset=0
sumOffset=0
/* No output is opened until ALL records pass. */
do while lines(detections)>0
 d=linein(detections)
 if d='' then call bad 'empty detection row'
 if lines(audit)<=0 | lines(pixels)<=0 then call bad 'unmatched input lengths'
 a=linein(audit); p=linein(pixels)
 if countstr('|',d)<>10 | countstr('|',a)<>9 | countstr('|',p)<>3 then call bad 'column count'
 parse var d frame '|' tt '|' state '|' cx '|' cy '|' dx '|' dy '|' dw '|' dh '|' da '|' dn
 parse var a aframe '|' atime '|' acx '|' acy '|' ex '|' ey '|' offset '|' support '|' method '|' geom
 parse var p pframe '|' ptime '|' px '|' py
 if \datatype(frame,'W') | \datatype(tt,'N') | \datatype(cx,'N') | \datatype(cy,'N') | \datatype(dw,'W') | \datatype(dh,'W') then call bad 'untyped detection'
 if \datatype(aframe,'W') | \datatype(atime,'N') | \datatype(acx,'N') | \datatype(acy,'N') | \datatype(ex,'N') | \datatype(ey,'N') | \datatype(offset,'N') | \datatype(support,'N') then call bad 'untyped audit'
 if \datatype(pframe,'W') | \datatype(ptime,'N') | \datatype(px,'N') | \datatype(py,'N') then call bad 'untyped metric input'
 if frame<>aframe | frame<>pframe | abs(tt-atime)>.000001 | abs(tt-ptime)>.000001 then call bad 'unmatched row identity/time'
 if frame<=lastFrame | tt<=lastTime then call bad 'non-monotonic row'
 if state<>'candidate' | method<>'WARM_HULL_LOWER_EDGE_PROXY' | geom<>'APPROXIMATE_UNSURVEYED' then call bad 'invalid evidence state'
 if dw<=0 | dh<=0 | dn<1 | da<=0 then call bad 'invalid region'
 if abs(acx-cx)>.000001 | abs(acy-cy)>.000001 | abs(ex-cx)>.000001 | abs(px-ex)>.000001 | abs(py-ey)>.000001 then call bad 'pixel linkage failure'
 if abs((ey-cy)-offset)>.000001 then call bad 'offset inconsistency'
 if ey<=cy | ey>=1080 | ex<0 | ex>=1920 | offset>dh*.8+5 then call bad 'contact outside admissible range'
 if support<.2 | support>1 then call bad 'insufficient row support'
 if frame<0 | tt<0 | cy<0 | cy>=1080 then call bad 'coordinate bounds'
 n=n+1;lastFrame=frame;lastTime=tt;sumOffset=sumOffset+offset
 if offset<minOffset then minOffset=offset
 if offset>maxOffset then maxOffset=offset
end
if n<2 | lines(audit)>0 | lines(pixels)>0 then call bad 'unmatched row count'
call stream detections,'c','close'
call stream audit,'c','close'
call stream pixels,'c','close'
call stream output,'c','open write replace'
call lineout output,'schema|tombstone.hull-contact/0.13'
call lineout output,'observations|'||n
call lineout output,'mean_pixel_offset|'||(sumOffset/n)
call lineout output,'minimum_pixel_offset|'||minOffset
call lineout output,'maximum_pixel_offset|'||maxOffset
call lineout output,'evidence_state|OBSERVED_UNTESTED'
call lineout output,'geometry_state|APPROXIMATE_UNSURVEYED'
call stream output,'c','close'
say 'TOMBSTONE HULL CONTACT 0.13 PASS observations='n
exit 0
bad: procedure
parse arg msg
say 'TOMBSTONE HULL CONTACT 0.13 BLOCKED:' msg
exit 2
