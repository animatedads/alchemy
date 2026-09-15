/*
 * CivicPort v0.13 Companies House company-profile adapters.
 *
 * This is an explicit mapping over the public company profile resource. It
 * does not flatten structured arrays such as sic_codes. Those remain intact in
 * CivicDocument~parsed until a later explicit projection is designed.
 */



::class CivicCompaniesHouseEnvironment public
::constant LIVE "LIVE"
::constant SANDBOX "SANDBOX"
::constant LIVE_HOST "api.company-information.service.gov.uk"
::constant SANDBOX_HOST "api-sandbox.company-information.service.gov.uk"
::constant LIVE_CREDENTIAL_REFERENCE "companieshouse-live"
::constant SANDBOX_CREDENTIAL_REFERENCE "companieshouse-sandbox"

::class CivicCompaniesHouseMapping subclass CivicJsonMapping public
::method init
  self~init:super("companieshouse.company-profile/0.1")
  ignore = self~addField("company_number", "/company_number", .true, "STRING")
  ignore = self~addField("company_name", "/company_name", .true, "STRING")
  ignore = self~addField("company_status", "/company_status", .true, "STRING")
  ignore = self~addField("company_type", "/type", .false, "STRING", .true)
  ignore = self~addField("date_of_creation", "/date_of_creation", .false, "STRING", .true)
  ignore = self~addField("jurisdiction", "/jurisdiction", .false, "STRING", .true)
  ignore = self~addField("registered_office_address_line_1", "/registered_office_address/address_line_1", .false, "STRING", .true)
  ignore = self~addField("registered_office_address_line_2", "/registered_office_address/address_line_2", .false, "STRING", .true)
  ignore = self~addField("registered_office_locality", "/registered_office_address/locality", .false, "STRING", .true)
  ignore = self~addField("registered_office_region", "/registered_office_address/region", .false, "STRING", .true)
  ignore = self~addField("registered_office_postal_code", "/registered_office_address/postal_code", .false, "STRING", .true)
  ignore = self~addField("registered_office_country", "/registered_office_address/country", .false, "STRING", .true)
  ignore = self~addField("has_insolvency_history", "/has_insolvency_history", .false, "BOOLEAN", .true)
  ignore = self~initCivicAlchemy


::class CivicCompaniesHouseAdapter subclass CivicAlchemyObject public
::attribute mapping get

::method init
  expose mapping
  ignore = self~initCivicAlchemy
  mapping = .CivicCompaniesHouseMapping~new

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
  return .CivicEndpointTemplate~new("https", .CivicCompaniesHouseEnvironment~LIVE_HOST, "/company/{company_number}")

::method validatedCompanyNumber class
  use arg companyNumber
  number = companyNumber~string~strip~translate
  if number = "" | number~length > 32 then raise syntax 93.900 additional("Companies House company number must contain 1 to 32 alphanumeric characters")
  do i = 1 to number~length
    ch = number~substr(i, 1)
    if \datatype(ch, "A") & \datatype(ch, "N") then raise syntax 93.900 additional("Companies House company number contains unsupported characters")
  end
  return number

::method companyUrl class
  use arg companyNumber
  number = .CivicCompaniesHouseAdapter~validatedCompanyNumber(companyNumber)
  return "https://" || .CivicCompaniesHouseEnvironment~LIVE_HOST || "/company/" || number


::class CivicCompaniesHouseSandboxAdapter subclass CivicCompaniesHouseAdapter public

::method endpointTemplate class
  return .CivicEndpointTemplate~new("https", .CivicCompaniesHouseEnvironment~SANDBOX_HOST, "/company/{company_number}")

::method companyUrl class
  use arg companyNumber
  number = .CivicCompaniesHouseAdapter~validatedCompanyNumber(companyNumber)
  return "https://" || .CivicCompaniesHouseEnvironment~SANDBOX_HOST || "/company/" || number

::requires "CivicJson.cls"
::requires "CivicPolicy.cls"
::requires "CivicAlchemy.cls"
