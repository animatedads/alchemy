::class OperationalPlanner public
::method init
  expose command
  use arg command='opctl'
::attribute command get
::method decide
  expose command
  use arg className, operatingState
  out.=''; err.=''
  address command command 'decide' className operatingState with output stem out. error stem err.
  if rc<>0 then raise syntax 93.900 array('Operational planner decision failed',err.)
  d=.directory~new
  do i=1 to out.0
    line=out.i
    do j=1 to line~words
      token=line~word(j)
      p=token~pos('=')
      if p>1 then d[token~left(p-1)]=token~substr(p+1)
    end
  end
  return d
::class OperationalClassRegistry public
::method init
  expose command
  use arg command='opctl'
::attribute command get
::method register
  expose command
  use arg name, normal='allow', degraded='allow', constrained='allow', emergency='allow', sort='', deadlineUs=''
  cmd=command 'class add' name '--normal' normal '--degraded' degraded '--constrained' constrained '--emergency' emergency
  if sort<>'' then cmd=cmd '--sort' sort
  if deadlineUs<>'' then cmd=cmd '--deadline-us' deadlineUs
  address command cmd
  if rc<>0 then raise syntax 93.900 array('Operational class registration failed',name)
  return 0
