/* Physics World v0.1-dev46.1-bass1
 * Four-string electric bass. Not a new instrument engine: a bass is a
 * transverse string under tension terminated at a bridge/body boundary.
 */
numeric digits 30

::class BassInstrumentFactory public

::method standardStringSet class
 use strict arg openFrequencies=.nil,scaleLengthM=.864,tensionN=190,inharmonicity=.00008,damping0=2.8,dampingN=.018,modes=5
 if openFrequencies==.nil then openFrequencies=.array~of(41.2034446,55.0,73.4161919,97.9988587)
 if openFrequencies~items<>4 then raise syntax 88.900 array('four bass open-string frequencies required')
 models=.array~new
 do f over openFrequencies
   linearDensityKgPerM=tensionN/((2*scaleLengthM*f)**2)
   models~append(.GuitarStringPhysicalModel~new(f,scaleLengthM,linearDensityKgPerM,tensionN,inharmonicity,damping0,dampingN,modes))
 end
 return models

::method standardBodyModes class
 return .array~of(.GuitarBodyMode~new('body-90',90,.34,.030,.06,1),.GuitarBodyMode~new('body-180',180,.20,.040,.035,.7))

::method standardBridgeImpedance class
 return .GuitarBoundaryImpedance~new('bridge',2600,.22,1,'bass development default')
::method standardNutImpedance class
 return .GuitarBoundaryImpedance~new('nut',11000,.12,1,'bass development default')

::method standardFourStringBass class
 use strict arg stringModels=.nil,frets=.nil,bodyModes=.nil,bridgeImpedance=.nil,nutImpedance=.nil,pluckCourse=1,pluckDisplacementM=.0014,pluckFraction=.20
 if stringModels==.nil then stringModels=self~standardStringSet
 if frets==.nil then frets=.array~of(0,0,0,0)
 if bodyModes==.nil then bodyModes=self~standardBodyModes
 if bridgeImpedance==.nil then bridgeImpedance=self~standardBridgeImpedance
 if nutImpedance==.nil then nutImpedance=self~standardNutImpedance
 if stringModels~items<>4 | frets~items<>4 then raise syntax 88.900 array('four bass string models and fret states required')
 names=.array~of('E1','A1','D2','G2');courses=.array~new
 do i=1 to 4
   c=.GuitarStringCourse~new(names[i],stringModels[i],frets[i],pluckFraction,.82)
   do n=1 to stringModels[i]~modeCount
     amp=0;if i=pluckCourse then amp=stringModels[i]~modalAmplitude(n,pluckFraction,pluckDisplacementM)
     w=stringModels[i]~modalAngularFrequency(frets[i],n,0);pi=4*RxCalcArcTan(1,30,'R')
     mass=stringModels[i]~modalEffectiveMass(frets[i],n);z=stringModels[i]~modalDamping(n,'PICK')/w
     c~addOscillator(.GuitarCoupledOscillator~new(names[i]'-'n,mass,w/(2*pi),z,amp,0,'STRING_MODE',stringModels[i]))
   end
   courses~append(c)
 end
 bodies=.array~new
 do bm over bodyModes
   bodies~append(.GuitarCoupledOscillator~new(bm~name,bm~effectiveMass,bm~frequencyHz,bm~dampingRatio,0,0,'BODY_MODE',bm))
 end
 return .GuitarInstrumentMechanics~new(courses,bodies,bridgeImpedance,nutImpedance)

::requires 'rxmath' LIBRARY
::requires 'GuitarInstrumentMechanics.cls'
