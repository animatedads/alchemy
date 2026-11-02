/* Native ooRexx temporal landmark measurements. ffmpeg is decoder only. */
numeric digits 16
parse arg basePath
if basePath=='' then basePath='frames'
f=.HarbourStreamStability~new
say 'feed|landmark|sample_frame|dx_320|dy_180|mean_abs_luma_error|status'
do feed=1 to 3
  name=basePath||'/stream'||feed||'_320x180_gray.raw'
  rows=f~measure(name,feed)
  do row over rows
    say row[1]'|'row[2]'|'row[3]'|'row[4]'|'row[5]'|'format(row[6],5,2)'|'row[7]
  end
  say 'CAMERA_STATUS|'feed'|'f~admission(rows)
end
::requires 'SlamHarbourStreamStability.cls'