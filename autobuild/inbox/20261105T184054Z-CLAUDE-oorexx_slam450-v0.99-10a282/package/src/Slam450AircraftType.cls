/* SLAM450 v0.88 — aircraft TYPE as an observation (quad / fixed wing).
 * Architecture: Tom Dyer. Implementation: Claude (Opus 5.5), 2026-11-03.
 *
 * Type is inferred ONLY from the onboard indexed panorama: the shape of an
 * 'R' (competitor) or 'P' (buddy) silhouette. No referee airframe table is
 * consulted. A rotorcraft silhouette is compact (aspect ~1); a wing is wide
 * and flat (aspect >= 3 at every range the renderer can resolve).
 *
 * Per-symbol bounded vote ring: one sighting is a CANDIDATE; three agreeing
 * sightings among the last five, with no contradiction among them, is
 * CONFIRMED. Image-edge crops are not classified (shape unknown).
 *
 * Type matters for:
 *   ranging   — half-width billboard is 2.5 m (QUAD) or 5.0 m (FIXED_WING);
 *               a wing ranged with quad assumptions reads ~2x too close;
 *   sharing   — buddies relay their observed rival type (peer self-report);
 *   tactics   — a quad can stop on a target, a wing must pass through it.
 */
::requires 'Slam450Flight.cls'

::class Slam450AircraftType public
::constant QUAD_HALF_WIDTH_M 2.5
::constant WING_HALF_WIDTH_M 5.0
::method classify class
  /* -> directory TYPE (QUAD|FIXED_WING|UNKNOWN), ASPECT, REASON */
  use strict arg sight,frameWidth
  numeric digits 16
  d=.directory~new;d['TYPE']='UNKNOWN';d['ASPECT']='';d['REASON']='NOT_VISIBLE'
  if sight==.nil then return d
  w=sight['WIDTH'];h=sight['HEIGHT']
  aspect=w/max(1,h)
  d['ASPECT']=aspect
  /* A silhouette clipped by the panorama seam has no reliable shape. */
  if sight['X']-w/2<=1 | sight['X']+w/2>=frameWidth then do
    d['REASON']='EDGE_CROPPED';return d
  end
  /* Overlapping silhouettes merge into one blob of unknown shape. */
  if sight['COUNT']<w*h*0.6 then do
    d['REASON']='IRREGULAR_OR_OCCLUDED';return d
  end
  if aspect>=2.5 then do;d['TYPE']='FIXED_WING';d['REASON']='WIDE_FLAT_SILHOUETTE';end
  else if aspect<=1.5 then do;d['TYPE']='QUAD';d['REASON']='COMPACT_SILHOUETTE';end
  else d['REASON']='AMBIGUOUS_ASPECT'
  return d
::method halfWidth class
  use strict arg type
  if type=='FIXED_WING' then return self~WING_HALF_WIDTH_M
  return self~QUAD_HALF_WIDTH_M

::class Slam450AircraftTypeMemory public
::attribute log get
::method init
  expose votes log capacity peer
  use strict arg slots=8
  if slots<5 | slots>64 then raise syntax 88.900 array('type memory capacity')
  capacity=slots;votes=.directory~new;log=.array~new;peer=.directory~new
::method observe
  /* Classify R and P in one frame; returns directory symbol -> belief. */
  expose votes log capacity
  use strict arg frame,step
  vis=.Slam450Vision~new
  out=.directory~new
  do symbol over .array~of('R','P')
    /* v0.89: classify the largest separate silhouette (nearest aircraft). */
    blobs=vis~observeBlobs(frame,symbol)
    sight=.nil
    if blobs~items>0 then sight=blobs[1]
    c=.Slam450AircraftType~classify(sight,frame['WIDTH'])
    if sight\==.nil then do
      if \votes~hasIndex(symbol) then votes[symbol]=.array~new
      ring=votes[symbol]
      if ring~items>=capacity then do
        kept=.array~new;do i=2 to ring~items;kept~append(ring[i]);end
        ring=kept;votes[symbol]=ring
      end
      ring~append(c['TYPE'])
      entry=.directory~new
      entry['STEP']=step;entry['SYMBOL']=symbol;entry['TYPE']=c['TYPE']
      entry['REASON']=c['REASON'];entry['ASPECT']=c['ASPECT']
      entry['WIDTH']=sight['WIDTH'];entry['HEIGHT']=sight['HEIGHT']
      entry['BELIEF']=self~belief(symbol)['TYPE']
      entry['CONFIDENCE']=self~belief(symbol)['CONFIDENCE']
      if log~items>=256 then do
        kept=.array~new;do i=2 to log~items;kept~append(log[i]);end
        log=kept
      end
      log~append(entry)
    end
    out[symbol]=self~belief(symbol)
  end
  return out
::method belief
  /* Own evidence first; a peer report fills in only when own is silent. */
  expose votes peer
  use strict arg symbol
  d=.directory~new;d['TYPE']='UNKNOWN';d['CONFIDENCE']='NONE';d['SOURCE']='NONE'
  if votes~hasIndex(symbol) then do
    ring=votes[symbol]
    first=max(1,ring~items-4)
    q=0;w=0
    do i=first to ring~items
      if ring[i]=='QUAD' then q+=1
      if ring[i]=='FIXED_WING' then w+=1
    end
    if q>0 & w>0 then do
      d['TYPE']='UNKNOWN';d['CONFIDENCE']='CONTRADICTED';d['SOURCE']='OWN_IMAGE'
      return d
    end
    if q>0 | w>0 then do
      d['TYPE']='QUAD';n=q
      if w>0 then do;d['TYPE']='FIXED_WING';n=w;end
      d['CONFIDENCE']='CANDIDATE'
      if n>=3 then d['CONFIDENCE']='CONFIRMED'
      d['SOURCE']='OWN_IMAGE'
      return d
    end
  end
  if peer~hasIndex(symbol) then do
    d['TYPE']=peer[symbol];d['CONFIDENCE']='PEER_REPORTED';d['SOURCE']='BUDDY_SELF_REPORTED_NOT_ORACLE'
  end
  return d
::method absorbPeer
  /* A buddy's relayed observation of the shared competitor (symbol R). */
  expose peer
  use strict arg symbol,type
  if type\=='QUAD' & type\=='FIXED_WING' & type\=='UNKNOWN' then ,
    raise syntax 88.900 array('peer aircraft type must be QUAD, FIXED_WING or UNKNOWN')
  if type\=='UNKNOWN' then peer[symbol]=type
  return .true
::method save
  expose log
  use strict arg file
  call lineout file,'tick,symbol,observed_type,reason,aspect,width_px,height_px,belief,confidence'
  do e over log
    call lineout file,e['STEP']||','||e['SYMBOL']||','||e['TYPE']||','||e['REASON']||','||,
      e['ASPECT']||','||e['WIDTH']||','||e['HEIGHT']||','||e['BELIEF']||','||e['CONFIDENCE']
  end
  call stream file,'C','CLOSE'
  return log~items

::class Slam450FlightWindowHints public
/* v0.88: typical performance window per airframe TYPE — ordinary pilot
 * knowledge (a recognition-manual table), the same for every pilot.
 * Rounded typical values, NOT any aircraft's live state, pack or pose.
 *
 *   QUAD   SPEED 0 TO 7    HOVER TRUE   CLIMB 4   DESCENT 4   TURN_RADIUS 0
 *          LATERAL TRUE    STOP_ON_TARGET TRUE    CRUISE 3 TO 7
 *   FIXED  SPEED 7 TO 11   HOVER FALSE  CLIMB 2   DESCENT 3   TURN_RADIUS 11
 *          LATERAL FALSE   STOP_ON_TARGET FALSE   CRUISE 8    STALL 6.5
 *          GLIDE 10
 */
::method init
  expose table
  table=.directory~new
  q=.directory~new
  q['TYPE']='QUAD';q['SPEED_MIN']=0;q['SPEED_MAX']=7;q['CRUISE_MIN']=3;q['CRUISE_MAX']=7
  q['HOVER']=.true;q['CLIMB_MAX']=4;q['DESCENT_MAX']=4;q['TURN_RADIUS_MIN']=0
  q['LATERAL']=.true;q['STOP_ON_TARGET']=.true;q['STALL']='';q['GLIDE']=''
  table['QUAD']=q
  w=.directory~new
  w['TYPE']='FIXED_WING';w['SPEED_MIN']=7;w['SPEED_MAX']=11;w['CRUISE_MIN']=8;w['CRUISE_MAX']=8
  w['HOVER']=.false;w['CLIMB_MAX']=2;w['DESCENT_MAX']=3;w['TURN_RADIUS_MIN']=11
  w['LATERAL']=.false;w['STOP_ON_TARGET']=.false;w['STALL']=6.5;w['GLIDE']=10
  table['FIXED_WING']=w
::method window
  /* Copy, so no pilot can edit the shared manual. UNKNOWN -> .nil. */
  expose table
  use strict arg type
  if \table~hasIndex(type) then return .nil
  return table[type]~copy
::method describe
  expose table
  out=.array~new
  do type over .array~of('QUAD','FIXED_WING')
    t=table[type];label=type;if type=='FIXED_WING' then label='FIXED'
    out~append(label 'SPEED' t['SPEED_MIN'] 'TO' t['SPEED_MAX'])
    out~append(label 'HOVER' tf(t['HOVER']))
    out~append(label 'CLIMB' t['CLIMB_MAX'] 'DESCENT' t['DESCENT_MAX'])
    out~append(label 'TURN_RADIUS' t['TURN_RADIUS_MIN'] 'LATERAL' tf(t['LATERAL']))
    out~append(label 'STOP_ON_TARGET' tf(t['STOP_ON_TARGET']))
  end
  return out
::routine tf
  use strict arg b
  if b then return 'TRUE'
  return 'FALSE'
