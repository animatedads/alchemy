/* Optional matplotlib renderer through ooRexx Foreign Runtime. */
ignored=.MLGraphRenderers~register(.MLGraphMatplotlibRenderer~new)

::class MLGraphMatplotlibRenderer subclass MLGraphRenderer public
::method init
  expose _mpl _plt _version
  if \.ForeignPython~canImport('matplotlib') then raise syntax 88.900 array('importable matplotlib','not available')
  _mpl=.ForeignPython~import('matplotlib')
  _version=_mpl~get('__version__')
  /* Headless and deterministic enough for qualification hosts. */
  _mpl~use('Agg')
  _plt=.ForeignPython~import('matplotlib.pyplot')
::method name; return 'MATPLOTLIB'
::method version; expose _version; return _version
::method supports
  use strict arg graph,view=.nil
  v=self~resolveView(graph,view)
  if graph~coordinateSystem='POLAR' then return graph~dimensionCount=2 & v~nativeView
  if graph~coordinateSystem='CARTESIAN' then do
    if v~kind='AXIS_PAIR' then return .true
    return graph~dimensionCount=2 | graph~dimensionCount=3
  end
  return .false
::method render
  expose _plt
  use strict arg graph,path,view=.nil
  v=self~resolveView(graph,view)
  if \self~supports(graph,v) then raise syntax 88.900 array('matplotlib renderer does not support graph/view combination')
  fig=_plt~figure()
  if graph~coordinateSystem='POLAR' then self~renderPolar(fig,graph)
  else if v~kind='AXIS_PAIR' then self~render2d(fig,graph,v)
  else if graph~dimensionCount=3 then self~render3d(fig,graph)
  else self~render2d(fig,graph,.MLGraphView~axisPair('XY',1,2))
  if v~nativeView then fig~suptitle(graph~title)
  else fig~suptitle(graph~title||' - view '||v~name)
  self~renderAnnotations(fig,graph)
  kw=.ForeignPython~keywords; kw~put('bbox_inches','tight')
  fig~savefig(path,kw)
  _plt~invoke('close',fig)
  fig~close
  return path
::method resolveView private
  use strict arg graph,view=.nil
  if view==.nil then return .MLGraphView~native
  if \view~isA(.MLGraphView) then raise syntax 88.900 array('matplotlib renderer view must be MLGraphView')
  return view~validateFor(graph)
::method renderPolar private
  use strict arg fig,graph
  kw=.ForeignPython~keywords; kw~put('projection','polar')
  ax=fig~add_subplot(111,kw)
  colorMap=.directory~new; nextColor=1
  do series over graph~series
    key=series~semanticKey; if \colorMap~hasIndex(key) then do; colorMap[key]=nextColor; nextColor=nextColor+1; end
    angles=.array~new; radii=.array~new
    do p over series~points
      angles~append((p~value('angle')+0)*3.14159265358979323846/180)
      radii~append(p~value('radius')+0)
    end
    style=self~styleKeywords(series~role,series~label,colorMap[key],series~connection)
    ax~plot(angles,radii,style)
  end
  ax~set_ylim(0,1)
  ax~grid(1)
  if graph~seriesCount>0 then ax~legend()
  ax~close
::method render2d private
  use strict arg fig,graph,view
  ax=fig~add_subplot(111); a1=graph~axis(view~axis1); a2=graph~axis(view~axis2)
  colorMap=.directory~new; nextColor=1
  do series over graph~series
    key=series~semanticKey; if \colorMap~hasIndex(key) then do; colorMap[key]=nextColor; nextColor=nextColor+1; end
    xs=.array~new; ys=.array~new
    do p over series~points; xs~append(p~value(a1~name)); ys~append(p~value(a2~name)); end
    ax~plot(xs,ys,self~styleKeywords(series~role,series~label,colorMap[key],series~connection))
  end
  ax~set_xlabel(self~axisLabel(a1)); ax~set_ylabel(self~axisLabel(a2)); ax~grid(1)
  if view~aspect='EQUAL' then ax~set_aspect('equal')
  if graph~seriesCount>0 then ax~legend()
  ax~close
::method render3d private
  use strict arg fig,graph
  /* Import registers the projection on older matplotlib versions as well. */
  m3=.ForeignPython~import('mpl_toolkits.mplot3d')
  kw=.ForeignPython~keywords; kw~put('projection','3d')
  ax=fig~add_subplot(111,kw); a1=graph~axis(1); a2=graph~axis(2); a3=graph~axis(3)
  colorMap=.directory~new; nextColor=1
  do series over graph~series
    key=series~semanticKey; if \colorMap~hasIndex(key) then do; colorMap[key]=nextColor; nextColor=nextColor+1; end
    xs=.array~new; ys=.array~new; zs=.array~new
    do p over series~points
      xs~append(p~value(a1~name)); ys~append(p~value(a2~name)); zs~append(p~value(a3~name))
    end
    ax~plot(xs,ys,zs,self~styleKeywords(series~role,series~label,colorMap[key],series~connection))
  end
  ax~set_xlabel(self~axisLabel(a1)); ax~set_ylabel(self~axisLabel(a2)); ax~set_zlabel(self~axisLabel(a3))
  if graph~seriesCount>0 then ax~legend()
  ax~close; m3~close
::method renderAnnotations private
  use strict arg fig,graph
  if graph~annotationCount=0 then return
  lines=.array~new
  do a over graph~annotations
    if a~kind='SUMMARY' then lines~append(a~text)
  end
  if lines~items=0 then return
  text=''; do i=1 to lines~items; if i>1 then text=text||'0a'x; text=text||lines[i]; end
  kw=.ForeignPython~keywords; kw~put('fontsize',8); kw~put('va','bottom'); kw~put('ha','left')
  fig~text(0.01,0.01,text,kw)
  return
::method styleKeywords private
  use strict arg role,label,colorIndex=0,connection='PATH'
  kw=.ForeignPython~keywords; kw~put('label',label)
  if colorIndex>0 then kw~put('color',self~colorFor(colorIndex))
  r=role~string~upper
  if connection~string~upper='POINTS' then do; kw~put('linestyle','None'); kw~put('linewidth',0); end
  else if r='EQUIVALENT' then do; kw~put('linestyle',':'); kw~put('linewidth',4); end
  else if r='NEAR' then do; kw~put('linestyle','--'); kw~put('linewidth',2); end
  else if r='CONTRAST' | r='DIFFERENCE' then do; kw~put('linestyle','-.'); kw~put('linewidth',1.5); end
  else if r='REFERENCE' | r='SECONDARY' | r='BASELINE_FIT' then do; kw~put('linestyle','--'); kw~put('linewidth',1.5); end
  else if r='RESTORED_FIT' then do; kw~put('linestyle','-'); kw~put('linewidth',2.5); end
  else do; kw~put('linestyle','-'); kw~put('linewidth',2.5); end
  if r='RESTORING_SET' then do; kw~put('marker','X'); kw~put('markersize',8); end
  else if r='PARTICIPATION' then do; kw~put('marker','D'); kw~put('markersize',6); end
  else if r='OBSERVED' then do; kw~put('marker','o'); kw~put('markersize',5); end
  else do; kw~put('marker','o'); kw~put('markersize',3); end
  return kw
::method colorFor private
  use strict arg index
  palette=.array~of('#111111','#2c5f9e','#327a4b','#a35d1d','#7a4a8f','#177f86','#9a3c3c','#4e6d2d')
  return palette[1+((index-1)//palette~items)]
::method axisLabel private
  use strict arg axis
  label=axis~label
  if axis~unit<>'' then label=label||' ['||axis~unit||']'
  if axis~role='TIME' then label=label||' (time)'
  return label
::method uninit
  expose _plt _mpl
  if symbol('_plt')='VAR' then if _plt \== .nil then _plt~close
  if symbol('_mpl')='VAR' then if _mpl \== .nil then _mpl~close

::requires 'MLGraph.cls'
::requires 'python_foreign.cls'
