/* ooRexx ML Graph v0.1-dev5
 * Semantic technical visualisation objects plus deterministic polar SVG renderer.
 *
 * ML algorithms own meaning and normalization.  Renderers own pixels.
 */

::class MLGraphAxis public
::method init
  expose _name _role _label _unit
  use strict arg name,role='VALUE',label='',unit=''
  if name='' then raise syntax 88.900 array('graph axis name must not be empty')
  _name=name~string; _role=role~string~upper; _label=label~string; _unit=unit~string
::method name; expose _name; return _name
::method role; expose _role; return _role
::method label
  expose _name _label
  if _label='' then return _name
  return _label
::method unit; expose _unit; return _unit
::method canonicalText
  expose _name _role _label _unit
  return 'AXIS='||_name||'|role='||_role||'|label='||_label||'|unit='||_unit

::class MLGraphPoint public
::method init
  expose _values _evidence
  use strict arg values,evidence=.nil
  if \values~isA(.Directory) then raise syntax 88.900 array('graph point values must be a Directory')
  _values=.directory~new
  do k over values; _values[k]=values[k]; end
  _evidence=evidence
::method value
  expose _values
  use strict arg name
  if \_values~hasIndex(name) then raise syntax 88.900 array('graph point has no coordinate',name)
  return _values[name]
::method has
  expose _values
  use strict arg name
  return _values~hasIndex(name)
::method values
  expose _values
  out=.directory~new; do k over _values; out[k]=_values[k]; end
  return out
::method evidence; expose _evidence; return _evidence
::method canonicalText
  expose _values
  names=.array~new; do k over _values; names~append(k); end; names~sort
  text='POINT='
  first=.true
  do k over names
    if \first then text=text||','
    text=text||k||'='||_values[k]
    first=.false
  end
  return text

::class MLGraphSeries public
::method init
  expose _label _points _role _closed _evidence _semanticKey _connection
  use strict arg label,points,role='PRIMARY',closed=.false,evidence=.nil,semanticKey='',connection='PATH'
  if \points~isA(.Array) then raise syntax 88.900 array('graph series points must be an Array')
  _label=label~string; _role=role~string~upper; _closed=closed; _evidence=evidence; _semanticKey=semanticKey~string; _connection=connection~string~upper
  if _connection<>'PATH' & _connection<>'POINTS' then raise syntax 88.900 array('graph series connection must be PATH or POINTS',_connection)
  if _connection='POINTS' & _closed then raise syntax 88.900 array('point-only graph series cannot be closed')
  _points=.array~new
  do p over points
    if \p~isA(.MLGraphPoint) then raise syntax 88.900 array('graph series requires MLGraphPoint values')
    _points~append(p)
  end
::method label; expose _label; return _label
::method role; expose _role; return _role
::method closed; expose _closed; return _closed
::method evidence; expose _evidence; return _evidence
::method connection; expose _connection; return _connection
::method semanticKey
  expose _semanticKey _label
  if _semanticKey='' then return _label
  return _semanticKey
::method points
  expose _points
  out=.array~new; do p over _points; out~append(p); end; return out
::method pointCount; expose _points; return _points~items
::method point; expose _points; use strict arg i; return _points[i]
::method canonicalText
  expose _label _points _role _closed _semanticKey _connection
  return 'SERIES='||_label||'|role='||_role||'|semanticKey='||_semanticKey||'|connection='||_connection||'|closed='||_closed||'|points='||_points~items

::class MLGraphAnnotation public
::method init
  expose _kind _text _evidence
  use strict arg kind,text,evidence=.nil
  _kind=kind~string~upper
  if _kind<>'SUMMARY' then raise syntax 88.900 array('graph annotation kind is not supported',_kind)
  _text=text~string
  if _text='' then raise syntax 88.900 array('graph annotation text must not be empty')
  _evidence=evidence
::method summary class
  use strict arg text,evidence=.nil
  return .MLGraphAnnotation~new('SUMMARY',text,evidence)
::method kind; expose _kind; return _kind
::method text; expose _text; return _text
::method evidence; expose _evidence; return _evidence
::method locatable; return .false
::method canonicalText
  expose _kind _text
  return 'ANNOTATION='||_kind||'|text='||_text

::class MLGraphGrid public
::method init
  expose _kind _majorCount _angularStep _visible
  use strict arg kind='NONE',majorCount=0,angularStep=0,visible=.true
  _kind=kind~string~upper; _majorCount=majorCount; _angularStep=angularStep; _visible=visible
::method none class; return .MLGraphGrid~new('NONE',0,0,.false)
::method polar class
  use strict arg rings=4,spokeDegrees=45
  if rings<0 then raise syntax 88.900 array('polar ring count must be non-negative')
  if spokeDegrees<=0 | spokeDegrees>360 then raise syntax 88.900 array('polar spoke step must be in (0,360]')
  return .MLGraphGrid~new('POLAR',rings,spokeDegrees,.true)
::method kind; expose _kind; return _kind
::method majorCount; expose _majorCount; return _majorCount
::method angularStep; expose _angularStep; return _angularStep
::method visible; expose _visible; return _visible
::method canonicalText
  expose _kind _majorCount _angularStep _visible
  return 'GRID='||_kind||'|major='||_majorCount||'|angularStep='||_angularStep||'|visible='||_visible

::class MLGraphView public
/* A view names a presentation projection of already-existing graph axes.
 * It never creates, normalizes or resamples semantic coordinates. */
::method init
  expose _name _kind _axis1 _axis2 _aspect
  use strict arg name,kind='NATIVE',axis1=0,axis2=0,aspect='AUTO'
  _name=name~string~upper; _kind=kind~string~upper; _axis1=axis1; _axis2=axis2; _aspect=aspect~string~upper
  if _aspect<>'AUTO' & _aspect<>'EQUAL' then raise syntax 88.900 array('graph view aspect must be AUTO or EQUAL',_aspect)
  if _name='' then raise syntax 88.900 array('graph view name must not be empty')
  if _kind<>'NATIVE' & _kind<>'AXIS_PAIR' then raise syntax 88.900 array('graph view kind must be NATIVE or AXIS_PAIR',_kind)
  if _kind='NATIVE' then do
    if _axis1<>0 | _axis2<>0 then raise syntax 88.900 array('native graph view must not name projected axes')
  end
  else do
    if _axis1<1 | _axis2<1 | _axis1=_axis2 then raise syntax 88.900 array('axis-pair graph view requires two distinct positive axis indexes')
  end
::method native class
  return .MLGraphView~new('NATIVE','NATIVE',0,0,'AUTO')
::method axisPair class
  use strict arg name,axis1,axis2,aspect='AUTO'
  return .MLGraphView~new(name,'AXIS_PAIR',axis1,axis2,aspect)
::method forGraph class
  use strict arg graph,name='NATIVE'
  if \graph~isA(.MLGraph) then raise syntax 88.900 array('graph view factory requires MLGraph')
  key=name~string~upper
  if key='NATIVE' then return self~native
  if graph~coordinateSystem<>'CARTESIAN' then raise syntax 88.900 array('axis-pair views require Cartesian graph coordinates',key)
  if key='XY' | key='AXES_1_2' then return self~axisPair('XY',1,2)
  if graph~dimensionCount=3 then do
    if key='XZ' | key='AXES_1_3' then return self~axisPair('XZ',1,3)
    if key='YZ' | key='AXES_2_3' then return self~axisPair('YZ',2,3)
    if graph~metadata('geometry','')='CYLINDER' then do
      if key='SHAPE' | key='TOP' then return self~axisPair('SHAPE',1,2,'EQUAL')
      if key='TIME_X' | key='SIDE_X' then return self~axisPair('TIME_X',1,3)
      if key='TIME_Y' | key='SIDE_Y' then return self~axisPair('TIME_Y',2,3)
    end
  end
  raise syntax 88.900 array('unknown graph view for this graph',key)
::method name; expose _name; return _name
::method kind; expose _kind; return _kind
::method axis1; expose _axis1; return _axis1
::method axis2; expose _axis2; return _axis2
::method aspect; expose _aspect; return _aspect
::method nativeView; expose _kind; return _kind='NATIVE'
::method validateFor
  expose _kind _axis1 _axis2
  use strict arg graph
  if \graph~isA(.MLGraph) then raise syntax 88.900 array('graph view validation requires MLGraph')
  if _kind='NATIVE' then return self
  if graph~coordinateSystem<>'CARTESIAN' then raise syntax 88.900 array('axis-pair view cannot project non-Cartesian graph')
  if _axis1>graph~dimensionCount | _axis2>graph~dimensionCount then raise syntax 88.900 array('graph view axis is outside graph dimensions')
  return self
::method canonicalText
  expose _name _kind _axis1 _axis2 _aspect
  return 'VIEW='||_name||'|kind='||_kind||'|axis1='||_axis1||'|axis2='||_axis2||'|aspect='||_aspect

::class MLGraph public
::method init
  expose _title _coordinateSystem _axes _series _grid _metadata _annotations
  use strict arg title,coordinateSystem,axes,grid=.nil
  if \axes~isA(.Array) | axes~items<2 | axes~items>3 then raise syntax 88.900 array('graph requires two or three axes')
  _title=title~string; _coordinateSystem=coordinateSystem~string~upper
  if _coordinateSystem<>'POLAR' & _coordinateSystem<>'CARTESIAN' then raise syntax 88.900 array('graph coordinate system must be POLAR or CARTESIAN')
  _axes=.array~new
  seen=.directory~new
  do a over axes
    if \a~isA(.MLGraphAxis) then raise syntax 88.900 array('graph axes must be MLGraphAxis values')
    if seen~hasIndex(a~name) then raise syntax 88.900 array('graph axis names must be unique',a~name)
    seen[a~name]=1; _axes~append(a)
  end
  if _coordinateSystem='POLAR' then do
    if _axes~items<>2 then raise syntax 88.900 array('polar graph requires exactly two axes')
    if _axes[1]~role<>'ANGLE' | _axes[2]~role<>'RADIUS' then raise syntax 88.900 array('polar graph axes must have ANGLE then RADIUS roles')
  end
  if grid==.nil then do
    if _coordinateSystem='POLAR' then grid=.MLGraphGrid~polar; else grid=.MLGraphGrid~none
  end
  if \grid~isA(.MLGraphGrid) then raise syntax 88.900 array('graph grid must be MLGraphGrid')
  _grid=grid; _series=.array~new; _metadata=.directory~new; _annotations=.array~new
::method polar class
  use strict arg title='Polar graph'
  axes=.array~of(.MLGraphAxis~new('angle','ANGLE','angle','degrees'),.MLGraphAxis~new('radius','RADIUS','radius','normalized'))
  return .MLGraph~new(title,'POLAR',axes,.MLGraphGrid~polar)
::method cartesian2 class
  use strict arg title='Cartesian graph',xName='x',yName='y',xRole='VALUE',yRole='VALUE'
  axes=.array~of(.MLGraphAxis~new(xName,xRole),.MLGraphAxis~new(yName,yRole))
  return .MLGraph~new(title,'CARTESIAN',axes,.MLGraphGrid~none)
::method cartesian3 class
  use strict arg title='3D graph',xName='x',yName='y',zName='z',xRole='VALUE',yRole='VALUE',zRole='VALUE'
  axes=.array~of(.MLGraphAxis~new(xName,xRole),.MLGraphAxis~new(yName,yRole),.MLGraphAxis~new(zName,zRole))
  return .MLGraph~new(title,'CARTESIAN',axes,.MLGraphGrid~none)
::method spaceTime class
  use strict arg title='Space/time graph',timeName='time',firstName='value1',secondName='value2'
  return .MLGraph~cartesian3(title,timeName,firstName,secondName,'TIME','VALUE','VALUE')
::method cylindricalTime class
  use strict arg title='Cylindrical time graph',xName='x',yName='y',timeName='time'
  g=.MLGraph~cartesian3(title,xName,yName,timeName,'CYLINDER_X','CYLINDER_Y','TIME')
  g~putMetadata('geometry','CYLINDER')
  g~putMetadata('timeAxis',timeName)
  return g
::method view
  use strict arg name='NATIVE'
  return .MLGraphView~forGraph(self,name)
::method title; expose _title; return _title
::method coordinateSystem; expose _coordinateSystem; return _coordinateSystem
::method dimensionCount; expose _axes; return _axes~items
::method axes
  expose _axes
  out=.array~new; do a over _axes; out~append(a); end; return out
::method axis; expose _axes; use strict arg i; return _axes[i]
::method grid; expose _grid; return _grid
::method "grid="
  expose _grid
  use strict arg value
  if \value~isA(.MLGraphGrid) then raise syntax 88.900 array('graph grid must be MLGraphGrid')
  _grid=value
::method addSeries
  expose _series _axes
  use strict arg series
  if \series~isA(.MLGraphSeries) then raise syntax 88.900 array('graph requires MLGraphSeries')
  do p over series~points
    do a over _axes
      if \p~has(a~name) then raise syntax 88.900 array('series point is missing graph coordinate',a~name)
    end
  end
  _series~append(series)
  return self
::method series
  expose _series
  out=.array~new; do s over _series; out~append(s); end; return out
::method seriesCount; expose _series; return _series~items
::method seriesAt; expose _series; use strict arg i; return _series[i]
::method addAnnotation
  expose _annotations
  use strict arg annotation
  if \annotation~isA(.MLGraphAnnotation) then raise syntax 88.900 array('graph requires MLGraphAnnotation')
  _annotations~append(annotation)
  return self
::method annotations
  expose _annotations
  out=.array~new; do a over _annotations; out~append(a); end; return out
::method annotationCount; expose _annotations; return _annotations~items
::method annotationAt; expose _annotations; use strict arg i; return _annotations[i]
::method putMetadata
  expose _metadata
  use strict arg name,value
  _metadata[name]=value; return self
::method metadata
  expose _metadata
  use strict arg name,default=.nil
  if _metadata~hasIndex(name) then return _metadata[name]
  return default
::method canonicalText
  expose _title _coordinateSystem _axes _series _grid _annotations
  return 'GRAPH='||_title||'|coords='||_coordinateSystem||'|dimensions='||_axes~items||'|series='||_series~items||'|annotations='||_annotations~items||'|'||_grid~canonicalText
::method render
  use strict arg renderer,path,view=.nil
  if \renderer~isA(.MLGraphRenderer) then raise syntax 88.900 array('renderer must be MLGraphRenderer')
  /* Preserve the two-argument renderer call for existing providers. */
  if view==.nil then return renderer~render(self,path)
  if \view~isA(.MLGraphView) then raise syntax 88.900 array('graph render view must be MLGraphView')
  view~validateFor(self)
  return renderer~render(self,path,view)

::class MLGraphRenderer public
::method name; return 'ABSTRACT'
::method supports; use strict arg graph,view=.nil; return .false
::method render; use strict arg graph,path,view=.nil; raise syntax 88.900 array('abstract graph renderer cannot render')

::class MLGraphRenderers public
::method _registry class private
  expose registry
  if symbol('registry')<>'VAR' then do
    registry=.directory~new
    registry['SVG']=.MLGraphSvgRenderer~new
  end
  return registry
::method register class
  use strict arg renderer
  if \renderer~isA(.MLGraphRenderer) then raise syntax 88.900 array('renderer registration requires MLGraphRenderer')
  r=self~_registry; r[renderer~name~upper]=renderer
  return renderer
::method byName class
  use strict arg name
  r=self~_registry; key=name~string~upper
  if \r~hasIndex(key) then raise syntax 88.900 array('unknown graph renderer',key)
  return r[key]
::method names class
  r=self~_registry; a=.array~new; do k over r; a~append(k); end; a~sort; return a

::class MLPatternGraphAdapter public
::method addHash class
  use strict arg graph,hash,label,role='PRIMARY'
  if \graph~isA(.MLGraph) | graph~coordinateSystem<>'POLAR' then raise syntax 88.900 array('pattern hash adapter requires a polar MLGraph')
  points=.array~new
  /* Pattern semantics already belong to MLPatternHash.  Do not renormalize here. */
  do p over hash~polarPoints
    v=.directory~new; v['angle']=p~angleDegrees; v['radius']=p~radius
    points~append(.MLGraphPoint~new(v,p))
  end
  graph~addSeries(.MLGraphSeries~new(label,points,role,.true,hash))
  return graph
::method overlay class
  use strict arg title,hashes,labels,roles=.nil
  if \hashes~isA(.Array) | \labels~isA(.Array) | hashes~items<>labels~items then raise syntax 88.900 array('pattern overlay requires equally-sized hash and label arrays')
  if roles==.nil then do; roles=.array~new; do i=1 to hashes~items; roles~append('PRIMARY'); end; end
  if \roles~isA(.Array) | roles~items<>hashes~items then raise syntax 88.900 array('pattern overlay role count mismatch')
  g=.MLGraph~polar(title)
  do i=1 to hashes~items; self~addHash(g,hashes[i],labels[i],roles[i]); end
  return g


::class MLTemporalPatternGraphAdapter public
::method addHash class
  use strict arg graph,hash,labelPrefix='',role='PRIMARY'
  if \graph~isA(.MLGraph) | graph~coordinateSystem<>'CARTESIAN' | graph~dimensionCount<>3 then raise syntax 88.900 array('temporal pattern adapter requires a three-dimensional Cartesian MLGraph')
  if graph~axis(1)~role<>'CYLINDER_X' | graph~axis(2)~role<>'CYLINDER_Y' | graph~axis(3)~role<>'TIME' then raise syntax 88.900 array('temporal pattern graph axes must be CYLINDER_X, CYLINDER_Y, TIME')
  all=hash~points
  do c=1 to hash~channelCount
    channel=hash~channelName(c); points=.array~new
    do p over all
      if p~channel\==channel then iterate
      v=.directory~new; v[graph~axis(1)~name]=p~x; v[graph~axis(2)~name]=p~y; v[graph~axis(3)~name]=p~height
      points~append(.MLGraphPoint~new(v,p))
    end
    if labelPrefix='' then label=channel; else label=labelPrefix||' / '||channel
    graph~addSeries(.MLGraphSeries~new(label,points,role,.false,hash,channel))
  end
  return graph
::method graphForHash class
  use strict arg title,hash,label='',role='PRIMARY'
  g=.MLGraph~cylindricalTime(title)
  self~addHash(g,hash,label,role)
  g~putMetadata('semanticSource','MLTemporalPatternHash')
  return g
::method overlay class
  use strict arg title,hashes,labels,roles=.nil
  if \hashes~isA(.Array) | \labels~isA(.Array) | hashes~items<>labels~items then raise syntax 88.900 array('temporal pattern overlay requires equally-sized hash and label arrays')
  if roles==.nil then do; roles=.array~new; do i=1 to hashes~items; roles~append('PRIMARY'); end; end
  if \roles~isA(.Array) | roles~items<>hashes~items then raise syntax 88.900 array('temporal pattern overlay role count mismatch')
  g=.MLGraph~cylindricalTime(title)
  do i=1 to hashes~items; self~addHash(g,hashes[i],labels[i],roles[i]); end
  g~putMetadata('semanticSource','MLTemporalPatternHash')
  return g

::class MLGraphDifferenceAdapter public
/* Difference summaries consume only evidence explicitly published by upstream ML.
 * In particular, dev10 difference objects do not publish the point/segment index
 * of the dominant delta, so Graph deliberately does not reconstruct one. */
::method addPatternSummary class
  use strict arg graph,difference,label='Pattern difference'
  text=label||': dominant='||difference~dominantDelta||', radialMax='||difference~radialMax||', slopeMax='||difference~slopeMax||', curvatureMax='||difference~curvatureMax
  graph~addAnnotation(.MLGraphAnnotation~summary(text,difference))
  graph~putMetadata('difference.location','UNPUBLISHED')
  return graph
::method addTemporalSummary class
  use strict arg graph,difference,label='Temporal pattern difference'
  text=label||': dominant='||difference~dominantDelta||' '||difference~dominantKind||'/'||difference~dominantChannel||', radiusMax='||difference~radiusMax||', timeMax='||difference~timeMax||', bearingMax='||difference~bearingMax||', elevationMax='||difference~elevationMax||', turnMax='||difference~turnMax
  graph~addAnnotation(.MLGraphAnnotation~summary(text,difference))
  graph~putMetadata('difference.location','UNPUBLISHED')
  return graph

::class MLGraphSvgRenderer subclass MLGraphRenderer public
::method init
  call RxFuncAdd 'RxCalcSin','rxmath','RxCalcSin'
  call RxFuncAdd 'RxCalcCos','rxmath','RxCalcCos'
::method name; return 'SVG'
::method supports
  use strict arg graph,view=.nil
  v=self~resolveView(graph,view)
  if graph~coordinateSystem='POLAR' & graph~dimensionCount=2 then return v~nativeView
  if graph~coordinateSystem='CARTESIAN' then do
    if v~kind='AXIS_PAIR' then return .true
    return graph~dimensionCount=2 | graph~dimensionCount=3
  end
  return .false
::method render
  use strict arg graph,path,view=.nil
  v=self~resolveView(graph,view)
  if \self~supports(graph,v) then raise syntax 88.900 array('SVG reference renderer does not support graph/view combination')
  if graph~coordinateSystem='POLAR' then return self~renderPolar(graph,path)
  if v~kind='AXIS_PAIR' then return self~renderCartesian2d(graph,path,v)
  if graph~dimensionCount=2 then return self~renderCartesian2d(graph,path,.MLGraphView~axisPair('XY',1,2))
  return self~renderCartesian3d(graph,path)
::method resolveView private
  use strict arg graph,view=.nil
  if view==.nil then return .MLGraphView~native
  if \view~isA(.MLGraphView) then raise syntax 88.900 array('SVG renderer view must be MLGraphView')
  return view~validateFor(graph)
::method renderPolar private
  use strict arg graph,path
  s=.stream~new(path); rc=s~open('write replace')
  if rc<>'READY:' then raise syntax 88.900 array('unable to open graph output',path,rc)
  w=760; h=820; cx=380; cy=395; pr=270
  s~lineout('<svg xmlns="http://www.w3.org/2000/svg" width="760" height="820" viewBox="0 0 760 820">')
  s~lineout('<rect width="760" height="820" fill="white"/>')
  s~lineout('<text x="24" y="34" font-family="sans-serif" font-size="22" font-weight="bold">'||self~escape(graph~title)||'</text>')
  s~lineout('<text x="24" y="58" font-family="sans-serif" font-size="13">angle and radius are semantic graph coordinates; renderer does not normalize source data</text>')
  grid=graph~grid
  if grid~visible & grid~kind='POLAR' then do
    rings=grid~majorCount
    if rings>0 then do ring=1 to rings
      rr=pr*ring/rings
      s~lineout('<circle cx="'||cx||'" cy="'||cy||'" r="'||format(rr,,2)||'" fill="none" stroke="#d0d0d0" stroke-width="1"/>')
    end
    step=grid~angularStep
    do angle=0 to 359 by step
      x=cx+pr*RxCalcCos(angle,12,'D'); y=cy-pr*RxCalcSin(angle,12,'D')
      lx=cx+(pr+20)*RxCalcCos(angle,12,'D'); ly=cy-(pr+20)*RxCalcSin(angle,12,'D')
      s~lineout('<line x1="'||cx||'" y1="'||cy||'" x2="'||format(x,,2)||'" y2="'||format(y,,2)||'" stroke="#dddddd" stroke-width="1"/>')
      s~lineout('<text x="'||format(lx,,2)||'" y="'||format(ly,,2)||'" font-family="sans-serif" font-size="11" text-anchor="middle">'||angle||'°</text>')
    end
  end
  s~lineout('<circle cx="'||cx||'" cy="'||cy||'" r="4" fill="#111"/>')
  legendY=700
  do i=1 to graph~seriesCount
    series=graph~seriesAt(i); style=self~style(series~role,i)
    if series~connection='PATH' then s~lineout('<path d="'||self~polarPath(series,cx,cy,pr)||'" fill="none" stroke="'||style[1]||'" stroke-width="'||style[2]||'"'||style[3]||'/>')
    do p over series~points
      angle=p~value('angle'); radius=p~value('radius'); rr=pr*radius
      x=cx+rr*RxCalcCos(angle,12,'D'); y=cy-rr*RxCalcSin(angle,12,'D')
      s~lineout('<circle class="sample role-'||series~role~lower||'" cx="'||format(x,,2)||'" cy="'||format(y,,2)||'" r="'||self~markerRadius(series~role)||'" fill="'||style[1]||'"/>')
    end
    y=legendY+(i-1)*18
    s~lineout('<line x1="24" y1="'||y||'" x2="58" y2="'||y||'" stroke="'||style[1]||'" stroke-width="'||style[2]||'"'||style[3]||'/>')
    s~lineout('<text x="66" y="'||(y+4)||'" font-family="sans-serif" font-size="12">'||self~escape(series~label)||' ['||series~role||']</text>')
  end
  self~writeAnnotations(s,graph,24,630,710)
  s~lineout('<text x="24" y="806" font-family="sans-serif" font-size="11">Reference SVG renderer: geometry is supplied by ooRexx ML evidence; SVG is presentation only.</text>')
  s~lineout('</svg>'); s~close; return path
::method renderCartesian2d private
  use strict arg graph,path,view
  a1=graph~axis(view~axis1); a2=graph~axis(view~axis2)
  s=.stream~new(path); rc=s~open('write replace')
  if rc<>'READY:' then raise syntax 88.900 array('unable to open graph output',path,rc)
  w=860; h=max(760,740+graph~annotationCount*16)
  if view~aspect='EQUAL' then do; left=150; right=710; top=70; bottom=630; end
  else do; left=90; right=820; top=85; bottom=610; end
  b=self~bounds2d(graph,a1,a2)
  if view~aspect='EQUAL' then b=self~equalBounds2d(graph,a1,a2,b)
  s~lineout('<svg xmlns="http://www.w3.org/2000/svg" width="860" height="'||h||'" viewBox="0 0 860 '||h||'" data-graph-view="'||view~name||'">')
  s~lineout('<rect width="860" height="'||h||'" fill="white"/>')
  s~lineout('<text x="24" y="34" font-family="sans-serif" font-size="22" font-weight="bold">'||self~escape(graph~title)||'</text>')
  s~lineout('<text x="24" y="58" font-family="sans-serif" font-size="13">view='||view~name||'; projection selects existing axes only; semantic coordinates are unchanged</text>')
  s~lineout('<rect x="'||left||'" y="'||top||'" width="'||(right-left)||'" height="'||(bottom-top)||'" fill="none" stroke="#d0d0d0"/>')
  do k=1 to 4
    gx=left+(right-left)*k/5; gy=top+(bottom-top)*k/5
    s~lineout('<line x1="'||format(gx,,2)||'" y1="'||top||'" x2="'||format(gx,,2)||'" y2="'||bottom||'" stroke="#eeeeee"/>')
    s~lineout('<line x1="'||left||'" y1="'||format(gy,,2)||'" x2="'||right||'" y2="'||format(gy,,2)||'" stroke="#eeeeee"/>')
  end
  colorMap=.directory~new; nextColor=1
  do i=1 to graph~seriesCount
    series=graph~seriesAt(i); key=series~semanticKey
    if \colorMap~hasIndex(key) then do; colorMap[key]=nextColor; nextColor=nextColor+1; end
    style=self~style(series~role,colorMap[key]); d=''; pts=series~points
    do j=1 to pts~items
      p=pts[j]; q=self~project2d(p~value(a1~name),p~value(a2~name),b,left,right,top,bottom)
      if j=1 then d='M '||q[1]||' '||q[2]; else d=d||' L '||q[1]||' '||q[2]
    end
    if series~closed & pts~items>0 then d=d||' Z'
    if series~connection='PATH' then s~lineout('<path d="'||d||'" fill="none" stroke="'||style[1]||'" stroke-width="'||style[2]||'"'||style[3]||'/>')
    do p over pts
      q=self~project2d(p~value(a1~name),p~value(a2~name),b,left,right,top,bottom)
      s~lineout('<circle class="sample role-'||series~role~lower||'" cx="'||q[1]||'" cy="'||q[2]||'" r="'||self~markerRadius(series~role)||'" fill="'||style[1]||'"/>')
    end
  end
  if graph~seriesCount>0 then do
    legendX=right-230; legendY=top+18; legendH=12+graph~seriesCount*18
    s~lineout('<rect class="graph-legend" x="'||(legendX-8)||'" y="'||(legendY-16)||'" width="230" height="'||legendH||'" fill="white" fill-opacity="0.88" stroke="#dddddd"/>')
    do i=1 to graph~seriesCount
      series=graph~seriesAt(i); key=series~semanticKey; style=self~style(series~role,colorMap[key]); ly=legendY+(i-1)*18
      if series~connection='POINTS' then s~lineout('<circle cx="'||(legendX+10)||'" cy="'||(ly-3)||'" r="'||self~markerRadius(series~role)||'" fill="'||style[1]||'"/>')
      else s~lineout('<line x1="'||legendX||'" y1="'||(ly-3)||'" x2="'||(legendX+28)||'" y2="'||(ly-3)||'" stroke="'||style[1]||'" stroke-width="'||style[2]||'"'||style[3]||'/>')
      s~lineout('<text x="'||(legendX+36)||'" y="'||ly||'" font-family="sans-serif" font-size="11">'||self~escape(series~label)||'</text>')
    end
  end
  s~lineout('<text x="'||((left+right)/2)||'" y="660" font-family="sans-serif" font-size="12" text-anchor="middle">'||self~escape(a1~label)||' ['||a1~role||']</text>')
  s~lineout('<text x="24" y="'||((top+bottom)/2)||'" font-family="sans-serif" font-size="12">'||self~escape(a2~label)||' ['||a2~role||']</text>')
  s~lineout('<text x="'||left||'" y="630" font-family="sans-serif" font-size="10">'||format(b[1],,5)||'</text>')
  s~lineout('<text x="'||right||'" y="630" font-family="sans-serif" font-size="10" text-anchor="end">'||format(b[2],,5)||'</text>')
  s~lineout('<text x="'||(left-8)||'" y="'||bottom||'" font-family="sans-serif" font-size="10" text-anchor="end">'||format(b[3],,5)||'</text>')
  s~lineout('<text x="'||(left-8)||'" y="'||top||'" font-family="sans-serif" font-size="10" text-anchor="end">'||format(b[4],,5)||'</text>')
  self~writeAnnotations(s,graph,24,690,820)
  s~lineout('<text x="24" y="'||(h-16)||'" font-family="sans-serif" font-size="11">Reference SVG axis-pair view: only the selected graph axes are projected.</text>')
  s~lineout('</svg>'); s~close; return path
::method bounds2d private
  use strict arg graph,a1,a2
  min1=.nil; max1=.nil; min2=.nil; max2=.nil
  do series over graph~series
    do p over series~points
      x=p~value(a1~name)+0; y=p~value(a2~name)+0
      if min1==.nil | x<min1 then min1=x; if max1==.nil | x>max1 then max1=x
      if min2==.nil | y<min2 then min2=y; if max2==.nil | y>max2 then max2=y
    end
  end
  if min1==.nil then do; min1=0; max1=1; min2=0; max2=1; end
  if max1=min1 then do; min1=min1-1; max1=max1+1; end
  if max2=min2 then do; min2=min2-1; max2=max2+1; end
  return .array~of(min1,max1,min2,max2)
::method equalBounds2d private
  use strict arg graph,a1,a2,b
  if graph~metadata('geometry','')='CYLINDER' & a1~role='CYLINDER_X' & a2~role='CYLINDER_Y' then do
    m=max(abs(b[1]),abs(b[2]),abs(b[3]),abs(b[4])); if m=0 then m=1
    return .array~of(-m,m,-m,m)
  end
  sx=b[2]-b[1]; sy=b[4]-b[3]; span=max(sx,sy); cx=(b[1]+b[2])/2; cy=(b[3]+b[4])/2
  return .array~of(cx-span/2,cx+span/2,cy-span/2,cy+span/2)
::method project2d private
  use strict arg x,y,b,left,right,top,bottom
  nx=(x-b[1])/(b[2]-b[1]); ny=(y-b[3])/(b[4]-b[3])
  px=left+nx*(right-left); py=bottom-ny*(bottom-top)
  return .array~of(format(px,,2),format(py,,2))
::method renderCartesian3d private
  use strict arg graph,path
  s=.stream~new(path); rc=s~open('write replace')
  if rc<>'READY:' then raise syntax 88.900 array('unable to open graph output',path,rc)
  w=980; h=860; cx=500; baseY=690; xyScale=235; zScale=500
  a1=graph~axis(1); a2=graph~axis(2); a3=graph~axis(3)
  bounds=self~bounds3d(graph,a1,a2,a3)
  s~lineout('<svg xmlns="http://www.w3.org/2000/svg" width="980" height="860" viewBox="0 0 980 860">')
  s~lineout('<rect width="980" height="860" fill="white"/>')
  s~lineout('<text x="24" y="34" font-family="sans-serif" font-size="22" font-weight="bold">'||self~escape(graph~title)||'</text>')
  s~lineout('<text x="24" y="58" font-family="sans-serif" font-size="13">3D coordinates are supplied evidence; view scaling and projection are presentation only.</text>')
  if graph~metadata('geometry','')='CYLINDER' then self~cylinderGuide(s,cx,baseY,xyScale,zScale)
  else self~boxGuide(s,cx,baseY,xyScale,zScale)
  legendY=735; colorMap=.directory~new; nextColor=1
  do i=1 to graph~seriesCount
    series=graph~seriesAt(i); key=series~semanticKey; if \colorMap~hasIndex(key) then do; colorMap[key]=nextColor; nextColor=nextColor+1; end
    style=self~style(series~role,colorMap[key]); d=''; pts=series~points
    do j=1 to pts~items
      p=pts[j]; q=self~project3d(p~value(a1~name),p~value(a2~name),p~value(a3~name),bounds,cx,baseY,xyScale,zScale)
      if j=1 then d='M '||q[1]||' '||q[2]; else d=d||' L '||q[1]||' '||q[2]
    end
    if series~connection='PATH' then s~lineout('<path d="'||d||'" fill="none" stroke="'||style[1]||'" stroke-width="'||style[2]||'"'||style[3]||'/>')
    do p over pts
      q=self~project3d(p~value(a1~name),p~value(a2~name),p~value(a3~name),bounds,cx,baseY,xyScale,zScale)
      s~lineout('<circle class="sample role-'||series~role~lower||'" cx="'||q[1]||'" cy="'||q[2]||'" r="'||self~markerRadius(series~role)||'" fill="'||style[1]||'"/>')
    end
    ly=legendY+((i-1)%3)*18; lx=24+((i-1)//3)*310
    s~lineout('<line x1="'||lx||'" y1="'||ly||'" x2="'||(lx+28)||'" y2="'||ly||'" stroke="'||style[1]||'" stroke-width="'||style[2]||'"'||style[3]||'/>')
    s~lineout('<text x="'||(lx+34)||'" y="'||(ly+4)||'" font-family="sans-serif" font-size="11">'||self~escape(series~label)||'</text>')
  end
  self~writeAnnotations(s,graph,24,795,930)
  s~lineout('<text x="24" y="842" font-family="sans-serif" font-size="11">Axes: '||self~escape(a1~label)||' / '||self~escape(a2~label)||' / '||self~escape(a3~label)||'. Time remains an explicit coordinate.</text>')
  s~lineout('</svg>'); s~close; return path
::method bounds3d private
  use strict arg graph,a1,a2,a3
  min1=.nil; max1=.nil; min2=.nil; max2=.nil; min3=.nil; max3=.nil
  do series over graph~series
    do p over series~points
      x=p~value(a1~name)+0; y=p~value(a2~name)+0; z=p~value(a3~name)+0
      if min1==.nil | x<min1 then min1=x; if max1==.nil | x>max1 then max1=x
      if min2==.nil | y<min2 then min2=y; if max2==.nil | y>max2 then max2=y
      if min3==.nil | z<min3 then min3=z; if max3==.nil | z>max3 then max3=z
    end
  end
  if min1==.nil then do; min1=-1; max1=1; min2=-1; max2=1; min3=0; max3=1; end
  if graph~metadata('geometry','')='CYLINDER' then do
    m=max(abs(min1),abs(max1),abs(min2),abs(max2)); if m=0 then m=1; min1=-m; max1=m; min2=-m; max2=m
  end
  if max1=min1 then do; min1=min1-1; max1=max1+1; end
  if max2=min2 then do; min2=min2-1; max2=max2+1; end
  if max3=min3 then do; min3=min3-1; max3=max3+1; end
  return .array~of(min1,max1,min2,max2,min3,max3)
::method project3d private
  use strict arg x,y,z,b,cx,baseY,xyScale,zScale
  nx=(x-b[1])/(b[2]-b[1])*2-1; ny=(y-b[3])/(b[4]-b[3])*2-1; nz=(z-b[5])/(b[6]-b[5])
  px=cx+(nx-ny)*xyScale*.72
  py=baseY-(nz*zScale)+(nx+ny)*xyScale*.23
  return .array~of(format(px,,2),format(py,,2))
::method cylinderGuide private
  use strict arg s,cx,baseY,r,zScale
  ry=r*.23; top=baseY-zScale
  s~lineout('<ellipse cx="'||cx||'" cy="'||baseY||'" rx="'||r||'" ry="'||format(ry,,2)||'" fill="none" stroke="#d0d0d0"/>')
  s~lineout('<ellipse cx="'||cx||'" cy="'||top||'" rx="'||r||'" ry="'||format(ry,,2)||'" fill="none" stroke="#d0d0d0"/>')
  s~lineout('<line x1="'||(cx-r)||'" y1="'||baseY||'" x2="'||(cx-r)||'" y2="'||top||'" stroke="#dddddd"/>')
  s~lineout('<line x1="'||(cx+r)||'" y1="'||baseY||'" x2="'||(cx+r)||'" y2="'||top||'" stroke="#dddddd"/>')
  s~lineout('<text x="'||(cx+r+10)||'" y="'||(top+4)||'" font-family="sans-serif" font-size="11">later</text>')
  s~lineout('<text x="'||(cx+r+10)||'" y="'||baseY||'" font-family="sans-serif" font-size="11">earlier</text>')
  return
::method boxGuide private
  use strict arg s,cx,baseY,r,zScale
  s~lineout('<line x1="'||(cx-r)||'" y1="'||baseY||'" x2="'||(cx+r)||'" y2="'||baseY||'" stroke="#d0d0d0"/>')
  s~lineout('<line x1="'||cx||'" y1="'||baseY||'" x2="'||cx||'" y2="'||(baseY-zScale)||'" stroke="#d0d0d0"/>')
  return
::method polarPath private
  use strict arg series,cx,cy,pr
  d=''; pts=series~points
  do i=1 to pts~items
    p=pts[i]; angle=p~value('angle'); rr=pr*p~value('radius')
    x=cx+rr*RxCalcCos(angle,12,'D'); y=cy-rr*RxCalcSin(angle,12,'D')
    if i=1 then d='M '||format(x,,2)||' '||format(y,,2)
    else d=d||' L '||format(x,,2)||' '||format(y,,2)
  end
  if series~closed & pts~items>0 then d=d||' Z'
  return d
::method writeAnnotations private
  use strict arg stream,graph,x,y,width
  if graph~annotationCount=0 then return
  lineY=y; stream~lineout('<g class="graph-annotations">')
  do a over graph~annotations
    if a~kind<>'SUMMARY' then iterate
    stream~lineout('<text class="graph-annotation summary" x="'||x||'" y="'||lineY||'" font-family="sans-serif" font-size="11" font-weight="bold">'||self~escape(a~text)||'</text>')
    lineY=lineY+15
  end
  stream~lineout('</g>')
  return
::method markerRadius private
  use strict arg role
  r=role~string~upper
  if r='RESTORING_SET' then return '5.2'
  if r='PARTICIPATION' then return '4.2'
  if r='OBSERVED' then return '3.2'
  return '2.4'
::method style private
  use strict arg role,index=1
  palette=.array~of('#111111','#2c5f9e','#327a4b','#a35d1d','#7a4a8f','#177f86','#9a3c3c','#4e6d2d')
  color=palette[1+((index-1)//palette~items)]
  r=role~string~upper
  if r='EQUIVALENT' then return .array~of(color,'4',' stroke-dasharray="2 7"')
  if r='NEAR' then return .array~of(color,'2',' stroke-dasharray="10 5"')
  if r='CONTRAST' | r='DIFFERENCE' then return .array~of(color,'1.5',' stroke-dasharray="18 5 3 5"')
  if r='REFERENCE' | r='SECONDARY' | r='BASELINE_FIT' then return .array~of(color,'1.5',' stroke-dasharray="6 4"')
  if r='RESTORED_FIT' then return .array~of(color,'2.5','')
  return .array~of(color,'2.5','')
::method escape private
  use strict arg text
  x=text~string
  x=x~changeStr('&','&amp;'); x=x~changeStr('<','&lt;'); x=x~changeStr('>','&gt;'); x=x~changeStr('"','&quot;')
  return x
