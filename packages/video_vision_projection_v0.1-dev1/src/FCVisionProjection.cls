/* FC -> ooRexx Vision evidence projection.
 * API: video.vision.fc.projection/0.1
 *
 * This adapter is downstream of FC Vehicle Motion. It does not decode video,
 * decide camera authority, or create CAR_MOTION events. It projects already
 * admitted FC event/sample evidence into Vision TRACK-coordinate evidence.
 */

::class FCVisionTrackProjection public
::method init
  expose trackRef classification sourceFile startMs endMs confidence accumulator persistent canonicalX canonicalY
  use strict arg trackRef,classification,sourceFile,startMs,endMs,confidence,accumulator,persistent,canonicalX,canonicalY
::attribute trackRef get
::attribute classification get
::attribute sourceFile get
::attribute startMs get
::attribute endMs get
::attribute confidence get
::attribute accumulator get
::attribute persistent get
::attribute canonicalX get
::attribute canonicalY get
::method observationCount
  expose accumulator
  return accumulator~observations~items
::method evidenceSampleCount
  expose accumulator
  return accumulator~samples~items

::class FCVisionProjection public
::method fromFiles class
  use strict arg eventPath,samplePath
  events=self~readTsv(eventPath)
  samples=self~readTsv(samplePath)
  projections=.array~new
  do e over events
    if e['schema'] <> 'FC_CAR_MOTION_EVENT_V1' then iterate
    trackRef=e['event_id']
    eventStart=e['start_ms']+0; eventEnd=e['end_ms']+0
    confidence=e['confidence']+0
    matching=.array~new
    do s over samples
      if s['schema'] <> 'FC_ROAD_MOTION_SAMPLE_V1' then iterate
      /* Episode admission begins at previous_ms and ends at time_ms. */
      if (s['previous_ms']+0)>=eventStart & (s['time_ms']+0)<=eventEnd then matching~append(s)
    end
    if matching~items=0 then iterate
    canonicalX=matching[1]['centroid_x']+0
    canonicalY=matching[1]['centroid_y']+0
    lattice=.VisionSamplingLattice~new('RECT',1,0,0,1)
    acc=.VisionTrackEvidenceAccumulator~new(trackRef)
    persistent=.VisionPersistentRegion~new(trackRef)
    do s over matching
      left=s['left_cell']+0; top=s['top_cell']+0
      right=s['right_cell']+0; bottom=s['bottom_cell']+0
      region=.VisionRegion~new(left,top,right-left+1,bottom-top+1,s['previous_ms']+0,s['time_ms']+0)
      transform=.VisionTrackTransform~new(trackRef,s['centroid_x']+0,s['centroid_y']+0,canonicalX,canonicalY)
      observation=.VisionTrackObservation~new(trackRef,region,s['time_ms']+0,confidence,transform,s)
      added=acc~addObservation(observation,lattice,32,18)
      persistent~observe(observation)
    end
    projections~append(.FCVisionTrackProjection~new(trackRef,e['class'],e['source_file'],eventStart,eventEnd,confidence,acc,persistent,canonicalX,canonicalY))
  end
  return projections

::method readTsv class private
  use strict arg path
  csv=.CSVStream~new(path,.false); csv~delimiter='09'x; csv~open('read')
  header=csv~csvLineIn
  rows=.array~new
  do while csv~chars>0
    row=csv~csvLineIn
    if row=.nil then leave
    if row~items=0 then iterate
    rec=.directory~new
    do i=1 to header~items
      rec[header[i]]=row[i]
    end
    rows~append(rec)
  end
  csv~close
  return rows

::requires 'Vision.cls'
::requires 'csvStream.cls'
