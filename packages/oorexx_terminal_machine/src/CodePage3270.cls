/* IBM 3270 character conversion boundary.  CP037 reuses the exact reversible
 * table already qualified by Terminal Machine; 3270-specific semantics live
 * above the code page rather than in it. */
::class CodePage3270Registry public
::method forName class
  use arg nameArg = "37"
  return .CodePage5250Registry~forName(nameArg)
::requires "CodePage5250.cls"
