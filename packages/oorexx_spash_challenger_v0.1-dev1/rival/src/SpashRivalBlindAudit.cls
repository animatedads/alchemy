/* SPASH Rival blind-review audit v0.1. Metadata only; no audio processing.
 * Tom's blinded labels first, private matched-key second. No early unblinding.
 */
::class SpashRivalBlindAudit public
::method score
  use strict arg reviewRows,hiddenKeyRows
  if \reviewRows~isA(.array) | \hiddenKeyRows~isA(.array) then raise syntax 88.900 array('blinded reviews and key must be arrays')
  reviews=.directory~new
  do review over reviewRows
    if \review~isA(.directory) then raise syntax 88.900 array('invalid review record')
    id=review~at('BLIND_ID');label=review~at('LABEL')
    if id==.nil | label==.nil then raise syntax 88.900 array('blind id and Tom label required')
    if reviews~at(id)\==.nil then raise syntax 88.900 array('duplicate blind review',id)
    if review~at('FEED')\==.nil | review~at('FILE')\==.nil | review~at('WALL_TIME')\==.nil | review~at('STRATEGY_ID')\==.nil then raise syntax 88.900 array('review leaks withheld key')
    if label\=='CALL' & label\=='SPEECH' & label\=='NOT_SPEECH' & label\=='UNSURE' & label\=='NOT_ASSESSABLE' then raise syntax 88.900 array('unsupported Tom label',label)
    reviews[id]=label
  end
  keyIds=.directory~new;groupPairs=.directory~new
  do key over hiddenKeyRows
    if \key~isA(.directory) then raise syntax 88.900 array('bad hidden key')
    id=key~at('BLIND_ID');pairId=key~at('PAIR_ID');role=key~at('ROLE')
    feed=key~at('FEED');file=key~at('FILE');block=key~at('TIME_BLOCK');strategy=key~at('STRATEGY_ID')
    if id==.nil | pairId==.nil | role==.nil | feed==.nil | file==.nil | block==.nil | strategy==.nil then raise syntax 88.900 array('incomplete private matched key')
    if reviews~at(id)==.nil then raise syntax 88.900 array('no blinded label for a hidden-key entry',id)
    if keyIds~at(id)\==.nil then raise syntax 88.900 array('duplicate private key id',id)
    keyIds[id]='SEEN'
    if role\=='CANDIDATE' & role\=='CONTROL' then raise syntax 88.900 array('invalid pair role')
    if key~at('CONTROL_SAMPLING')\=='RANDOM_SAME_FILE_TIME_BLOCK' then raise syntax 88.900 array('random matched control provenance absent')
    scope=feed||'/'||file||'/'||block||'/'||strategy
    pairKey=scope||'/'||pairId
    pair=groupPairs~at(pairKey)
    if pair==.nil then do
      pair=.directory~new
      pair['SCOPE']=scope
      pair['CANDIDATE']=.nil;pair['CONTROL']=.nil
      groupPairs[pairKey]=pair
    end
    if pair~at(role)\==.nil then raise syntax 88.900 array('duplicate role for matched pair',pairKey)
    pair[role]=reviews[id]
  end
  if hiddenKeyRows~items<>reviews~items then raise syntax 88.900 array('review/key sizes disagree')
  groups=.directory~new
  do pairKey over groupPairs
    pair=groupPairs[pairKey]
    if pair~at('CANDIDATE')==.nil | pair~at('CONTROL')==.nil then raise syntax 88.900 array('incomplete matched pair',pairKey)
    scope=pair['SCOPE']
    summary=groups~at(scope)
    if summary==.nil then do
      summary=.directory~new
      summary['SCOPE']=scope;summary['PAIRS_TOTAL']=0;summary['PAIRS_ASSESSABLE']=0
      summary['PAIRS_UNASSESSABLE']=0;summary['CANDIDATE_CONFIRMED']=0;summary['CONTROL_CONFIRMED']=0
      summary['CANDIDATE_ONLY_WINS']=0;summary['CONTROL_ONLY_WINS']=0
      groups[scope]=summary
    end
    summary['PAIRS_TOTAL']=summary['PAIRS_TOTAL']+1
    c=pair['CANDIDATE'];k=pair['CONTROL']
    if c=='UNSURE' | c=='NOT_ASSESSABLE' | k=='UNSURE' | k=='NOT_ASSESSABLE' then do
      summary['PAIRS_UNASSESSABLE']=summary['PAIRS_UNASSESSABLE']+1
      iterate
    end
    summary['PAIRS_ASSESSABLE']=summary['PAIRS_ASSESSABLE']+1
    ch=(c=='CALL' | c=='SPEECH');kh=(k=='CALL' | k=='SPEECH')
    if ch then summary['CANDIDATE_CONFIRMED']=summary['CANDIDATE_CONFIRMED']+1
    if kh then summary['CONTROL_CONFIRMED']=summary['CONTROL_CONFIRMED']+1
    if ch & \kh then summary['CANDIDATE_ONLY_WINS']=summary['CANDIDATE_ONLY_WINS']+1
    if kh & \ch then summary['CONTROL_ONLY_WINS']=summary['CONTROL_ONLY_WINS']+1
  end
  outputs=.array~new
  do scope over groups
    summary=groups[scope]
    n=summary['PAIRS_ASSESSABLE']
    summary['STATUS']='NO_ASSESSABLE_BLIND_PAIRS'
    if n>0 then do
      summary['STATUS']='ASSESSED_PAIRED_HUMAN_CONFIRMATION'
      summary['CANDIDATE_HIT_FRACTION']=summary['CANDIDATE_CONFIRMED']/n
      summary['CONTROL_HIT_FRACTION']=summary['CONTROL_CONFIRMED']/n
      summary['PAIRED_LIFT']=summary['CANDIDATE_HIT_FRACTION']-summary['CONTROL_HIT_FRACTION']
    end
    summary['AUTHORITY']='BLIND_TOM_LABELS_PLUS_MATCHED_RANDOM_CONTROLS_NOT_SOURCE_LOCALISATION'
    outputs~append(summary)
  end
  return outputs