/* RubyAlchemyCallbacks.cls - dev11 protected callback trampoline.
 * Conditions are trapped while their full Rexx condition Directory still exists.
 */
::class RubyAlchemyCallbackGuard public

/* Retain the real callback target; the guard adds no business semantics. */
::method init
  expose target
  use strict arg target

/* Dynamically invoke the exact target selector and return a structured envelope.
 * SIGNAL ON ANY runs in Rexx, before the native API boundary can lose condition state. */
::method unknown
  expose target
  use strict arg selector, args
  signal on any name callbackCondition
  env=.directory~new
  env['KIND']='value'
  env['VALUE']=target~sendWith(selector,args)
  return env
callbackCondition:
  env=.directory~new
  env['KIND']='condition'
  env['CONDITION']=condition('O')
  return env
