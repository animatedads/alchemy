/* DocumentationPlanner.cls
   Converts the deterministic source graph into bounded documentation segments.

   A class receives an initial bootstrap/review segment, followed by one segment
   per method.  This is the queue shape intended for the local Gwen worker:
   receive graph slice, document method, reconsider class documentation, continue.
*/

::class DFDocumentationPlanner public
::method build
  use strict arg graph, packageId
  segments = .Array~new
  sequence = 0
  do fileRecord over graph~files
    do classRecord over fileRecord~classes
      sequence += 1
      if classRecord~documentation = "" then action = "CLASS_BOOTSTRAP"
      else action = "CLASS_REVIEW"
      segments~append(self~segment(sequence, packageId, classRecord, .nil, action))
      do methodRecord over classRecord~methods
        sequence += 1
        segments~append(self~segment(sequence, packageId, classRecord, methodRecord, "METHOD_REVIEW"))
      end
    end
  end
  return segments
::method writeJson
  use strict arg graph, packageId, path
  root = .Directory~new
  root["schema"] = "development.floor.documentation-queue/0.1"
  root["package"] = packageId
  root["segments"] = self~build(graph, packageId)
  call lineout path, .json~toJson(root)
  call lineout path
  return path
::method segment private
  use strict arg sequence, packageId, classRecord, methodRecord, action
  d = .Directory~new
  d["id"] = "DOC-" || sequence~format(5,0)
  d["package"] = packageId
  d["file"] = classRecord~file
  d["class"] = classRecord~name
  d["classDocumentation"] = classRecord~documentation
  d["action"] = action
  d["state"] = "PENDING"
  if methodRecord == .nil then do
    d["method"] = ""
    d["methodDocumentation"] = ""
    d["line"] = classRecord~lineNumber
  end
  else do
    d["method"] = methodRecord~name
    d["methodDocumentation"] = methodRecord~documentation
    d["line"] = methodRecord~lineNumber
  end
  return d

::requires "json.cls"
::requires "SourceGraph.cls"
