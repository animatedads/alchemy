/* Stand-in for the estate MU audit (tests only): two process findings, one the
   audit's own ancestor (nshinvoker: the test runs the agent through a bash
   of that name, which nothing else on any host is called), one that is
   nobody's (ghostproc).
   Architecture: Tom Dyer. Coding: Claude (Opus 5.5). */
::class MuContract public
::method init
  use strict arg path
::class MuInventory public
::method fromHost class
  return self~new
::class MuFinding public
::attribute kind get
::attribute item get
::attribute verdict get
::attribute belongs get
::method init
  expose kind item verdict belongs
  use strict arg kind, item, verdict, belongs
::class MuAudit public
::method init
  use strict arg contract
::method check
  use strict arg inventory
  return .Array~of(.MuFinding~new('process', 'nshinvoker', 'EXTRA', 'no witness in the MU contract'), -
                   .MuFinding~new('process', 'ghostproc', 'EXTRA', 'no witness in the MU contract'))
