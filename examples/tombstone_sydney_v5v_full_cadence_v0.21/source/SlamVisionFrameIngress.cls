/* SLAM vision frame sidecar, additive schema ONLY, no change to code-node
   shape/edge/weight/TESTED tables. Uses canonical SlamStore RexxSQL backend.
   Expected caller runs verify_v5v_frame_series.rex BEFORE ingestion.
   Source docs: v0.21 Sydney native full-cadence V5V experiment.
   This adapter has syntax qualification only in isolated container.
 */
::class SlamVisionFrameIngress public
::method init
 expose store
 use strict arg databasePath
 store=.SlamStore~new(databasePath)
 store~q('CREATE TABLE IF NOT EXISTS vision_source (source_ref TEXT PRIMARY KEY, original_sha256 TEXT NOT NULL, mask_sha256 TEXT NOT NULL, width INTEGER NOT NULL, height INTEGER NOT NULL, bits INTEGER NOT NULL, value_count INTEGER NOT NULL, state TEXT NOT NULL)')
 store~q('CREATE TABLE IF NOT EXISTS vision_frame (source_ref TEXT NOT NULL, frame_index INTEGER NOT NULL, node_id TEXT NOT NULL UNIQUE, timestamp_seconds REAL NOT NULL, v5v_record TEXT NOT NULL, changed_cells INTEGER NOT NULL, water_changed INTEGER NOT NULL, excluded_changed INTEGER NOT NULL, payload_offset INTEGER NOT NULL, payload_bytes INTEGER NOT NULL, evidence_state TEXT NOT NULL, PRIMARY KEY(source_ref,frame_index))')
 store~q('CREATE TABLE IF NOT EXISTS vision_next (source_ref TEXT NOT NULL, previous_node_id TEXT NOT NULL, current_node_id TEXT NOT NULL, dt_seconds REAL NOT NULL, evidence_state TEXT NOT NULL, PRIMARY KEY(source_ref,previous_node_id,current_node_id))')
 store~q('CREATE TABLE IF NOT EXISTS vision_motion_structure (source_ref TEXT NOT NULL, frame_index INTEGER NOT NULL, water_change_cells INTEGER NOT NULL, water_components INTEGER NOT NULL, isolated_components INTEGER NOT NULL, largest_component INTEGER NOT NULL, temporal_neighbour_cells INTEGER NOT NULL, temporal_support_ratio REAL NOT NULL, motion_structure TEXT NOT NULL, evidence_state TEXT NOT NULL, PRIMARY KEY(source_ref,frame_index))')

::method close
 expose store
 store~close

::method ingestVerified
 expose store
 use strict arg sourceHash,maskHash,expectedCount,nodeFile,edgeFile,temporalFile
 if length(sourceHash)<>64 | length(maskHash)<>64 then raise syntax 40.900 array('hash length')
 if verify(sourceHash,'0123456789abcdef')<>0 | verify(maskHash,'0123456789abcdef')<>0 then raise syntax 40.900 array('hash alphabet')
 if \datatype(expectedCount,'W') | expectedCount<2 then raise syntax 40.900 array('source frame count')
 if stream(nodeFile,'c','query exists')='' | stream(edgeFile,'c','query exists')='' | stream(temporalFile,'c','query exists')='' then raise syntax 40.900 array('evidence files absent')
 source='sha256:'||sourceHash
 existing=store~scalar('SELECT count(*) AS n FROM vision_source WHERE source_ref = ?',store~binds(source))
 if existing<>0 then raise syntax 40.900 array('source already present; no silent rewrite')
 signal on syntax name rollbackAdmission
 store~begin
 store~q('INSERT INTO vision_source VALUES (?,?,?,?,?,?,?,?)',store~binds(source,sourceHash,maskHash,80,45,5,26,'OBSERVED_UNTESTED'))
 call stream nodeFile,'c','open read'
 if linein(nodeFile)\=='node_id|frame_index|timestamp_seconds|v5v_record|changed_cells|water_changed|excluded_changed|payload_offset|payload_bytes|source_ref|evidence_state' then raise syntax 40.900 array('invalid node header')
 nodes=0
 do while lines(nodeFile)>0
  row=linein(nodeFile)
  parse var row id '|' frame '|' pts '|' record '|' changed '|' water '|' excluded '|' offset '|' bytes '|' ref '|' state
  if ref\==source | state\=='OBSERVED_UNTESTED' | frame<>nodes | changed<>water+excluded then raise syntax 40.900 array('invalid frame receipt')
  store~q('INSERT INTO vision_frame VALUES (?,?,?,?,?,?,?,?,?,?,?)',store~binds(source,frame,id,pts,record,changed,water,excluded,offset,bytes,state))
  nodes=nodes+1
 end
 call stream nodeFile,'c','close'
 if nodes<>expectedCount then raise syntax 40.900 array('incomplete frame graph')
 call stream edgeFile,'c','open read'
 if linein(edgeFile)\=='from_id|to_id|dt_seconds|relation|evidence_state' then raise syntax 40.900 array('invalid edge header')
 edges=0
 do while lines(edgeFile)>0
  row=linein(edgeFile)
  parse var row from '|' to '|' dt '|' relation '|' state
  if relation\=='NEXT_SOURCE_FRAME' | state\=='OBSERVED_UNTESTED' then raise syntax 40.900 array('edge state invalid')
  store~q('INSERT INTO vision_next VALUES (?,?,?,?,?)',store~binds(source,from,to,dt,state))
  edges=edges+1
 end
 call stream edgeFile,'c','close'
 if edges<>nodes-1 then raise syntax 40.900 array('missing source frame edges')
 call stream temporalFile,'c','open read'
 if linein(temporalFile)\=='node_id|frame_index|source_pts|water_change_cells|water_components|isolated_components|largest_component|temporal_neighbour_cells|temporal_support_ratio|motion_structure|evidence_state' then raise syntax 40.900 array('invalid temporal header')
 features=0
 do while lines(temporalFile)>0
  row=linein(temporalFile)
  parse var row id '|' frame '|' pts '|' water '|' components '|' isolated '|' largest '|' neighbours '|' ratio '|' motion '|' state
  if state\=='OBSERVED_UNTESTED' | frame<>features then raise syntax 40.900 array('temporal sequence invalid')
  store~q('INSERT INTO vision_motion_structure VALUES (?,?,?,?,?,?,?,?,?,?)',store~binds(source,frame,water,components,isolated,largest,neighbours,ratio,motion,state))
  features=features+1
 end
 call stream temporalFile,'c','close'
 if features<>nodes then raise syntax 40.900 array('missing temporal observations')
 store~commit
 signal off syntax
 return nodes
rollbackAdmission:
 store~rollback
 raise syntax 40.900 array('vision evidence ingestion rolled back; source not admitted')
::requires 'SlamStore.cls'
