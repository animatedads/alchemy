/* This procedure is installed in ooRexx Macrospace as PYALARM.
   It is deliberately tiny: Macrospace supplies the REXX-side named dispatch;
   PYCALLBACK is the native boundary back into the Python object+method. */
use strict arg message
return PYCALLBACK(message)
