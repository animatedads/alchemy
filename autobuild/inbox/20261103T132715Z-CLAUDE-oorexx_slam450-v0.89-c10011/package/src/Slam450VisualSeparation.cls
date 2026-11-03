/* Flight-image-only separation steering: no true XYZ or referee access. */
::requires 'Slam450Flight.cls'
::class Slam450VisualSeparation public
::method adjust
  use strict arg aircraft,frame,command
  reader=.Slam450Vision~new
  closest=.nil
  do symbol over .array~of('R','P')
    /* v0.89: each separately drawn aircraft is its own blob. */
    do sight over reader~observeBlobs(frame,symbol)
      /* Visual apparent width: conservative relative-size cue. */
      if sight['WIDTH']<16 | abs(sight['AZ'])>100 then iterate
      if closest==.nil then closest=sight
      else if sight['WIDTH']>closest['WIDTH'] then closest=sight
    end
  end
  outCmd=.array~new
  do i=1 to command~items;outCmd~append(command[i]);end
  if closest==.nil then return outCmd
  if outCmd~items<4 then outCmd~append(0)
  /* Steer laterally away from the apparent bearing; no world position. */
  if closest['AZ']>=0 then outCmd[4]=-3
  else outCmd[4]=3
  if closest['WIDTH']>=35 then outCmd[2]=min(outCmd[2],0)
  else outCmd[2]=min(outCmd[2],2)
  return outCmd
