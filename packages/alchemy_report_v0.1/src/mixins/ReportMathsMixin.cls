/******************************************************************************/
/* Report maths mixin — arithmetic and proofs come from oorexx_maths.         */
/* This mixin does not implement addition. .Maths does.                       */
/******************************************************************************/
::class ReportMathsMixin mixinclass public

::method requireMaths
  signal on syntax name missing
  ignore = .Maths~exact("0")
  return .true
missing:
  raise syntax 40.900 array("ReportMathsMixin requires oorexx_maths (.Maths)")

::method exactAmount
  use arg value
  ignore = self~requireMaths
  return .Maths~exact(value~string)

::method addAmount
  use arg a, b
  ignore = self~requireMaths
  left = .Maths~exact(a~string)
  return left + .Maths~exact(b~string)

::method amountsEqual
  use arg a, b
  ignore = self~requireMaths
  left = .Maths~exact(a~string)
  right = .Maths~exact(b~string)
  claim = .MathClaim~equals(right)
  proof = left~prove(claim)
  return proof~verified

::method proveEqual
  use arg a, b
  ignore = self~requireMaths
  left = .Maths~exact(a~string)
  right = .Maths~exact(b~string)
  claim = .MathClaim~equals(right)
  return left~prove(claim)

::method debitCredit
  use arg postings
  ignore = self~requireMaths
  dr = .Maths~exact("0")
  cr = .Maths~exact("0")
  do i = 1 to postings~items
     d = postings[i]
     side = d["side"]~string~upper
     amt = .Maths~exact(d["amount"]~string)
     if side = "DR" | side = "DEBIT" then dr = dr + amt
     else if side = "CR" | side = "CREDIT" then cr = cr + amt
     else raise syntax 40.900 array("posting side must be DR or CR")
  end
  claim = .MathClaim~equals(cr)
  proof = dr~prove(claim)
  r = .directory~new
  r["debit"] = dr
  r["credit"] = cr
  r["proof"] = proof
  r["balanced"] = proof~verified
  r["outcome"] = proof~outcome
  return r

::method notAdditive
  use arg actual, reflections
  ignore = self~requireMaths
  work = .Maths~exact(actual~string)
  n = .Maths~exact(reflections~string)
  wrong = work * n
  claim = .MathClaim~equals(work)
  proof = work~prove(claim)
  r = .directory~new
  r["accounted"] = work
  r["additiveWrong"] = wrong
  r["proof"] = proof
  r["ok"] = proof~verified
  return r
