::class EvidenceTestSupport public
::method tempDir class
  use strict arg prefix="alchemy-evidence"
  p=SysTempFileName("/tmp/" || prefix || "-??????")
  if p="" | SysMkDir(p)<>0 then raise syntax 88.900 array("temp dir failed")
  return p

::method write class
  use strict arg path,data
  s=.stream~new(path); s~open("write replace"); s~charout(data); s~close

::method sh class
  use strict arg cmd
  address system cmd
  if rc<>0 then raise syntax 88.900 array("command failed rc=" || rc || ": " || cmd)

::method initRepo class
  use strict arg root
  remote=root || "/remote.git"; clone=root || "/repo"
  self~sh("git init --bare -q " || .AlchemyShell~quote(remote))
  self~sh("git clone -q " || .AlchemyShell~quote(remote) || " " || .AlchemyShell~quote(clone))
  self~sh("git -C " || .AlchemyShell~quote(clone) || " config user.email test@example.invalid")
  self~sh("git -C " || .AlchemyShell~quote(clone) || " config user.name EvidenceTest")
  self~write(clone || "/README.md","seed" || "0a"x)
  self~sh("git -C " || .AlchemyShell~quote(clone) || " add README.md")
  self~sh("git -C " || .AlchemyShell~quote(clone) || " commit -q -m seed")
  self~sh("git -C " || .AlchemyShell~quote(clone) || " branch -M main")
  self~sh("git -C " || .AlchemyShell~quote(clone) || " push -q -u origin main")
  self~sh("git -C " || .AlchemyShell~quote(remote) || " symbolic-ref HEAD refs/heads/main")
  return clone

::method assertTrue class
  use strict arg condition,label
  if \condition then raise syntax 88.900 array("FAIL " || label)

::method assertEq class
  use strict arg expected,actual,label
  if expected \== actual then raise syntax 88.900 array("FAIL " || label || " expected=" || expected || " actual=" || actual)

::method readJsonFromMain class
  use strict arg repo,rel
  r=.AlchemyCommandRunner~new~require(.array~of("git","show","refs/remotes/origin/main:" || rel),repo,"read main JSON")
  return .JSON~fromJSON(r~stdout)

::requires "AlchemyTransport.cls"
::requires "json.cls"
