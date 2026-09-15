/******************************************************************************/
/* Digest checks using oorexx_crypto .SHA512 when loaded.                     */
/* Mixin does not ::requires crypto.cls.                                      */
/******************************************************************************/
::class ReportCryptoCheckMixin mixinclass public

::method digestOf
  use arg bytes
  return .ReportSealDigest~of(bytes)

::method digestEngine
  return .ReportSealDigest~engine

::method bindingMatchesLive
  /* Compare binding sourceDigest to digest of live retained bytes.
     Returns MATCH / STALE / UNAVAILABLE / MISSING. */
  use arg binding, liveBytes
  if binding = .nil then return "MISSING"
  stored = binding~sourceDigest
  if stored = "" then return "MISSING"
  signal on syntax name unavailable
  live = .ReportSealDigest~of(liveBytes)
  /* Compare payload after scheme prefix when both use the same engine. */
  if stored = live then return "MATCH"
  if stored~pos(":") > 0 & live~pos(":") > 0 then do
     if stored~substr(stored~pos(":") + 1) = live~substr(live~pos(":") + 1) then
        return "MATCH"
  end
  return "STALE"
unavailable:
  return "UNAVAILABLE"

::method markStaleBindings
  use arg liveByBindingId
  /* liveByBindingId is a directory bindingId -> live bytes */
  n = 0
  do id over liveByBindingId
     b = self~binding(id)
     if b = .nil then iterate
     liveBytes = liveByBindingId[id]
     st = self~bindingMatchesLive(b, liveBytes)
     if st = "STALE" then do
        ignore = self~markStaleIfDigestDiffers(id, self~digestOf(liveBytes))
        n = n + 1
     end
  end
  return n
