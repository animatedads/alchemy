/* QueueRexxSerialization.cls - mandatory structured-format policy */

::class QueueSerialization public
::constant CSV_SEPARATOR ","
::constant TSV_SEPARATOR '09'x
::method toJson class
  use arg value
  return .JSON~toJSON(value)

::method fromJson class
  use arg text
  return .JSON~fromJSON(text)

::method toJsonFile class
  use arg value, path
  .JSON~toJSONFile(path, value)
  return .true

::method fromJsonFile class
  use arg path
  return .JSON~fromJSONFile(path)

::method toYaml class
  use arg value
  return .Yaml~toYaml(value)

::method toYamlFile class
  use arg value, path
  .Yaml~toYamlFile(value, path)
  return .true

::method fromYamlFile class
  use arg path
  y = .Yaml~new
  return y~parseFile(path)

::method writeCsv class
  use arg path, rows
  return self~writeDelimited(path, rows, self~CSV_SEPARATOR)

::method writeTsv class
  use arg path, rows
  return self~writeDelimited(path, rows, self~TSV_SEPARATOR)

::method writeDelimited class private
  use arg path, rows, delimiter
  out = .CSVStream~new(path)
  out~delimiter = delimiter
  out~open("WRITE REPLACE")
  if out~state \= "READY" then return .false
  do row over rows
    out~csvLineOut(row)
  end
  out~close
  return .true

::requires "json.cls"
::requires "yaml.cls"
::requires "csvStream.cls"
