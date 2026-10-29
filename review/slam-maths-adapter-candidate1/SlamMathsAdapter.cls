/*
 * Review-only SLAM -> ooRexx Maths adapter candidate.
 * Architecture: Tom Dyer. Adapter: ChatGPT GPT-6.
 *
 * Does not own SLAM grounding, vocabulary, TESTED-edge admission or composition.
 * Mirrors the current SlamMaths list-in/list-out numerical surface so SLAM can
 * delegate reusable mathematics to ooRexx Maths.
 */
::class SlamMathsAdapter public

::method init
  expose _context
  use strict arg context=.nil
  if context==.nil then context=.MathContext~decimal(20)
  _context=context

::method statistics private
  expose _context
  use strict arg values
  return .Maths~statistics(values,_context)

::method total
  use strict arg values
  return self~statistics(values)~sum

::method add
  use strict arg values
  return .array~of(self~total(values))

::method count
  use strict arg values
  return .array~of(values~items)

::method mean
  use strict arg values
  return .array~of(self~statistics(values)~mean)

::method sorted
  use strict arg values
  return self~statistics(values)~sortedValues

::method median
  use strict arg values
  return .array~of(self~statistics(values)~median)

::method mode
  use strict arg values
  return .array~of(self~statistics(values)~uniqueMode)

::method range
  use strict arg values
  return .array~of(self~statistics(values)~range)

::method deviation
  use strict arg values
  return self~statistics(values)~deviations~toArray

::method square
  use strict arg values
  return self~statistics(values)~squaredValues~toArray

::method root
  expose _context
  use strict arg values
  out=.array~new
  do value over values
    out~append(.Maths~sqrt(value,_context))
  end
  return out

::method variance
  use strict arg values
  return .array~of(self~statistics(values)~populationVariance)

::method standard
  use strict arg values
  return .array~of(self~statistics(values)~populationStdDev)

::method multiply
  use strict arg values
  return .array~of(self~statistics(values)~product)

::method subtract
  expose _context
  use strict arg values
  if values~items=0 then raise syntax 88.900 array('subtract requires at least one value',0)
  coerced=.Maths~statistics(values,_context)~values
  value=coerced[1]
  do i=2 to coerced~items
    value=value-coerced[i]
  end
  return .array~of(value)

::method divide
  expose _context
  use strict arg values
  if values~items=0 then raise syntax 88.900 array('divide requires at least one value',0)
  coerced=.Maths~statistics(values,_context)~values
  value=coerced[1]
  do i=2 to coerced~items
    if coerced[i]=0 then raise syntax 42.3
    value=value/coerced[i]
  end
  return .array~of(value)

::requires 'MathsBootstrap.cls'
