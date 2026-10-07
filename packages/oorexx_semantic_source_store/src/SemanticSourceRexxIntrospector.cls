/*
 * Semantic Source Control - ooRexx runtime class introspector.
 *
 * This service never creates an application class instance.  It consumes an
 * already loaded Package/Class object and records the effective method graph
 * exposed by the ooRexx runtime: declared methods, inherited methods,
 * overrides, shadowed ancestor definitions and immediate inheritance edges.
 *
 * IMPORTANT: loading/creating an ooRexx Package may execute its prolog.  The
 * host must therefore activate untrusted packages in an isolated worker.  This
 * class deliberately does not call .Package~new or instantiate inspected
 * classes.
 */

::class SemanticSourceRexxIntrospector public

::method init
  use strict arg sql = .nil
  self~sql = sql

::attribute sql get
::attribute sql set private

::method inspectPackage
  use strict arg packageObject, runtimeVersion = ""
  if packageObject == .nil then raise syntax 88.900 array("packageObject must not be nil")
  if runtimeVersion = "" then runtimeVersion = .RexxInfo~version

  packageInfo = .directory~new
  packageInfo["package_name"] = packageObject~name
  packageInfo["runtime"] = "ooRexx"
  packageInfo["runtime_version"] = runtimeVersion
  packageInfo["prolog_present"] = (packageObject~prolog <> .nil)
  classes = .array~new

  classTable = packageObject~classes
  supplier = classTable~supplier
  do while supplier~available
    className = supplier~index
    classObject = supplier~item
    classInfo = self~inspectClass(classObject, runtimeVersion)
    classInfo["public"] = packageObject~publicClasses~hasIndex(className)
    classes~append(classInfo)
    supplier~next
  end
  packageInfo["classes"] = classes
  return packageInfo

::method inspectClass
  use strict arg classObject, runtimeVersion = ""
  if classObject == .nil then raise syntax 88.900 array("classObject must not be nil")
  if runtimeVersion = "" then runtimeVersion = .RexxInfo~version

  info = .directory~new
  info["class_id"] = classObject~id
  info["package_name"] = classObject~package~name
  info["runtime"] = "ooRexx"
  info["runtime_version"] = runtimeVersion

  parents = .array~new
  ordinal = 0
  do parent over classObject~superClasses
    ordinal += 1
    p = .directory~new
    p["class_id"] = parent~id
    p["package_name"] = parent~package~name
    p["ordinal"] = ordinal
    parents~append(p)
  end
  info["parents"] = parents

  chain = self~classChain(classObject)
  info["hierarchy"] = self~hierarchySummary(chain)
  info["instance_methods"] = self~methodSurface(classObject, chain, "INSTANCE")
  info["class_methods"] = self~methodSurface(classObject, chain, "CLASS")
  return info

::method classChain private
  use strict arg classObject
  chain = .array~new
  seen = .directory~new
  self~appendClassAndParents(classObject, chain, seen, 0)
  return chain

::method appendClassAndParents private
  use strict arg classObject, chain, seen, depth
  key = self~classKey(classObject)
  if seen~hasIndex(key) then return
  seen[key] = 1
  entry = .directory~new
  entry["class"] = classObject
  entry["depth"] = depth
  chain~append(entry)
  do parent over classObject~superClasses
    self~appendClassAndParents(parent, chain, seen, depth + 1)
  end

::method hierarchySummary private
  use strict arg chain
  summary = .array~new
  do entry over chain
    classObject = entry["class"]
    row = .directory~new
    row["class_id"] = classObject~id
    row["package_name"] = classObject~package~name
    row["depth"] = entry["depth"]
    summary~append(row)
  end
  return summary

::method methodSurface private
  use strict arg targetClass, chain, methodScope
  surface = .array~new
  seenNames = .directory~new
  targetKey = self~classKey(targetClass)

  do entry over chain
    originClass = entry["class"]
    methods = self~localMethods(originClass, methodScope)
    do while methods~available
      methodName = methods~index
      methodObject = methods~item
      row = .directory~new
      row["method_name"] = methodName
      row["method_source_spelling"] = ""
      row["method_runtime_spelling"] = methodName
      row["method_lookup_key"] = methodName~upper
      row["method_scope"] = methodScope
      row["origin_class_id"] = originClass~id
      row["origin_package_name"] = originClass~package~name
      row["depth"] = entry["depth"]
      row["hidden"] = (methodObject == .nil)

      if seenNames~hasIndex(methodName) then do
        row["effective"] = 0
        row["relation_kind"] = "SHADOWED"
      end
      else do
        seenNames[methodName] = self~classKey(originClass)
        row["effective"] = 1
        if self~classKey(originClass) = targetKey then do
          overriddenClass = self~nearestAncestorDefining(chain, methodName, methodScope)
          if overriddenClass == .nil then row["relation_kind"] = "DECLARED"
          else do
            row["relation_kind"] = "OVERRIDES"
            row["overrides_class_id"] = overriddenClass~id
            row["overrides_package_name"] = overriddenClass~package~name
          end
        end
        else row["relation_kind"] = "INHERITED"
      end

      if \row~hasIndex("overrides_class_id") then row["overrides_class_id"] = ""
      if \row~hasIndex("overrides_package_name") then row["overrides_package_name"] = ""
      surface~append(row)
      methods~next
    end
  end
  return surface

::method nearestAncestorDefining private
  use strict arg chain, methodName, methodScope
  first = 1
  do entry over chain
    if first then do
      first = 0
      iterate
    end
    classObject = entry["class"]
    if self~classDefines(classObject, methodName, methodScope) then return classObject
  end
  return .nil

::method classDefines private
  use strict arg classObject, methodName, methodScope
  methods = self~localMethods(classObject, methodScope)
  do while methods~available
    if methods~index = methodName then return 1
    methods~next
  end
  return 0

::method localMethods private
  use strict arg classObject, methodScope
  if methodScope = "INSTANCE" then return classObject~methods(.nil)
  if methodScope = "CLASS" then return classObject~instanceMethods(classObject)
  raise syntax 88.900 array("invalid ooRexx method scope: " || methodScope)

::method classKey private
  use strict arg classObject
  return classObject~package~name || "::" || classObject~id

::method persistClassSnapshot
  use strict arg snapshotId, moduleId, sourceObjectId, sourceRevisionId, classObject, capturedAt = "", capturedBy = "", runtimeVersion = ""
  if self~sql == .nil then raise syntax 88.900 array("SQL authority is required to persist runtime introspection")
  if runtimeVersion = "" then runtimeVersion = .RexxInfo~version
  info = self~inspectClass(classObject, runtimeVersion)

  statement = "INSERT INTO ssc_runtime_class_snapshot (snapshot_id,module_id,source_object_id,source_revision_id,package_name,class_id,runtime_name,runtime_version,captured_at,captured_by) VALUES (" ||,
              self~quote(snapshotId) || "," || self~quote(moduleId) || "," || self~quote(sourceObjectId) || "," || self~quote(sourceRevisionId) || "," ||,
              self~quote(info["package_name"]) || "," || self~quote(info["class_id"]) || ",'ooRexx'," || self~quote(runtimeVersion) || "," || self~quote(capturedAt) || "," || self~quote(capturedBy) || ")"
  self~query(statement)

  edgeNo = 0
  do p over info["parents"]
    edgeNo += 1
    edgeId = snapshotId || ":parent:" || edgeNo
    statement = "INSERT INTO ssc_runtime_inheritance_edge (edge_id,snapshot_id,child_class_id,parent_class_id,parent_ordinal,depth) VALUES (" ||,
                self~quote(edgeId) || "," || self~quote(snapshotId) || "," || self~quote(info["class_id"]) || "," || self~quote(p["class_id"]) || "," || p["ordinal"] || ",1)"
    self~query(statement)
  end

  rowNo = 0
  do methodScope over .array~of("instance_methods", "class_methods")
    do m over info[methodScope]
      rowNo += 1
      surfaceId = snapshotId || ":method:" || rowNo
      statement = "INSERT INTO ssc_runtime_method_surface (surface_id,snapshot_id,method_scope,method_name,method_source_spelling,method_runtime_spelling,method_lookup_key,origin_package_name,origin_class_id,relation_kind,is_effective,is_hidden,overrides_package_name,overrides_class_id,depth) VALUES (" ||,
                  self~quote(surfaceId) || "," || self~quote(snapshotId) || "," || self~quote(m["method_scope"]) || "," || self~quote(m["method_name"]) || "," ||,
                  self~quote(m["method_source_spelling"]) || "," || self~quote(m["method_runtime_spelling"]) || "," || self~quote(m["method_lookup_key"]) || "," ||,
                  self~quote(m["origin_package_name"]) || "," || self~quote(m["origin_class_id"]) || "," || self~quote(m["relation_kind"]) || "," ||,
                  m["effective"] || "," || m["hidden"] || "," || self~quote(m["overrides_package_name"]) || "," || self~quote(m["overrides_class_id"]) || "," || m["depth"] || ")"
      self~query(statement)
    end
  end
  return info

::method query private
  use strict arg statement
  dbResult = self~sql~execute(statement)
  if dbResult~status = "SUCCESS" then return dbResult
  raise syntax 88.900 array("Database operation failed: " || statement || "; " || dbResult~message)

::method quote private
  use strict arg value
  if value == .nil then value = ""
  return "'" || value~changestr("'", "''") || "'"

