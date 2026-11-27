/* Each instance is created with an authenticated principal by the host,
   not by a browser action. A session cannot be switched to another identity.
   PUBLIC actions cannot install a profile, provision a credential, bind a
   worker, record a journal event, or read a vault reference. */
::requires 'DiplomacyWeb.cls'
::class DiplomacySession public
::method init
  expose domain principal selected
  use strict arg domain,principal,selected=''
::method project
  expose domain principal selected
  return domain~project(principal,selected)
::method dispatch
  expose domain principal selected
  use strict arg action,x
  if \x~isA(.directory) & \x~isA(.table) then return 'BAD_DETAIL'
  if self~project['account']=='' then return 'AUTH_REQUIRED'
  r='DENIED'
  select
    when action=='DIP.REFRESH' then r='REFRESHED'
    when action=='DIP.SELECT' then do
      gid=dipField(x,'game')
      if domain~game(gid)\==.nil then do
        selected=gid; r='GAME_SELECTED'
      end
      else r='NO_GAME'
    end
    when action=='DIP.CREATE' then do
      r=domain~createGame(principal,dipField(x,'title'),dipField(x,'mode'))
      if domain~game(r)\==.nil then selected=r
    end
    when action=='DIP.SEAT' then r=domain~seat(principal,selected,dipField(x,'power'),dipField(x,'kind'),dipField(x,'credential'),dipField(x,'prompt'),dipField(x,'profile'))
    when action=='DIP.PROMPT' then r=domain~prompt(principal,selected,dipField(x,'power'),dipField(x,'prompt'))
    when action=='DIP.DESIGN' then r=domain~design(principal,selected,dipField(x,'power'),dipField(x,'credential'))
    when action=='DIP.SUBMIT' then if domain~game(selected)\==.nil then r=domain~game(selected)~submitTask(principal,dipField(x,'task'),dipField(x,'raw'))
    when action=='DIP.START' then if domain~game(selected)\==.nil then r=domain~game(selected)~start(principal)
    otherwise nop
  end
  return r
::routine dipField
  use strict arg x,key
  if x~hasIndex(key) then if x[key]~isA(.string) then return x[key]
  return ''
