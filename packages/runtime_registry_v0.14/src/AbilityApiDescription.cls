/* Ability API Description v0.2
 *
 * Profile-scoped machine-readable API description for Ability HTTP.
 * The description is generated from the immutable AbilitySession/Profile that
 * the request is actually executing against.  It never asks RuntimeRegistry
 * for "current" modules and never invokes dynamic capability code.
 *
 * v0.2 publishes the immutable input/output schemas carried by each
 * AbilityDescriptor.  Dedicated and custom ability paths are generated from
 * those exact schemas; no transport-owned schema widening is performed.
 */

::class AbilityApiDescriptionBuild public
::constant PRODUCT "ooRexx Ability API Description"
::constant RELEASE "0.2"
::constant OPENAPI_VERSION "3.2.0"

::class AbilityOpenApiDescription public

::method etagForSession class
  use arg session
  token = session~clientId || ":" || session~profileId || ":" || session~revision || ":" || session~generationId
  return '"' || token || '"'

::method forSession class
  use arg session
  profile = session~profile
  document = .directory~new
  document["openapi"] = .AbilityApiDescriptionBuild~OPENAPI_VERSION

  info = .directory~new
  info["title"] = "ooRexx Ability API"
  info["version"] = session~revision
  info["description"] = "Profile-scoped API contract for the authenticated ability generation."
  document["info"] = info

  servers = .array~new
  server = .directory~new
  server["url"] = "/"
  servers~append(server)
  document["servers"] = servers

  document["security"] = .array~of(self~bearerRequirement)
  document["paths"] = self~pathsFor(session)
  document["components"] = self~components
  document["x-oorexx-profile"] = self~profileExtension(session)
  document["x-oorexx-abilities"] = self~abilityExtension(profile)
  document["x-oorexx-resources"] = self~resourceExtension(session)
  document["x-oorexx-rules"] = self~ruleExtension(session)
  return document

::method pathsFor private class
  use arg session
  profile = session~profile
  paths = .directory~new

  paths["/v1/health"] = self~singleOperation("get", "health", "Service health", .false, .false)
  paths["/v1/openapi.json"] = self~openApiPath
  paths["/v1/abilities"] = self~singleOperation("get", "listAbilities", "List granted abilities", .true, .false)
  paths["/v1/resources"] = self~singleOperation("get", "listResources", "List granted data resources", .true, .false)
  paths["/v1/rules"] = self~singleOperation("get", "listRules", "List granted rule bindings", .true, .false)

  queryDescriptor = profile~ability("query")
  if queryDescriptor \== .nil then do
    paths["/v1/queries"] = self~abilityCreatePath(queryDescriptor, "createQuery", "Create one materialised query result", .true)
    paths["/v1/queries/{id}"] = self~materializedItemPath("query")
    paths["/v1/queries/{id}/rows"] = self~queryRowsPath
  end
  evaluationDescriptor = profile~ability("evaluate")
  if evaluationDescriptor \== .nil then do
    paths["/v1/evaluations"] = self~abilityCreatePath(evaluationDescriptor, "createEvaluation", "Create one materialised rule evaluation", .true)
    paths["/v1/evaluations/{id}"] = self~materializedItemPath("evaluation")
    paths["/v1/evaluations/{id}/evidence"] = self~evaluationEvidencePath
  end

  ids = profile~abilityIds
  do i = 1 to ids~items
    abilityId = ids~at(i)
    if abilityId = "query" then iterate
    if abilityId = "evaluate" then iterate
    descriptor = profile~ability(abilityId)
    paths["/v1/abilities/" || abilityId] = self~abilityCreatePath(descriptor, "invoke_" || self~operationToken(abilityId), "Invoke granted ability " || abilityId, .false)
  end

  paths["/v1/evidence/{evidenceId}"] = self~evidencePath
  return paths

::method openApiPath private class
  pathItem = .directory~new
  op = self~operation("openapi", "Profile-scoped OpenAPI description", .true)
  headerParameter = .directory~new
  headerParameter["name"] = "If-None-Match"
  headerParameter["in"] = "header"
  headerParameter["required"] = .JSONBoolean~false
  schema = .directory~new; schema["type"] = "string"; headerParameter["schema"] = schema
  op["parameters"] = .array~of(headerParameter)
  responses = self~standardResponses(.false)
  notModified = .directory~new; notModified["description"] = "Profile contract unchanged for the supplied ETag"
  responses["304"] = notModified
  op["responses"] = responses
  pathItem["get"] = op
  return pathItem

::method singleOperation private class
  use arg method, operationId, summary, requiresAuth = .true, hasBody = .false
  pathItem = .directory~new
  op = self~operation(operationId, summary, requiresAuth)
  if hasBody then op["requestBody"] = self~jsonObjectRequestBody
  if method = "post" then op["responses"] = self~standardResponses(.true)
  else op["responses"] = self~standardResponses(.false)
  pathItem[method] = op
  return pathItem

::method operation private class
  use arg operationId, summary, requiresAuth = .true
  op = .directory~new
  op["operationId"] = operationId
  op["summary"] = summary
  if \requiresAuth then op["security"] = .array~new
  return op

::method abilityCreatePath private class
  use arg descriptor, operationId, summary, materialized = .false
  pathItem = .directory~new
  op = self~operation(operationId, summary, .true)
  op["x-oorexx-ability-id"] = descriptor~abilityId
  op["x-oorexx-output-schema"] = descriptor~outputSchema~document
  op["requestBody"] = self~schemaRequestBody(descriptor~inputSchema~document)
  if materialized then op["responses"] = self~abilityResponses(.true, descriptor~outputSchema~document)
  else op["responses"] = self~abilityResponses(.false, descriptor~outputSchema~document)
  pathItem["post"] = op
  return pathItem

::method operationToken private class
  use arg abilityId
  token = abilityId~string
  token = token~changestr(".", "_")
  token = token~changestr("-", "_")
  return token

::method materializedItemPath private class
  use arg kind
  pathItem = .directory~new
  getOp = self~operation("get" || kind~upper || "Result", "Read materialised " || kind || " metadata", .true)
  getOp["parameters"] = .array~of(self~idParameter("id"))
  getOp["responses"] = self~standardResponses(.false)
  deleteOp = self~operation("delete" || kind~upper || "Result", "Release materialised " || kind, .true)
  deleteOp["parameters"] = .array~of(self~idParameter("id"))
  deleteOp["responses"] = self~standardResponses(.false)
  pathItem["get"] = getOp
  pathItem["delete"] = deleteOp
  return pathItem

::method queryRowsPath private class
  pathItem = .directory~new
  op = self~operation("pageQueryRows", "Page a materialised query without re-executing it", .true)
  parameters = .array~new
  parameters~append(self~idParameter("id"))
  cursor = .directory~new; cursor["name"] = "cursor"; cursor["in"] = "query"; cursor["required"] = .JSONBoolean~false
  cursorSchema = .directory~new; cursorSchema["type"] = "string"; cursorSchema["pattern"] = "^c\\.[0-9]+$"; cursor["schema"] = cursorSchema
  parameters~append(cursor)
  limit = .directory~new; limit["name"] = "limit"; limit["in"] = "query"; limit["required"] = .JSONBoolean~false
  limitSchema = .directory~new; limitSchema["type"] = "integer"; limitSchema["minimum"] = 1; limitSchema["maximum"] = 200; limit["schema"] = limitSchema
  parameters~append(limit)
  op["parameters"] = parameters
  op["responses"] = self~standardResponses(.false)
  pathItem["get"] = op
  return pathItem

::method evaluationEvidencePath private class
  pathItem = .directory~new
  op = self~operation("getEvaluationEvidence", "List evidence attached to a materialised evaluation", .true)
  op["parameters"] = .array~of(self~idParameter("id"))
  op["responses"] = self~standardResponses(.false)
  pathItem["get"] = op
  return pathItem

::method evidencePath private class
  pathItem = .directory~new
  op = self~operation("getEvidence", "Dereference evidence owned by this client", .true)
  op["parameters"] = .array~of(self~idParameter("evidenceId"))
  op["responses"] = self~standardResponses(.false)
  pathItem["get"] = op
  return pathItem

::method idParameter private class
  use arg name
  p = .directory~new
  p["name"] = name
  p["in"] = "path"
  p["required"] = .JSONBoolean~true
  schema = .directory~new; schema["type"] = "string"; schema["minLength"] = 1
  p["schema"] = schema
  return p

::method jsonObjectRequestBody private class
  schema = .directory~new
  schema["type"] = "object"
  schema["additionalProperties"] = .JSONBoolean~true
  return self~schemaRequestBody(schema)

::method schemaRequestBody private class
  use arg schema
  body = .directory~new
  body["required"] = .JSONBoolean~true
  content = .directory~new
  media = .directory~new
  media["schema"] = schema
  content["application/json"] = media
  body["content"] = content
  return body

::method abilityResponses private class
  use arg created, outputSchema
  responses = self~standardResponses(created)
  if created then code = "201"
  else code = "200"
  if created then description = "Created"
  else description = "OK"
  responses[code] = self~abilityResponse(description, outputSchema, created)
  responses["415"] = self~problemResponse("Unsupported media type")
  responses["422"] = self~problemResponse("Schema or ability validation failed")
  responses["429"] = self~problemResponse("Work Load Unit admission or delivery capacity denied")
  responses["500"] = self~problemResponse("Ability contract violation")
  return responses

::method abilityResponse private class
  use arg description, outputSchema, materialized
  d = .directory~new
  d["description"] = description
  content = .directory~new
  media = .directory~new
  envelope = .directory~new
  envelope["type"] = "object"
  properties = .directory~new
  properties["result"] = outputSchema
  envelope["properties"] = properties
  if materialized then envelope["required"] = .array~of("id", "result")
  else envelope["required"] = .array~of("ability", "result")
  envelope["additionalProperties"] = .JSONBoolean~true
  media["schema"] = envelope
  content["application/json"] = media
  d["content"] = content
  return d

::method standardResponses private class
  use arg created = .false
  responses = .directory~new
  if created then responses["201"] = self~response("Created")
  else responses["200"] = self~response("OK")
  responses["400"] = self~problemResponse("Bad request")
  responses["401"] = self~problemResponse("Unauthorized")
  responses["403"] = self~problemResponse("Forbidden")
  responses["404"] = self~problemResponse("Not found")
  return responses

::method response private class
  use arg description
  d = .directory~new
  d["description"] = description
  content = .directory~new
  media = .directory~new
  schema = .directory~new
  schema["type"] = "object"
  schema["additionalProperties"] = .JSONBoolean~true
  media["schema"] = schema
  content["application/json"] = media
  d["content"] = content
  return d

::method problemResponse private class
  use arg description
  d = .directory~new
  d["description"] = description
  content = .directory~new
  media = .directory~new
  refSchema = .directory~new
  refSchema["$ref"] = "#/components/schemas/Problem"
  media["schema"] = refSchema
  content["application/problem+json"] = media
  d["content"] = content
  return d

::method bearerRequirement private class
  d = .directory~new
  d["abilityBearer"] = .array~new
  return d

::method components private class
  components = .directory~new
  schemes = .directory~new
  bearer = .directory~new
  bearer["type"] = "http"
  bearer["scheme"] = "bearer"
  bearer["bearerFormat"] = "ab1.<key-id>.<secret>"
  schemes["abilityBearer"] = bearer
  components["securitySchemes"] = schemes

  schemas = .directory~new
  problem = .directory~new
  problem["type"] = "object"
  properties = .directory~new
  do field over .array~of("type", "title", "detail")
    s = .directory~new; s["type"] = "string"; properties[field] = s
  end
  statusSchema = .directory~new; statusSchema["type"] = "integer"; properties["status"] = statusSchema
  problem["properties"] = properties
  problem["required"] = .array~of("type", "title", "status")
  schemas["Problem"] = problem
  components["schemas"] = schemas
  return components

::method profileExtension private class
  use arg session
  d = .directory~new
  d["client_id"] = session~clientId
  d["profile_id"] = session~profileId
  d["profile_revision"] = session~revision
  d["ability_generation"] = session~generationId
  d["environment"] = session~environment
  return d

::method abilityExtension private class
  use arg profile
  items = .array~new
  ids = profile~abilityIds
  do i = 1 to ids~items
    descriptor = profile~ability(ids~at(i))
    item = .directory~new
    item["id"] = descriptor~abilityId
    item["kind"] = descriptor~kind
    item["read_only"] = self~jsonBoolean(descriptor~readOnly)
    item["description"] = descriptor~description
    item["required_aliases"] = descriptor~requiredAliases
    if descriptor~abilityId = "query" then do
      item["invoke_uri"] = "/v1/queries"
      item["result_mode"] = "materialized-query"
    end
    else if descriptor~abilityId = "evaluate" then do
      item["invoke_uri"] = "/v1/evaluations"
      item["result_mode"] = "materialized-evaluation"
    end
    else do
      item["invoke_uri"] = "/v1/abilities/" || descriptor~abilityId
      item["result_mode"] = "inline"
    end
    item["http_method"] = "POST"
    item["input_schema"] = descriptor~inputSchema~document
    item["output_schema"] = descriptor~outputSchema~document
    items~append(item)
  end
  return items

::method resourceExtension private class
  use arg session
  profile = session~profile
  items = .array~new
  names = profile~dataBindingNames
  do i = 1 to names~items
    binding = profile~dataBinding(names~at(i))
    item = .directory~new
    item["name"] = binding~logicalName
    item["resource"] = binding~resourceName
    item["access"] = binding~accessMode
    item["runtime_alias"] = binding~runtimeAlias
    item["runtime_generation"] = session~runtimeGenerationId(binding~runtimeAlias)
    item["runtime_artifact"] = session~runtimeArtifactId(binding~runtimeAlias)
    items~append(item)
  end
  return items

::method ruleExtension private class
  use arg session
  profile = session~profile
  items = .array~new
  names = profile~ruleBindingNames
  do i = 1 to names~items
    binding = profile~ruleBinding(names~at(i))
    item = .directory~new
    item["name"] = binding~logicalName
    item["rule_set"] = binding~ruleSetName
    item["runtime_alias"] = binding~runtimeAlias
    item["runtime_generation"] = session~runtimeGenerationId(binding~runtimeAlias)
    item["runtime_artifact"] = session~runtimeArtifactId(binding~runtimeAlias)
    items~append(item)
  end
  return items

::method jsonBoolean private class
  use arg value
  if value == .true then return .JSONBoolean~true
  return .JSONBoolean~false

::requires "AbilityRegistry.cls"
::requires "json.cls"
