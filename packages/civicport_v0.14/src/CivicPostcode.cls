/* CivicPort v0.3 postcodes.io adapter: explicit pointers, no schema inference. */

::class CivicPostcodeMapping subclass CivicJsonMapping public
::method init
  self~init:super("postcodes.io.postcode/0.2")
  ignore = self~addField("http_status", "/status", .true, "NUMBER")
  ignore = self~addField("postcode", "/result/postcode", .true, "STRING")
  ignore = self~addField("country", "/result/country", .true, "STRING")
  ignore = self~addField("admin_district", "/result/admin_district", .false, "STRING", .true)
  ignore = self~addField("region", "/result/region", .false, "STRING", .true)
  ignore = self~addField("longitude", "/result/longitude", .false, "NUMBER", .true)
  ignore = self~addField("latitude", "/result/latitude", .false, "NUMBER", .true)
  ignore = self~addField("parliamentary_constituency", "/result/parliamentary_constituency", .false, "STRING", .true)

  ignore = self~initCivicAlchemy
::method validateMapped protected
  use arg document, row, sourcePointer = ""
  id = self~mappingId
  if row["http_status"]~string \= document~status~string then -
    return .CivicJsonMappingResult~invalid(document, id, "SCHEMA_STATUS_MISMATCH", "JSON status does not match HTTP status", sourcePointer)
  return .CivicJsonMappingResult~success(document, id, row, sourcePointer)


::class CivicPostcodeAdapter subclass CivicAlchemyObject public
::attribute mapping get

::method init
  expose mapping
  mapping = .CivicPostcodeMapping~new

  ignore = self~initCivicAlchemy
::method map
  expose mapping
  use arg document
  return mapping~map(document)

::method mapAll
  use arg document
  mapped = self~map(document)
  if \mapped~ok then return .CivicJsonCollectionMappingResult~invalid(document, mapped~mappingId, mapped~errorCode, mapped~message)
  return .CivicJsonCollectionMappingResult~success(document, mapped~mappingId, .array~of(mapped))

::method endpointTemplate class
  return .CivicEndpointTemplate~new("https", "api.postcodes.io", "/postcodes/{postcode}")

::requires "CivicJson.cls"
::requires "CivicPolicy.cls"

::requires "CivicAlchemy.cls"
