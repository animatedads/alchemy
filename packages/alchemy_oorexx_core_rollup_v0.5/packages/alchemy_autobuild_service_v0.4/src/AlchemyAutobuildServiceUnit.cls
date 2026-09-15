/* User-systemd installation model for AlchemyAutobuildService. */

::class AlchemyAutobuildServiceUnit subclass AlchemyCoreComponent public
::constant UNIT_NAME "alchemy-autobuild.service"

::method init
  expose runner
  use strict arg runner=.nil
  self~initCoreComponent("AlchemyAutobuildServiceUnit", "0.3", "User systemd unit installer for ooRexx autobuild")
  if runner==.nil then runner=.AlchemyCommandRunner~new

::method render
  use strict arg repoRoot, pollSeconds=5, launcherPath=""
  repoRoot=repoRoot~string
  pollSeconds=pollSeconds+0
  if repoRoot="" then raise syntax 88.900 array("service unit repo root required")
  if launcherPath="" then launcherPath=repoRoot || "/tools/alchemy-autobuild"
  launcherPath=launcherPath~string
  if repoRoot~pos("0a"x)>0 | repoRoot~pos("0d"x)>0 then raise syntax 88.900 array("service unit repo root contains newline")
  if launcherPath~pos("0a"x)>0 | launcherPath~pos("0d"x)>0 then raise syntax 88.900 array("service unit launcher contains newline")
  if pollSeconds<1 then raise syntax 88.900 array("service unit poll seconds must be >= 1")
  q='"'
  text="[Unit]" || "0a"x
  text||="Description=Alchemy ooRexx Autobuild Service" || "0a"x
  text||="After=network-online.target" || "0a"x || "0a"x
  text||="[Service]" || "0a"x
  text||="Type=simple" || "0a"x
  text||="WorkingDirectory=" || q || repoRoot || q || "0a"x
  text||="Environment=PATH=/usr/local/bin:/usr/bin:/bin" || "0a"x
  text||="ExecStart=" || q || launcherPath || q || " --repo=" || q || repoRoot || q || " --poll=" || pollSeconds || "0a"x
  text||="Restart=on-failure" || "0a"x
  text||="RestartSec=3" || "0a"x || "0a"x
  text||="[Install]" || "0a"x
  text||="WantedBy=default.target" || "0a"x
  return text

::method install
  expose runner
  use strict arg home, repoRoot, pollSeconds=5, enableNow=.false, reload=.true, launcherPath=""
  home=home~string
  if home="" then raise syntax 88.900 array("service unit home required")
  unitDir=home || "/.config/systemd/user"
  runner~require(.array~of("mkdir","-p",unitDir),"","systemd user directory")
  unitPath=unitDir || "/" || self~UNIT_NAME
  s=.stream~new(unitPath); s~open("write replace"); s~charout(self~render(repoRoot,pollSeconds,launcherPath)); s~close
  if reload then runner~require(.array~of("systemctl","--user","daemon-reload"),"","systemd daemon reload")
  if enableNow then do
    runner~run(.array~of("systemctl","--user","stop",self~UNIT_NAME),"")
    runner~require(.array~of("systemctl","--user","enable","--now",self~UNIT_NAME),"","systemd enable autobuild")
  end
  return unitPath

::requires "AlchemyAutobuildService.cls"
