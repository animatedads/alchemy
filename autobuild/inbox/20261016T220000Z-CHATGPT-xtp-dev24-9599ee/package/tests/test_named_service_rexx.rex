/* ooRexx r13196 native-library named-service smoke test.
 * Exercises actual external routine binding and XTP FIRST service admission.
 */
parse arg role peer
if role = 'listener' then do
  h = xtpNativeListenerOpenServices(peer, 5000, 'ssh.management')
  if h = 0 then do; say 'FAIL native named listener open'; exit 2; end
  say 'NATIVE_LISTENER_READY' h
  payload = xtpNativeListenerReceive(h)
  service = xtpNativeListenerLastService(h)
  call xtpNativeListenerClose h
  if service <> 'ssh.management' then do; say 'FAIL service='service; exit 3; end
  if payload <> 'native-rexx-service-smoke' then do; say 'FAIL payload='payload; exit 4; end
  say 'PASS native ooRexx named-service listener'
  exit 0
end
if role = 'sender' then do
  n = xtpNativeSendService(peer,'native-rexx-service-smoke','ssh.management')
  if n <> 25 then do; say 'FAIL send length='n; exit 5; end
  say 'PASS native ooRexx named-service sender'
  exit 0
end
say 'FAIL unknown role' role
exit 6
::routine xtpNativeListenerOpenServices external 'library oorexx_xtp_native xtpNativeListenerOpenServices'
::routine xtpNativeListenerLastService external 'library oorexx_xtp_native xtpNativeListenerLastService'
::routine xtpNativeListenerReceive external 'library oorexx_xtp_native xtpNativeListenerReceive'
::routine xtpNativeListenerClose external 'library oorexx_xtp_native xtpNativeListenerClose'
::routine xtpNativeSendService external 'library oorexx_xtp_native xtpNativeSendService'
