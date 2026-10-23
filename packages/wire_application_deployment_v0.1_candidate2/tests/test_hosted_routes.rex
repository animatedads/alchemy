call test .HttpsHostedRoutes~new
say 'PASS hosted routes CAS and isolation'
exit 0
test: procedure
  use strict arg r
  a=.RouteTarget~new('A')
  b=.RouteTarget~new('B')
  if \r~publish('GET','/apps/one','one','g1',a,'answer') then signal failed
  if r~publish('GET','/apps/one','two','g2',b,'answer','g1') then signal failed
  if r~publish('GET','/apps/one','one','g2',b,'answer','wrong') then signal failed
  if r~publish('GET','/apps/one','one','g1',a,'answer','g1') then signal failed
  if \r~publish('GET','/apps/two','two','g1',b,'answer') then signal failed
  if r~lookup('GET','/apps/one')[3]~answer('')<>'A' then signal failed
  if \r~publish('GET','/apps/one','one','g2',b,'answer','g1') then signal failed
  if r~lookup('GET','/apps/one')[3]~answer('')<>'B' then signal failed
  if r~retire('GET','/apps/one','one','g1') then signal failed
  if \r~retire('GET','/apps/one','one','g2') then signal failed
  if r~generation('GET','/apps/one')<>'' then signal failed
  if r~generation('GET','/apps/two')<>'g1' then signal failed
  return
failed:
  say 'FAIL hosted routes CAS and isolation'
  exit 1
::class RouteTarget
::method init
  expose value
  use strict arg value
::method answer
  expose value
  return value
::requires 'HttpsHostedRoutes.cls'
