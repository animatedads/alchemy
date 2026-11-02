/* User-supplied video overlay clock readings, visually transcribed.
 * Distinguish embedded DISPLAY CLOCK offset from physical capture latency.
 * Not a frame sync or user-visible UTC guarantee.
 */
::class HarbourClockEvidence public
::method clockSecond
  use strict arg stamp
  if length(stamp)\==8 | substr(stamp,3,1)\==':' | substr(stamp,6,1)\==':' then raise syntax 88.900 array('clock format must be HH:MM:SS')
  h=substr(stamp,1,2);m=substr(stamp,4,2);s=substr(stamp,7,2)
  if \datatype(h,'W') | \datatype(m,'W') | \datatype(s,'W') then raise syntax 88.900 array('invalid clock digits')
  if h<0 | h>23 | m<0 | m>59 | s<0 | s>59 then raise syntax 88.900 array('clock out of range')
  return h*3600+m*60+s
::method records
  /* Time points correspond to 7.5, 22.5, 37.5, 52.5 seconds into
   * independent 60-second streams, NOT synchronized image capture.
   * Visible WEB CLOCK TEXT transcribed from user-supplied frames.
   */
  r=.array~new
  r~append(.array~of(7.5,'17:23:06','17:23:01'))
  r~append(.array~of(22.5,'17:23:21','17:23:16'))
  r~append(.array~of(37.5,'17:23:36','17:23:31'))
  r~append(.array~of(52.5,'17:23:51','17:23:46'))
  return r
::method compare
  use strict arg rows
  a=.array~new
  do row over rows
    a~append(self~clockSecond(row[2])-self~clockSecond(row[3]))
  end
  return a
::method qualify
  use strict arg rows
  if rows~items<3 then return 'INSUFFICIENT_CLOCK_READINGS'
  d=self~compare(rows)
  first=d[1]
  do i=2 to d~items
    if d[i]\==first then return 'VARIABLE_DISPLAY_CLOCK_OFFSET'
    if self~clockSecond(rows[i][2])-self~clockSecond(rows[i-1][2])\=rows[i][1]-rows[i-1][1] then return 'CLOCK_RATE_INCONSISTENT'
    if self~clockSecond(rows[i][3])-self~clockSecond(rows[i-1][3])\=rows[i][1]-rows[i-1][1] then return 'CLOCK_RATE_INCONSISTENT'
  end
  return 'STABLE_DISPLAY_CLOCK_OFFSET_NOT_FRAME_SYNC'