/* Select bounded raw visual motion strata; NEVER align to audio implicitly. */
::class SpashRawVisualStrata public
::method select
  use strict arg sourcePath,targetWidth=1000,maxSelected=20
  if \datatype(targetWidth,'W') | \datatype(maxSelected,'W') then raise syntax 88.900 array('integer window and limit required')
  if targetWidth<250 | maxSelected<1 | maxSelected>1000 then raise syntax 88.900 array('selection bounds exceeded')
  s=.stream~new(sourcePath)
  if s~open('READ')<0 then raise syntax 88.900 array('view missing',sourcePath)
  header=s~linein
  if pos('valid_geometry_ms',header)=0 | pos('audio_clock_authority',header)=0 then raise syntax 88.900 array('not a raw-PTS view')
  ranked=.array~new
  do while s~lines>0
    line=s~linein
    if line=='' then iterate
    f=line~makeArray('09'x)
    if f~items<21 then raise syntax 88.900 array('malformed PTS window')
    if f[1]\=='spash.visual.raw-window/0.2' | f[20]\=='NOT_ALIGNED' then raise syntax 88.900 array('visual source or clock contract violated')
    if f[3]<>targetWidth then iterate
    if f[21]\=='VALID_RAW_PTS_WINDOW' | f[10]\=='STABLE' then iterate
    if \datatype(f[7],'N') | \datatype(f[8],'N') | \datatype(f[11],'N') | \datatype(f[12],'N') | \datatype(f[18],'N') then raise syntax 88.900 array('malformed numeric motion')
    if abs(f[7]-targetWidth)>.01 | abs(f[8]-targetWidth)>.01 then iterate
    /* Door-specific residuals are measured after global subtraction;
     * selected intervals remain visual-only candidate strata. */
    score=f[12]/(1+f[11])
    if score<=0 then iterate
    record=.directory~new
    record['SOURCE_FILE']=f[2];record['WIDTH_MS']=targetWidth
    record['START_MS']=f[4];record['END_MS']=f[5]
    record['EPOCH_ID']=f[9];record['DOOR_RESIDUAL_TRAVEL_PX_PER_SEC']=f[12]
    record['GLOBAL_TRAVEL_PX_PER_SEC']=f[11]
    record['SCORE']=score;record['AUTHORITY']='RAW_VIDEO_PTS_STRATUM_NOT_AUDIO_PROOF'
    record['AUDIO_CLOCK']='NOT_ALIGNED'
    position=ranked~items+1
    do j=1 to ranked~items
      if score>ranked[j]['SCORE'] then do;position=j;leave;end
      if score=ranked[j]['SCORE'] & f[4]<ranked[j]['START_MS'] then do;position=j;leave;end
    end
    ranked~append(record)
    do k=ranked~items to position+1 by -1
      ranked[k]=ranked[k-1]
    end
    ranked[position]=record
    if ranked~items>maxSelected then ranked~remove(ranked~items)
  end
  s~close
  return ranked