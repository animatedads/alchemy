/* Audio techniques: pure ooRexx reference implementations. 0.1 */
::class AudioTechniqueRegistry public
::method init
 expose methods
 methods=.Directory~new
 self~register('DC_REMOVE',.AudioDCRemove~new)
 self~register('PREEMPHASIS',.AudioPreEmphasis~new)
 self~register('DEEMPHASIS',.AudioDeEmphasis~new)
 self~register('MOVING_AVERAGE',.AudioMovingAverage~new)
 self~register('MEDIAN_FILTER',.AudioMedianFilter~new)
 self~register('ENERGY_GATE',.AudioEnergyGate~new)
 self~register('FIRST_DIFFERENCE',.AudioFirstDifference~new)
::method register
 expose methods
 use strict arg name,technique
 methods~put(technique,translate(name))
 return self
::method get
 expose methods
 use strict arg name
 return methods~at(translate(name))
::method names
 expose methods
 return methods~allIndexes
::method process
 use strict arg name,samples,parameter
 tech=self~get(name)
 if tech==.nil then raise syntax 93.900 array('Unknown audio technique',name)
 return tech~process(samples,parameter)

::class AudioTechnique public
::method copySamples
 use strict arg samples
 if \samples~isA(.Array) then raise syntax 93.900 array('Expected .Array of PCM samples')
 out=.Array~new
 do i=1 to samples~items
   if \datatype(samples[i],'N') then raise syntax 93.900 array('Non-numeric PCM sample',i)
   out~append(samples[i]+0)
 end
 return out
::method describe
 return 'REFERENCE'

::class AudioDCRemove subclass AudioTechnique public
::method process
 use strict arg samples,unused
 x=self~copySamples(samples)
 n=x~items
 if n=0 then return x
 total=0
 do i=1 to n; total=total+x[i]; end
 avg=total/n
 do i=1 to n; x[i]=x[i]-avg; end
 return x

::class AudioPreEmphasis subclass AudioTechnique public
::method process
 use strict arg samples,alpha
 x=self~copySamples(samples)
 if \datatype(alpha,'N') then raise syntax 93.900 array('Numeric coefficient required')
 if alpha<0 | alpha>=1 then raise syntax 93.900 array('Coefficient must be in [0,1)')
 y=.Array~new
 if x~items=0 then return y
 y~append(x[1])
 do i=2 to x~items; y~append(x[i]-alpha*x[i-1]); end
 return y

::class AudioDeEmphasis subclass AudioTechnique public
::method process
 use strict arg samples,alpha
 x=self~copySamples(samples)
 if \datatype(alpha,'N') then raise syntax 93.900 array('Numeric coefficient required')
 if alpha<0 | alpha>=1 then raise syntax 93.900 array('Coefficient must be in [0,1)')
 y=.Array~new
 if x~items=0 then return y
 y~append(x[1])
 do i=2 to x~items; y~append(x[i]+alpha*y[i-1]); end
 return y

::class AudioMovingAverage subclass AudioTechnique public
::method process
 use strict arg samples,width
 x=self~copySamples(samples)
 if \datatype(width,'W') | width<1 then raise syntax 93.900 array('Positive integer width required')
 y=.Array~new
 total=0
 do i=1 to x~items
  total=total+x[i]
  if i>width then total=total-x[i-width]
  y~append(total/min(i,width))
 end
 return y

::class AudioMedianFilter subclass AudioTechnique public
::method process
 use strict arg samples,width
 x=self~copySamples(samples)
 if \datatype(width,'W') | width<1 | width//2=0 then raise syntax 93.900 array('Positive odd integer width required')
 y=.Array~new
 radius=(width-1)/2
 do i=1 to x~items
  a=.Array~new
  do j=max(1,i-radius) to min(x~items,i+radius); a~append(x[j]); end
  do j=2 to a~items
   v=a[j]; k=j-1
   do while k>=1
    if a[k]<=v then leave
    a[k+1]=a[k]; k=k-1
   end
   a[k+1]=v
  end
  y~append(a[(a~items+1)%2])
 end
 return y

::class AudioEnergyGate subclass AudioTechnique public
::method process
 use strict arg samples,threshold
 x=self~copySamples(samples)
 if \datatype(threshold,'N') | threshold<0 then raise syntax 93.900 array('Nonnegative threshold required')
 do i=1 to x~items
  if abs(x[i])<threshold then x[i]=0
 end
 return x

::class AudioFirstDifference subclass AudioTechnique public
::method process
 use strict arg samples,unused
 x=self~copySamples(samples)
 y=.Array~new
 if x~items=0 then return y
 y~append(0)
 do i=2 to x~items; y~append(x[i]-x[i-1]); end
 return y
