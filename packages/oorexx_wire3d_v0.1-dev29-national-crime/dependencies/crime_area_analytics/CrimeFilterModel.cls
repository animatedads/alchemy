/* ---------------------------------------------------------------------
   CrimeFilterModel.cls

   Semantic filter definitions and selections for crime-area data.
   The same catalog can drive Web/Swing/GTK/Android/Windows/3D renderers.
   There are no widget or layout instructions in this file.
--------------------------------------------------------------------- */

::class CrimeFilterValue public
::attribute id unguarded
::attribute label unguarded
::attribute sourceCount unguarded
::attribute available unguarded
::attribute metadata unguarded

::method init
  expose id label sourceCount available metadata
  use arg id, label = ""
  if label = "" then label = id
  sourceCount = 0
  available = .true
  metadata = .directory~new
  return


::class CrimeFilterDefinition public
::attribute id unguarded
::attribute label unguarded
::attribute valueKind unguarded          -- ENUM / PERIOD / AREA / BOOLEAN / METRIC
::attribute multiSelect unguarded
::attribute values unguarded
::attribute description unguarded
::attribute appliesTo unguarded          -- array: STREET_CRIME / OUTCOME / STOP_SEARCH / MAP

::method init
  expose id label valueKind multiSelect values description appliesTo
  use arg id, label = "", valueKind = "ENUM", multiSelect = .true
  if label = "" then label = id
  values = .array~new
  description = ""
  appliesTo = .array~new
  return

::method addValue
  expose values
  use arg value
  values~append(value)
  return self

::method addAppliesTo
  expose appliesTo
  use arg layerId
  appliesTo~append(layerId)
  return self


::class CrimeFilterCatalog public
::attribute catalogId unguarded
::attribute sourceRevision unguarded
::attribute definitions unguarded

::method init
  expose catalogId sourceRevision definitions
  use arg catalogId = "crime.filters/0.1"
  sourceRevision = ""
  definitions = .directory~new
  return

::method addDefinition
  expose definitions
  use arg definition
  definitions~put(definition, definition~id)
  return self

::method definition
  expose definitions
  use arg id
  if definitions~hasIndex(id) then return definitions~at(id)
  return .nil

::method ids
  expose definitions
  ids = .array~new
  supplier = definitions~supplier
  do while supplier~available
    ids~append(supplier~index)
    supplier~next
  end
  return ids


::class CrimeFilterSelection public
::attribute selected unguarded           -- filter id -> array of selected ids
::attribute metricKind unguarded
::attribute includeMissingArea unguarded
::attribute includeMissingOutcome unguarded

::method init
  expose selected metricKind includeMissingArea includeMissingOutcome
  selected = .directory~new
  metricKind = "COUNT"
  includeMissingArea = .false
  includeMissingOutcome = .true
  return

::method setValues
  expose selected
  use arg filterId, values
  selected~put(values, filterId)
  return self

::method valuesFor
  expose selected
  use arg filterId
  if selected~hasIndex(filterId) then return selected~at(filterId)
  return .array~new

::method hasSelections
  expose selected
  use arg filterId
  if selected~hasIndex(filterId) = .false then return .false
  values = selected~at(filterId)
  return values~items > 0

::method includes
  use arg filterId, value
  values = self~valuesFor(filterId)
  if values~items = 0 then return .true
  do candidate over values
    if candidate = value then return .true
  end
  return .false

::method fingerprint
  expose selected metricKind includeMissingArea includeMissingOutcome
  /* Stable enough for semantic frame identity when callers add filters
     in canonical catalog order.  Crypto can replace this textual form. */
  text = "metric="metricKind";missingArea="includeMissingArea";missingOutcome="includeMissingOutcome
  supplier = selected~supplier
  do while supplier~available
    key = supplier~index
    values = supplier~item
    text = text";"key"="
    first = .true
    do value over values
      if first then first = .false
      else text = text"," 
      text = text || value
    end
    supplier~next
  end
  return text


::class CrimeFilterMatcher public

::method matchesStreetCrime class
  use arg observation, selection
  if selection~includes("period", observation~period~key) = .false then return .false
  if selection~includes("crimeType", observation~crimeType) = .false then return .false
  if selection~includes("lastOutcome", observation~lastOutcomeCategory) = .false then return .false
  if selection~includes("reportedBy", observation~reportedBy) = .false then return .false
  if selection~includes("fallsWithin", observation~fallsWithin) = .false then return .false
  if selection~includes("lsoa", observation~lsoaCode) = .false then return .false
  if observation~lsoaCode = "" then if selection~includeMissingArea = .false then return .false
  if observation~lastOutcomeCategory = "" then if selection~includeMissingOutcome = .false then return .false
  return .true


/* Stable semantic filter set for the public-data application.  Source
   inventory code can add/replace values without changing UI renderers. */
::class PoliceUKCrimeFilterDefinitions public

::method buildBaseCatalog class
  catalog = .CrimeFilterCatalog~new("police.uk.crime.filters/0.1")

  dataLayer = .CrimeFilterDefinition~new("dataLayer", "Data layer", "ENUM", .false)
  dataLayer~description = "Choose observations that have distinct source semantics."
  dataLayer~addValue(.CrimeFilterValue~new("STREET_CRIME", "Recorded street crime"))
  dataLayer~addValue(.CrimeFilterValue~new("OUTCOME", "Crime outcomes"))
  dataLayer~addValue(.CrimeFilterValue~new("STOP_SEARCH", "Stop and search"))
  catalog~addDefinition(dataLayer)

  period = .CrimeFilterDefinition~new("period", "Period", "PERIOD", .true)
  period~addAppliesTo("STREET_CRIME")~addAppliesTo("OUTCOME")~addAppliesTo("STOP_SEARCH")
  catalog~addDefinition(period)

  crimeType = .CrimeFilterDefinition~new("crimeType", "Crime type", "ENUM", .true)
  crimeType~addAppliesTo("STREET_CRIME")~addAppliesTo("MAP")
  catalog~addDefinition(crimeType)

  lastOutcome = .CrimeFilterDefinition~new("lastOutcome", "Last published outcome", "ENUM", .true)
  lastOutcome~addAppliesTo("STREET_CRIME")
  catalog~addDefinition(lastOutcome)

  outcomeType = .CrimeFilterDefinition~new("outcomeType", "Outcome event", "ENUM", .true)
  outcomeType~addAppliesTo("OUTCOME")
  catalog~addDefinition(outcomeType)

  reportedBy = .CrimeFilterDefinition~new("reportedBy", "Reported by", "ENUM", .true)
  reportedBy~addAppliesTo("STREET_CRIME")~addAppliesTo("OUTCOME")
  catalog~addDefinition(reportedBy)

  fallsWithin = .CrimeFilterDefinition~new("fallsWithin", "Falls within", "ENUM", .true)
  fallsWithin~addAppliesTo("STREET_CRIME")~addAppliesTo("OUTCOME")
  catalog~addDefinition(fallsWithin)

  lsoa = .CrimeFilterDefinition~new("lsoa", "LSOA 2021", "AREA", .true)
  lsoa~addAppliesTo("STREET_CRIME")~addAppliesTo("OUTCOME")~addAppliesTo("MAP")
  catalog~addDefinition(lsoa)

  metric = .CrimeFilterDefinition~new("metric", "Map metric", "METRIC", .false)
  metric~description = "COUNT is source count. RATE and DENSITY require an explicit denominator."
  metric~addValue(.CrimeFilterValue~new("COUNT", "Published count"))
  metric~addValue(.CrimeFilterValue~new("RATE", "Rate"))
  metric~addValue(.CrimeFilterValue~new("DENSITY", "Spatial density"))
  metric~addValue(.CrimeFilterValue~new("CHANGE", "Change"))
  metric~addValue(.CrimeFilterValue~new("HOTSPOT_SCORE", "Hotspot score"))
  metric~addAppliesTo("MAP")
  catalog~addDefinition(metric)

  trend = .CrimeFilterDefinition~new("trendDirection", "Trend", "ENUM", .true)
  trend~addValue(.CrimeFilterValue~new("RISING", "Rising"))
  trend~addValue(.CrimeFilterValue~new("FALLING", "Falling"))
  trend~addValue(.CrimeFilterValue~new("STABLE", "Stable"))
  trend~addValue(.CrimeFilterValue~new("VOLATILE", "Volatile"))
  trend~addValue(.CrimeFilterValue~new("NEW_ACTIVITY", "New activity"))
  trend~addValue(.CrimeFilterValue~new("INSUFFICIENT", "Insufficient history"))
  trend~addAppliesTo("MAP")
  catalog~addDefinition(trend)

  hotspot = .CrimeFilterDefinition~new("hotspotBand", "Hotspot intensity", "ENUM", .true)
  hotspot~addValue(.CrimeFilterValue~new("LOW", "Low"))
  hotspot~addValue(.CrimeFilterValue~new("TYPICAL", "Typical"))
  hotspot~addValue(.CrimeFilterValue~new("ELEVATED", "Elevated"))
  hotspot~addValue(.CrimeFilterValue~new("HIGH", "High"))
  hotspot~addValue(.CrimeFilterValue~new("EXTREME", "Extreme"))
  hotspot~addAppliesTo("MAP")
  catalog~addDefinition(hotspot)

  stopType = .CrimeFilterDefinition~new("stopType", "Search type", "ENUM", .true)
  stopType~addAppliesTo("STOP_SEARCH")
  catalog~addDefinition(stopType)

  stopObject = .CrimeFilterDefinition~new("stopObject", "Object of search", "ENUM", .true)
  stopObject~addAppliesTo("STOP_SEARCH")
  catalog~addDefinition(stopObject)

  stopOutcome = .CrimeFilterDefinition~new("stopOutcome", "Stop/search outcome", "ENUM", .true)
  stopOutcome~addAppliesTo("STOP_SEARCH")
  catalog~addDefinition(stopOutcome)

  stopAge = .CrimeFilterDefinition~new("stopAge", "Age range", "ENUM", .true)
  stopAge~addAppliesTo("STOP_SEARCH")
  catalog~addDefinition(stopAge)

  stopGender = .CrimeFilterDefinition~new("stopGender", "Gender", "ENUM", .true)
  stopGender~addAppliesTo("STOP_SEARCH")
  catalog~addDefinition(stopGender)

  stopEthnicity = .CrimeFilterDefinition~new("stopOfficerDefinedEthnicity", "Officer-defined ethnicity", "ENUM", .true)
  stopEthnicity~addAppliesTo("STOP_SEARCH")
  catalog~addDefinition(stopEthnicity)

  return catalog
