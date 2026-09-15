::routine civicNotamTestQueueDocument public
  use arg body, messageId, acceptedAt = "2026-08-28T12:00:01Z", useClassification = "NOT_FOR_OPERATIONAL_USE"
  digestPort = .CivicDigestPort~new
  headers = .directory~new
  headers["JMSMESSAGEID"] = messageId~string
  properties = .directory~new
  headerDigest = digestPort~sha512Bytes(.CivicQueueMapCodec~encode(headers))
  propertyDigest = digestPort~sha512Bytes(.CivicQueueMapCodec~encode(properties))
  bodyDigest = digestPort~sha512Bytes(body)
  sourceIdentity = "JMS:" || c2x("SOLACE") || ":" || c2x("AIM_FNS") || ":" || c2x(messageId~string)
  return .CivicQueueDocument~new(sourceIdentity, "FAA.SWIM.AIM_FNS", "QPKG-" || c2x(messageId~string), messageId, "SOLACE", "AIM_FNS", "TEXT", body, bodyDigest, -
    headers, properties, headerDigest, propertyDigest, "2026-08-28T12:00:00Z", acceptedAt, "2026-08-28T12:00:00Z", "", "", 4, useClassification)

::requires "CivicQueueEvidence.cls"
