/*
 * AlgorithmInputRelation.cls
 * Frozen typed relation input for table-fed algorithms.
 */

::class AlgorithmInputRelationConstant public
::constant BAG_UNORDERED 'BAG_UNORDERED'
::constant ORDERED       'ORDERED'

::class AlgorithmInputRowView public
::attribute schema get

::method init
  expose schema storedValues
  use arg schemaArg, sourceValues
  schema = schemaArg
  storedValues = .directory~new
  do column over schema~columns
    if sourceValues~hasIndex(column~name) then storedValues[column~name] = sourceValues[column~name]
  end

::method value
  expose storedValues
  use arg name
  key = name~upper
  if storedValues~hasIndex(key) then return storedValues[key]
  return .nil

::method hasValue
  expose storedValues
  use arg name
  return storedValues~hasIndex(name~upper)

::method canonicalValue private
  use arg column, fieldValue
  if fieldValue == .nil then return 'N'
  typeName = column~typeName~upper
  if typeName == 'BOOLEAN' then do
    if fieldValue == .true then return 'B1'
    return 'B0'
  end
  if typeName == 'RICH_OBJECT' then do
    richText = fieldValue~algorithmCanonicalText
    return 'O' || richText~length || ':' || richText
  end
  textValue = fieldValue~string
  return 'V' || textValue~length || ':' || textValue

::method canonicalText
  expose storedValues
  canonical = ''
  do column over self~schema~columns
    nameText = column~name
    typeText = column~typeName
    fieldValue = .nil
    if storedValues~hasIndex(nameText) then fieldValue = storedValues[nameText]
    encoded = self~canonicalValue(column, fieldValue)
    canonical = canonical || 'C' || nameText~length || ':' || nameText || 'T' || typeText~length || ':' || typeText || encoded
  end
  return canonical

::class AlgorithmInputRelationBuilder public
::attribute schema get
::attribute relationName get
::attribute orderMode get
::attribute errors get

::method init
  expose schema relationName orderMode sourceRows frozen errors
  use arg schemaArg, relationNameArg = '', orderModeArg = .nil
  if orderModeArg == .nil then orderModeArg = .AlgorithmInputRelationConstant~BAG_UNORDERED
  schema = schemaArg
  if relationNameArg == '' then relationNameArg = schema~relationName
  relationName = relationNameArg~upper
  orderMode = orderModeArg~upper
  sourceRows = .array~new
  errors = .array~new
  frozen = .false
  if self~orderMode \= .AlgorithmInputRelationConstant~BAG_UNORDERED then do
    if self~orderMode \= .AlgorithmInputRelationConstant~ORDERED then errors~append('UNKNOWN_ORDER_MODE ' || self~orderMode)
  end

::method addValues
  expose sourceRows frozen errors
  use arg values
  if frozen then do
    errors~append('BUILDER_ALREADY_FROZEN')
    return .false
  end

  validationRow = .AlgorithmRow~new(self~schema)
  do column over self~schema~columns
    if values~hasIndex(column~name) then do
      ok = validationRow~put(column~name, values[column~name])
    end
    else do
      lowerName = column~name~lower
      if values~hasIndex(lowerName) then ok = validationRow~put(column~name, values[lowerName])
    end
  end
  rowErrors = validationRow~validate
  if rowErrors~items > 0 then do
    do rowError over rowErrors
      errors~append(rowError)
    end
    return .false
  end

  copied = .directory~new
  do column over self~schema~columns
    copied[column~name] = validationRow~value(column~name)
  end
  sourceRows~append(.AlgorithmInputRowView~new(self~schema, copied))
  return .true

::method freeze
  expose sourceRows frozen errors
  use arg sourceOid, sourceQuery = '', sourceIdentity = '', consistencyDescriptor = .nil
  if frozen then do
    errors~append('BUILDER_ALREADY_FROZEN')
    return .nil
  end
  if errors~items > 0 then return .nil
  if consistencyDescriptor == .nil then consistencyDescriptor = .AlgorithmInputConsistencyDescriptor~new(.AlgorithmInputConsistencyConstant~FROZEN_OBSERVATION, 1, '', '', .array~of('BUILDER_FROZEN_OBSERVATION'))
  frozen = .true
  return .AlgorithmInputRelationSnapshot~new(self~schema, self~relationName, sourceRows, self~orderMode, sourceOid, sourceQuery, sourceIdentity, consistencyDescriptor)

::class AlgorithmInputRelationSnapshot public
::attribute schema get
::attribute relationName get
::attribute orderMode get
::attribute sourceOid get
::attribute sourceQueryHash get
::attribute sourceIdentity get
::attribute contentHash get
::attribute consistency get
::attribute consistencyGrade get
::attribute consistencyHash get

::method init
  expose schema relationName orderMode sourceOid sourceQueryHash sourceIdentity contentHash consistency consistencyGrade consistencyHash frozenRows canonicalTextValue algorithmCanonicalTextValue
  use arg schemaArg, relationNameArg, sourceRows, orderModeArg, sourceOidArg, sourceQuery = '', sourceIdentityArg = '', consistencyArg = .nil
  schema = schemaArg
  relationName = relationNameArg~upper
  orderMode = orderModeArg~upper
  sourceOid = sourceOidArg
  sourceQueryHash = .AlgorithmDigest~sha256Text(sourceQuery)
  sourceIdentity = sourceIdentityArg
  if consistencyArg == .nil then consistencyArg = .AlgorithmInputConsistencyDescriptor~new(.AlgorithmInputConsistencyConstant~FROZEN_OBSERVATION, 1, '', '', .array~of('DEFAULT_FROZEN_OBSERVATION'))
  consistency = consistencyArg
  consistencyGrade = consistency~grade
  consistencyHash = consistency~hash
  frozenRows = self~canonicalizeRows(sourceRows)
  canonicalTextValue = self~buildCanonicalText(frozenRows)
  contentHash = .AlgorithmDigest~sha256Text(canonicalTextValue)
  algorithmCanonicalTextValue = canonicalTextValue || 'CONSISTENCY_HASH=' || consistencyHash || '0a'x || consistency~canonicalText
  if sourceOid == '' then sourceOid = 'ALGREL-INPUT:' || contentHash

::method canonicalizeRows private
  use arg sourceRows
  if self~orderMode == .AlgorithmInputRelationConstant~ORDERED then do
    ordered = .array~new
    do sourceRow over sourceRows
      ordered~append(sourceRow)
    end
    return ordered
  end

  buckets = .directory~new
  keys = .array~new
  do sourceRow over sourceRows
    rowKey = sourceRow~canonicalText
    if buckets~hasIndex(rowKey) then bucket = buckets[rowKey]
    else do
      bucket = .array~new
      buckets[rowKey] = bucket
      keys~append(rowKey)
    end
    bucket~append(sourceRow)
  end
  keys~sort
  ordered = .array~new
  do rowKey over keys
    bucket = buckets[rowKey]
    do sourceRow over bucket
      ordered~append(sourceRow)
    end
  end
  return ordered

::method buildCanonicalText private
  use arg rows
  canonical = 'ALGREL_INPUT_RELATION_V1' || '0a'x
  canonical = canonical || 'RELATION=' || self~relationName || '0a'x
  canonical = canonical || 'ORDER_MODE=' || self~orderMode || '0a'x
  canonical = canonical || 'SCHEMA=' || '0a'x
  do column over self~schema~columns
    rendered = column~render
    canonical = canonical || rendered~length || ':' || rendered || '0a'x
  end
  canonical = canonical || 'ROWS=' || rows~items || '0a'x
  rowOrdinal = 0
  do sourceRow over rows
    rowOrdinal = rowOrdinal + 1
    rowText = sourceRow~canonicalText
    canonical = canonical || 'R' || rowOrdinal || '=' || rowText~length || ':' || rowText || '0a'x
  end
  return canonical

::method rows
  expose frozenRows
  copied = .array~new
  do sourceRow over frozenRows
    copied~append(sourceRow)
  end
  return copied

::method rowCount
  expose frozenRows
  return frozenRows~items

::method canonicalText
  expose canonicalTextValue
  return canonicalTextValue

::method algorithmCanonicalText
  expose algorithmCanonicalTextValue
  return algorithmCanonicalTextValue

::method meetsConsistency
  use arg requiredGrade
  return self~consistency~satisfies(requiredGrade)

::method provenanceText
  text = 'SOURCE_OID=' || self~sourceOid || '0a'x
  text = text || 'SOURCE_QUERY_HASH=' || self~sourceQueryHash || '0a'x
  text = text || 'SOURCE_IDENTITY=' || self~sourceIdentity || '0a'x
  text = text || 'CONTENT_HASH=' || self~contentHash || '0a'x
  text = text || 'CONSISTENCY_GRADE=' || self~consistencyGrade || '0a'x
  text = text || 'CONSISTENCY_HASH=' || self~consistencyHash || '0a'x
  return text

::method render
  expose frozenRows
  lines = .array~new
  lines~append('INPUT_RELATION ' || self~relationName || ' rows=' || frozenRows~items || ' order=' || self~orderMode || ' hash=' || self~contentHash || ' consistency=' || self~consistencyGrade || ' consistency_hash=' || self~consistencyHash)
  do sourceRow over frozenRows
    rowText = ''
    first = .true
    do column over self~schema~columns
      fieldValue = sourceRow~value(column~name)
      if fieldValue == .nil then valueText = '<NULL>'
      else if column~typeName~upper == 'RICH_OBJECT' then do
        if fieldValue~hasMethod('CANONICALIDENTITY') then valueText = '<RICH_OBJECT:' || fieldValue~canonicalIdentity || '>'
        else valueText = '<RICH_OBJECT>'
      end
      else valueText = fieldValue
      if first then do
        rowText = column~name || '=' || valueText
        first = .false
      end
      else rowText = rowText || '|' || column~name || '=' || valueText
    end
    lines~append('  ' || rowText)
  end
  return lines

::requires 'AlgorithmRelation.cls'
::requires 'RichEvidence.cls'
::requires 'AlgorithmIntegrity.cls'
::requires 'AlgorithmInputConsistency.cls'
