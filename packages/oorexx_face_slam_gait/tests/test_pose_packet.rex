/* Tests the plain-string provider-return contract through a fake provider.
 * It does not claim real Python bridge execution or MediaPipe inference. */
numeric digits 30
.envIRONMENT['PACKET_CHECKS']=0
packet=makePacket('MEDIAPIPE33',33)
frame=.FaceSlamPosePacket~decode(packet)
call check frame~sourceId='fixture-raw-video','original source retained'
call check frame~cameraId='cam-4','camera retained'
call check frame~trackId='anonymous-7','external Motion Control track preserved'
call check frame~timeUs='1700000001234567','microsecond source time exact'
call check frame~modelDigest='modelsha256','model digest retained'
call check frame~sourceDigest='videosha256','source digest retained'
call check frame~joint('LEFT_KNEE')\==.nil,'MediaPipe knee mapped'
call check frame~joint('RIGHT_HEEL')\==.nil,'MediaPipe heel mapped'
call check frame~joint('LEFT_HEEL')~visibility='.9','quality forwarded'
fake=.FakePoseBridge~new(packet)
provider=.FaceSlamProjectedPoseProvider~new(fake)
call check provider~observe('pinned-window-1')~timeUs='1700000001234567','provider invocation contract'
call check fake~requests=1,'one invocation, not process-per-frame'
coco=.FaceSlamPosePacket~decode(makePacket('COCO17',17))
call check coco~joint('LEFT_KNEE')\==.nil,'COCO knee mapped'
call check coco~joint('LEFT_HEEL')==.nil,'no invented COCO heel'
call check failsPacket(packet||'0a'x||'33|.5|.5|1'),'extra landmark fails closed'
call check failsPacket(packet~changestr('0|.5|.5|.9','0|2|.5|.9')),'out of frame landmark blocked'
call check failsPacket(packet~changestr('0|.5|.5|.9','1|.5|.5|.9')),'duplicate index blocked'
call check failsPacket(packet~changestr('MEDIAPIPE33','ALTERNATIVE33')),'unknown topology blocked'
call check failsPacket(packet~changestr('NORMALIZED_IMAGE','UNREGISTERED_3D')),'unqualified 3D blocked'
call check .environment['PACKET_CHECKS']=18,'test count'
say 'FACE_SLAM_POSE_PACKET PASS' .environment['PACKET_CHECKS'] 'checks (mock provider, no Python bridge inference)'
exit 0
::routine makePacket
  use strict arg topo,n
  s='POSE2D/1|fixture-raw-video|cam-4|anonymous-7|1700000001234567|640|480|'||topo||'|modelsha256|videosha256|NORMALIZED_IMAGE'
  do i=0 to n-1
    s=s||'0a'x||i||'|.5|.5|.9'
  end
  return s
::routine failsPacket
  signal on syntax name rejected
  use strict arg packet
  f=.FaceSlamPosePacket~decode(packet)
  return .false
rejected: return .true
::routine check
  use strict arg ok,reason
  if \ok then raise syntax 88.900 array('FAIL: '||reason)
  .environment['PACKET_CHECKS']=.environment['PACKET_CHECKS']+1
::class FakePoseBridge public
::attribute requests get
::method init
  expose packet requests
  use strict arg packet
  requests=0
::method pose2dPacket
  expose packet requests
  use strict arg token
  if token\='pinned-window-1' then raise syntax 88.900 array('wrong source window')
  requests=requests+1
  return packet
::requires 'FaceSlamPosePacket.cls'
