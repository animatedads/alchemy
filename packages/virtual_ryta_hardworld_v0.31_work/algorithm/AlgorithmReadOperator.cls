/*
 * AlgorithmReadOperator.cls
 * Read-only planner-facing operator for Algorithm Relation v0.4.
 * All projection/filter/LIMIT work is deliberately post-materialization.
 * No provider pushdown interface exists in v0.4.
 */

::class AlgorithmRelationPredicate public
::attribute columnName
::attribute operatorName
::attribute expectedValue

::method init
  use arg columnName, operatorName = 'EQ', expectedValue = .nil
  self~columnName = columnName~upper
  self~operatorName = operatorName~upper
  self~expectedValue = expectedValue

::method matches
  use arg row
  select
    when self~operatorName == 'EQ' then return row~value(self~columnName) == self~expectedValue
    otherwise return .false
  end


::class AlgorithmRelationReadPlan public
::attribute algorithmId
::attribute relationName
::attribute projections get
::attribute predicates get
::attribute rowLimit

::method init
  expose projections predicates
  use arg algorithmId, relationName
  self~algorithmId = algorithmId~upper
  self~relationName = relationName~upper
  projections = .array~new
  predicates = .array~new
  self~rowLimit = 0

::method project
  expose projections
  use arg columnName
  projections~append(columnName~upper)
  return self

::method whereEqual
  expose predicates
  use arg columnName, expectedValue
  predicates~append(.AlgorithmRelationPredicate~new(columnName, 'EQ', expectedValue))
  return self

::method limit
  use arg rowLimit
  self~rowLimit = rowLimit
  return self


::class AlgorithmRelationReadOperator public
::attribute engine
::attribute lastError

::method init
  use arg engine
  self~engine = engine
  self~lastError = ''

::method describe
  use arg plan
  self~lastError = ''
  providerObject = self~engine~provider(plan~algorithmId)
  if providerObject == .nil then do
    self~lastError = 'UNKNOWN_ALGORITHM ' || plan~algorithmId
    return .nil
  end
  if providerObject~sideEffectClass \== 'NONE' then do
    self~lastError = 'READ_PATH_SIDE_EFFECT_CLASS ' || providerObject~sideEffectClass
    return .nil
  end

  if providerObject~sourceManifestMode \== 'FILE_HASHED' then do
    self~lastError = 'READ_PATH_UNVERIFIED_SOURCE_MANIFEST ' || providerObject~sourceManifestMode
    return .nil
  end
  if providerObject~determinism \== .AlgorithmRelationConstant~DETERMINISTIC_GIVEN_MATERIALIZED_INPUT then do
    self~lastError = 'READ_PATH_UNVERIFIED_DETERMINISM ' || providerObject~determinism
    return .nil
  end

  sourceSchema = self~findSchema(providerObject~declaredSchemas, plan~relationName)
  if sourceSchema == .nil then do
    self~lastError = 'UNKNOWN_RELATION ' || plan~relationName
    return .nil
  end

  return self~projectedSchema(sourceSchema, plan)

::method explain
  use arg plan
  lines = .array~new
  describedSchema = self~describe(plan)
  if describedSchema == .nil then do
    lines~append('ERROR ' || self~lastError)
    return lines
  end
  lines~append('ALGORITHM_READ algorithm=' || plan~algorithmId || ' relation=' || plan~relationName)
  lines~append('EXECUTION_BOUNDARY=MATERIALIZE_PROVIDER')
  lines~append('PREDICATE_PHASE=POST_MATERIALIZATION')
  lines~append('PROJECTION_PHASE=POST_MATERIALIZATION')
  lines~append('LIMIT_PHASE=POST_MATERIALIZATION')
  lines~append('PROVIDER_PUSHDOWN=NONE_V0.4')
  return lines

::method execute
  use arg plan, inputObject, context
  self~lastError = ''
  outputSchema = self~describe(plan)
  if outputSchema == .nil then return .nil

  providerObject = self~engine~provider(plan~algorithmId)
  algorithmResult = self~engine~execute(plan~algorithmId, inputObject, context)
  if algorithmResult == .nil then do
    self~lastError = 'ALGORITHM_EXECUTION_FAILED'
    return .nil
  end
  if algorithmResult~validationErrors~items > 0 then do
    self~lastError = 'INVALID_ALGORITHM_RESULT'
    return .nil
  end

  sourceRelation = algorithmResult~relation(plan~relationName)
  if sourceRelation == .nil then do
    self~lastError = 'RESULT_MISSING_RELATION ' || plan~relationName
    return .nil
  end

  outputRelation = .AlgorithmRelation~new(outputSchema)
  outputCount = 0
  do sourceRow over sourceRelation~rows
    if \self~matchesAll(plan~predicates, sourceRow, sourceRelation~schema) then iterate

    outputRow = outputRelation~newRow
    do column over outputSchema~columns
      ok = outputRow~put(column~name, sourceRow~value(column~name))
    end
    added = outputRelation~addRow(outputRow)
    if added then outputCount = outputCount + 1

    if plan~rowLimit > 0 then do
      if outputCount >= plan~rowLimit then leave
    end
  end
  return outputRelation

::method matchesAll private
  use arg predicates, row, sourceSchema
  do predicate over predicates
    if \sourceSchema~hasColumn(predicate~columnName) then do
      self~lastError = 'UNKNOWN_FILTER_COLUMN ' || predicate~columnName
      return .false
    end
    if \predicate~matches(row) then return .false
  end
  return .true

::method findSchema private
  use arg schemas, relationName
  relationKey = relationName~upper
  do schema over schemas
    if schema~relationName == relationKey then return schema
  end
  return .nil

::method projectedSchema private
  use arg sourceSchema, plan
  outputSchema = .AlgorithmSchema~new(sourceSchema~relationName)

  if plan~projections~items == 0 then do
    do column over sourceSchema~columns
      added = outputSchema~addColumn(column)
    end
    return outputSchema
  end

  do columnName over plan~projections
    sourceColumn = sourceSchema~column(columnName)
    if sourceColumn == .nil then do
      self~lastError = 'UNKNOWN_PROJECTION_COLUMN ' || columnName
      return .nil
    end
    added = outputSchema~addColumn(sourceColumn)
  end
  return outputSchema

::requires 'AlgorithmRelation.cls'
