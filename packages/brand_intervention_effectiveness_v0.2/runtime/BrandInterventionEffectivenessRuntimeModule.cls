::class BrandInterventionEffectivenessRuntimeModule public
::attribute starts get
::attribute quiesces get
::attribute stops get
::method init
  expose starts quiesces stops
  starts=0; quiesces=0; stops=0
::method runtimeStart
  expose starts; starts+=1; return .true
::method runtimeQuiesce
  expose quiesces; quiesces+=1; return .true
::method runtimeStop
  expose stops; stops+=1; return .true
::method generationLabel
  return "BRAND-INTERVENTION-EFFECTIVENESS-V0.2"
::method apiVersion
  return .BrandInterventionEffectivenessBuild~API_VERSION
::method newEngine
  return .BrandInterventionEffectivenessEngine~new
::method newLibrary
  return .BrandInterventionEffectivenessLibrary~new
::method newBridge
  return .BrandInterventionEffectivenessBridge~new
::requires "BrandInterventionEffectiveness.cls"
::requires "BrandInterventionEffectivenessBridge.cls"
