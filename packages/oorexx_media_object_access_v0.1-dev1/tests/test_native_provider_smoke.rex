/* ooRexx native package load smoke test, no file I/O. */
id=MOAH264Open()
if left(id,5)='ERROR' then do
 say 'FAIL' id
 exit 2
end
if MOAH264Close(id)<>'OK' then exit 3
say 'PASS ooRexx native H264 package load/open/close'
::requires 'moa_h264' LIBRARY