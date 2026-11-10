/* ooRexx Physics World v0.1-dev10
   Explicit brittle-fracture criteria and post-fracture topology views.

   This module deliberately does not create decorative "damage percentages".
   A fracture event is a state transition of a real DeformableLink.  Once the
   link breaks it no longer carries load, so the existing deformable solver's
   connectivity changes immediately.  Fragments are the connected components
   of the remaining intact node/link graph.

   The first fracture law is intentionally modest: an axial tensile or
   compressive strength criterion optionally gated by critical fracture energy
   per unit crack area.  It is not a continuum crack-tip / stress-intensity
   solver and does not claim arbitrary crack-surface generation.
*/

::class FractureUnitBoundary
::method scalar class
  use strict arg value,expectedDimension,label
  numeric digits 50
  if value==.nil then return .nil
  if value~isA(.UnitQuantity) then do
    if \value~dimension~compatible(expectedDimension) then -
      raise syntax 93.900 array(label 'has incompatible physical dimension')
    return value~canonicalValue+0
  end
  return value+0
::method energyReleaseRateUnit class
  return .Units~joule/.Units~squareMetre

::class BrittleFractureLaw public
::method init
  expose _name _tensile _compressive _criticalEnergyReleaseRate
  use strict arg name,tensileStrength,compressiveStrength=.nil,criticalEnergyReleaseRate=.nil
  _name=name
  _tensile=.FractureUnitBoundary~scalar(tensileStrength,.Units~pascal~dimension,'fracture tensile strength')
  _compressive=.FractureUnitBoundary~scalar(compressiveStrength,.Units~pascal~dimension,'fracture compressive strength')
  _criticalEnergyReleaseRate=.FractureUnitBoundary~scalar(criticalEnergyReleaseRate,.FractureUnitBoundary~energyReleaseRateUnit~dimension,'critical fracture energy release rate')
  if _tensile<=0 then raise syntax 88.900 array('positive fracture tensile strength',_tensile)
  if _compressive<>.nil then if _compressive<=0 then raise syntax 88.900 array('positive fracture compressive strength',_compressive)
  if _criticalEnergyReleaseRate<>.nil then if _criticalEnergyReleaseRate<0 then raise syntax 88.900 array('non-negative critical fracture energy release rate',_criticalEnergyReleaseRate)
::method name; expose _name; return _name
::method tensileStrength; expose _tensile; return _tensile
::method tensileStrengthQuantity; return .Units~q(self~tensileStrength,.Units~pascal)
::method compressiveStrength; expose _compressive; return _compressive
::method compressiveStrengthQuantity
  if self~compressiveStrength==.nil then return .nil
  return .Units~q(self~compressiveStrength,.Units~pascal)
::method criticalEnergyReleaseRate; expose _criticalEnergyReleaseRate; return _criticalEnergyReleaseRate
::method criticalEnergyReleaseRateQuantity
  if self~criticalEnergyReleaseRate==.nil then return .nil
  return .Units~q(self~criticalEnergyReleaseRate,.FractureUnitBoundary~energyReleaseRateUnit)
::method surfaceEnergyFor
  use strict arg crackArea,availableEnergy
  if crackArea<=0 then raise syntax 88.900 array('positive fracture crack area',crackArea)
  if availableEnergy<0 then raise syntax 88.900 array('non-negative available fracture energy',availableEnergy)
  if self~criticalEnergyReleaseRate==.nil then return 0
  required=self~criticalEnergyReleaseRate*crackArea
  if required>availableEnergy then return availableEnergy
  return required
::method failureCriterion
  use strict arg axialStress,elasticEnergy,crackArea
  if crackArea<=0 then raise syntax 88.900 array('positive fracture crack area',crackArea)
  criterion=''
  if axialStress>=self~tensileStrength then criterion='TENSION'
  else if axialStress<0 & self~compressiveStrength<>.nil then do
    if abs(axialStress)>=self~compressiveStrength then criterion='COMPRESSION'
  end
  if criterion=='' then return ''
  if self~criticalEnergyReleaseRate<>.nil then do
    releaseRate=elasticEnergy/crackArea
    if releaseRate<self~criticalEnergyReleaseRate then return ''
    criterion=criterion || '_ENERGY'
  end
  return criterion

::class FractureEvent public
::method init
  expose _body _link _point _direction _time _criterion _stress _strain _releasedEnergy _surfaceEnergy _unresolvedEnergy _crackArea
  use strict arg body,link,timeSeconds
  _body=body; _link=link; _time=timeSeconds
  _point=link~fracturePoint; _direction=link~fractureDirection
  _criterion=link~fractureCriterion; _stress=link~fractureStress
  _strain=link~fractureStrainAtFailure; _releasedEnergy=link~fractureEnergy
  _surfaceEnergy=link~fractureSurfaceEnergy; _unresolvedEnergy=link~unresolvedFractureEnergy
  _crackArea=link~area
::method kind; return 'DEFORMABLE_FRACTURE'
::method body; expose _body; return _body
::method link; expose _link; return _link
::method point; expose _point; return _point
::method direction; expose _direction; return _direction
::method time; expose _time; return _time
::method timeQuantity; return .Units~q(self~time,.Units~second)
::method criterion; expose _criterion; return _criterion
::method stress; expose _stress; return _stress
::method stressQuantity; return .Units~q(self~stress,.Units~pascal)
::method strain; expose _strain; return _strain
::method strainQuantity; return .Units~q(self~strain,.Units~one)
::method releasedEnergy; expose _releasedEnergy; return _releasedEnergy
::method releasedEnergyQuantity; return .Units~q(self~releasedEnergy,.Units~joule)
::method surfaceCreationEnergy; expose _surfaceEnergy; return _surfaceEnergy
::method surfaceCreationEnergyQuantity; return .Units~q(self~surfaceCreationEnergy,.Units~joule)
::method unresolvedReleasedEnergy; expose _unresolvedEnergy; return _unresolvedEnergy
::method unresolvedReleasedEnergyQuantity; return .Units~q(self~unresolvedReleasedEnergy,.Units~joule)
::method crackArea; expose _crackArea; return _crackArea
::method crackAreaQuantity; return .Units~q(self~crackArea,.Units~squareMetre)
::method energyReleaseRate
  if self~crackArea<=0 then return 0
  return self~releasedEnergy/self~crackArea
::method energyReleaseRateQuantity; return .Units~q(self~energyReleaseRate,.FractureUnitBoundary~energyReleaseRateUnit)

::class FractureFragment public
::method init
  expose _body _nodes
  use strict arg body,nodes
  _body=body; _nodes=nodes~copy
::method body; expose _body; return _body
::method nodes; expose _nodes; return _nodes~copy
::method nodeCount; expose _nodes; return _nodes~items
::method contains
  expose _nodes
  use strict arg node
  do n over _nodes; if n==node then return .true; end
  return .false
::method links
  expose _body
  linkArray=.array~new
  do link over _body~links
    if link~broken then iterate
    if self~contains(link~nodeA) & self~contains(link~nodeB) then linkArray~append(link)
  end
  return linkArray
::method mass
  expose _nodes
  total=0; do n over _nodes; total=total+n~mass; end; return total
::method massQuantity; return .Units~q(self~mass,.Units~kilogram)
::method momentum
  expose _nodes
  if _nodes~items=0 then return .MathVector3~new(0,0,0,.Maths~defaultContext)
  p=.MathVector3~new(0,0,0,_nodes[1]~position~context)
  do n over _nodes; if \n~fixed then p=p+n~momentum; end
  return p
::method momentumQuantity; return .Units~q(self~momentum,.Units~newtonSecond)
::method centroid
  expose _nodes
  if _nodes~items=0 then raise syntax 88.900 array('fracture fragment with nodes')
  c=.MathVector3~new(0,0,0,_nodes[1]~position~context); total=0
  do n over _nodes; c=c+n~position*n~mass; total=total+n~mass; end
  return c*(1/total)

::class FractureTopology public
::method containsNode class
  use strict arg collection,node
  do item over collection; if item==node then return .true; end
  return .false
::method fragments class
  use strict arg body
  nodes=body~nodes; visited=.array~new; fragmentsArray=.array~new
  do seed over nodes
    if self~containsNode(visited,seed) then iterate
    component=.array~new; frontier=.array~new
    frontier~append(seed); visited~append(seed)
    do while frontier~items>0
      idx=frontier~items; current=frontier[idx]; frontier~delete(idx)
      component~append(current)
      do link over body~links
        if link~broken then iterate
        neighbor=.nil
        if link~nodeA==current then neighbor=link~nodeB
        else if link~nodeB==current then neighbor=link~nodeA
        if neighbor<>.nil then do
          if \self~containsNode(visited,neighbor) then do
            visited~append(neighbor); frontier~append(neighbor)
          end
        end
      end
    end
    fragmentsArray~append(.FractureFragment~new(body,component))
  end
  return fragmentsArray

::requires 'Mechanics.cls'
