parse arg line
repo=""; home=value("HOME",,"ENVIRONMENT"); poll=5; enableNow=.false; reload=.true; launcher=""
do i=1 to words(line)
  token=word(line,i)
  select
    when token~left(7)="--repo=" then repo=token~substr(8)
    when token~left(7)="--home=" then home=token~substr(8)
    when token~left(7)="--poll=" then poll=token~substr(8)+0
    when token~left(11)="--launcher=" then launcher=token~substr(12)
    when token="--enable-now" then enableNow=.true
    when token="--no-reload" then reload=.false
    otherwise do; say "ERROR unknown argument:" token; exit 2; end
  end
end
if repo="" then repo=home || "/alchemy-autobuild/repo"
unit=.AlchemyAutobuildServiceUnit~new~install(home,repo,poll,enableNow,reload,launcher)
say "UNIT=" || unit
if enableNow then say "PASS ALCHEMY_AUTOBUILD_SERVICE_ENABLED"
else say "PASS ALCHEMY_AUTOBUILD_SERVICE_UNIT_INSTALLED"
exit 0
::requires "AlchemyAutobuildServiceUnit.cls"
