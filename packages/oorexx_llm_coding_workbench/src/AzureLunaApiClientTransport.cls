/* Azure GPT-6 Luna transport using the existing ooRexx API Client authority.
 * Development Desk buttons are exposed as strict Responses function tools.
 * No curl, urllib or private socket/TLS implementation lives here.
 */
::class AzureLunaApiClientTransport public
::attribute requestCount get

::method init
  expose client endpoint deployment apiKey requestCount requestClass maxOutputTokens reasoningEffort
  use strict arg clientArg,endpointArg,deploymentArg,apiKeyArg,requestClassArg=.nil,maxOutputTokensArg=8192,reasoningEffortArg="low"
  if clientArg==.nil then raise syntax 88.900 array("API Client object is required")
  client=clientArg
  endpoint=endpointArg~string~strip("T","/")
  deployment=deploymentArg~string
  apiKey=apiKeyArg~string
  requestCount=0
  requestClass=requestClassArg
  if requestClass==.nil then requestClass=.environment~at("APIREQUEST")
  maxOutputTokens=maxOutputTokensArg
  reasoningEffort=reasoningEffortArg~string

::method invokeTurn
  use strict arg turn,boundary=.nil
  if boundary==.nil then boundary=.LlmCodingBoundaryAdapter~new
  return self~invoke(boundary~turnDirectory(turn))

::method invoke
  expose client endpoint deployment apiKey requestCount requestClass maxOutputTokens reasoningEffort
  use strict arg turnDirectory
  requestCount+=1
  if requestClass==.nil then raise syntax 88.900 array("ApiRequest public class is not loaded; load oorexx_api_client_v0.4.1 before live Luna use")

  headers=.directory~new
  headers["Content-Type"]="application/json"
  headers["api-key"]=apiKey
  headers["User-Agent"]="ooRexx-LLM-Coding-Workbench/0.1-dev13"

  systemText="You are operating a semantic coding workbench. You do not know ooRexx syntax or APIs and must not invent them. Treat the supplied JSON coding turn as structured state, not prose. Press exactly one supplied function tool per turn. Never return or replace a whole source file. Prefer semantic CODING_* tools. Use semantic_context.hints as advisory evidence, never authority. Treat Intention Service evidence authority/confidence separately: observed runtime evidence and language contracts determine whether an operation is feasible. Inspect the supplied Coding Intention dev13 skill/operation catalogue and evidence-backed object/result lineage, then use CODING_OPERATION only for operations marked renderable. If an operation returns EVIDENCE_CLARIFY, wait for evidence rather than guessing a type, shape, method, or ooRexx spelling. Use CODING_APPLY_METHOD to let the deterministic renderer write ooRexx. Raw WRITE_METHOD is an escape hatch only when the semantic vocabulary cannot express the change; do not use remembered ooRexx syntax as authority. Wait for the next turn after one tool call. Use REPORT only when verification evidence supports completion."
  input=.array~new
  sys=.directory~new; sys["role"]="system"
  sysContent=.array~new; sysPart=.directory~new; sysPart["type"]="input_text"; sysPart["text"]=systemText; sysContent~append(sysPart); sys["content"]=sysContent
  input~append(sys)
  usr=.directory~new; usr["role"]="user"
  usrContent=.array~new; usrPart=.directory~new; usrPart["type"]="input_text"; usrPart["text"]=.json~toJson(turnDirectory); usrContent~append(usrPart); usr["content"]=usrContent
  input~append(usr)

  payload=.directory~new
  payload["model"]=deployment
  payload["input"]=input
  payload["max_output_tokens"]=maxOutputTokens
  reasoning=.directory~new; reasoning["effort"]=reasoningEffort; reasoning["summary"]="concise"; payload["reasoning"]=reasoning
  payload["tools"]=self~tools
  payload["tool_choice"]="required"
  payload["parallel_tool_calls"]=.false
  payload["max_tool_calls"]=1
  payload["store"]=.false

  metadata=.directory~new
  metadata["component"]="llm.coding.workbench"
  metadata["provider"]="azure-luna"
  metadata["schema"]="oorexx.llm-coding.turn/0.2"
  id="llm-code-"||requestCount||"-"||date("S")||"-"||time("S")
  request=requestClass~new(id,"POST",endpoint||"/openai/v1/responses",headers,.json~toJson(payload),"API_CONTROL",50,2000000,2000000,"",metadata,.nil,"")
  response=client~execute(request)
  if response~status<200 | response~status>=300 then -
    raise syntax 88.900 array("Luna API request failed status="||response~status||" transport="||response~errorCode)
  return self~toolDecision(response~body)

::method tools private
  out=.array~new
  out~append(self~tool("LIST_CLASSES","Inspect classes in the current semantic package.",.directory~new,.array~new))
  out~append(self~tool("VIEW_CLASS","Inspect one class semantic object.",self~properties(.array~of("class_name")),.array~of("class_name")))
  out~append(self~tool("VIEW_METHOD","Inspect one method semantic object and current projection.",self~properties(.array~of("class_name","method_name")),.array~of("class_name","method_name")))
  out~append(self~tool("VIEW_ATTRIBUTE","Inspect one attribute semantic object.",self~properties(.array~of("class_name","attribute_name")),.array~of("class_name","attribute_name")))
  out~append(self~tool("CREATE_CLASS","Create one class semantic object.",self~properties(.array~of("class_name","ordinal")),.array~of("class_name","ordinal")))
  out~append(self~tool("ADD_REQUIRES","Add one package-level ooRexx requires semantic object.",self~properties(.array~of("requires_target","ordinal")),.array~of("requires_target","ordinal")))
  out~append(self~tool("ADD_ATTRIBUTE","Add one attribute semantic object.",self~properties(.array~of("class_name","attribute_name","ordinal")),.array~of("class_name","attribute_name","ordinal")))
  out~append(self~tool("ADD_METHOD","Add one method semantic object with an empty body.",self~properties(.array~of("class_name","method_name","ordinal")),.array~of("class_name","method_name","ordinal")))
  out~append(self~tool("CODING_RETURN_IF_ALREADY","Add a semantic conditional guard step. The deterministic renderer writes ooRexx syntax.",self~properties(.array~of("class_name","method_name","attribute_name","condition","return_value")),.array~of("class_name","method_name","attribute_name","condition","return_value")))
  out~append(self~tool("CODING_SET_ATTRIBUTE","Add a semantic state mutation step. The deterministic renderer writes ooRexx syntax.",self~properties(.array~of("class_name","method_name","attribute_name","value")),.array~of("class_name","method_name","attribute_name","value")))
  out~append(self~tool("CODING_LOAD_JSON_FILE","Add a semantic JSON load step resolved through RexxLanguageKnowledge.",self~properties(.array~of("class_name","method_name","filename","target_object")),.array~of("class_name","method_name","filename","target_object")))
  out~append(self~tool("CODING_GET_NAMED_MEMBER","Add a semantic named-member traversal step.",self~properties(.array~of("class_name","method_name","source_object","member","target_object")),.array~of("class_name","method_name","source_object","member","target_object")))
  opProps=self~operationProperties
  opRequired=.array~of("operation","class_name","method_name","target","source","value","member","message","filename","index","names")
  out~append(self~tool("CODING_OPERATION","Add one operation from Coding Intention dev13 RexxLanguageKnowledge. Prefer portable semantic operations such as GET_COLLECTION_SIZE, GET_KEYS, APPEND_ITEM and CONTAINS_KEY over raw SEND_MESSAGE when they express the intent. SEND_MESSAGE requires runtime or class-contract method evidence. Use only operations advertised as renderable in semantic_context.coding_intention.available_operations. Prefix a semantic operand value with $ when it is an existing Rexx variable rather than a string literal. Set unused nullable operands to null.",opProps,opRequired))
  out~append(self~tool("CODING_CLEAR_STEPS","Discard accumulated semantic coding steps for the target method.",self~properties(.array~of("class_name","method_name")),.array~of("class_name","method_name")))
  out~append(self~tool("CODING_APPLY_METHOD","Render accumulated Coding Intention steps deterministically and submit the body through WRITE_METHOD.",self~properties(.array~of("class_name","method_name")),.array~of("class_name","method_name")))
  out~append(self~tool("WRITE_METHOD","Replace one existing method body. method_body must contain body statements only, never a ::method directive or whole file.",self~properties(.array~of("class_name","method_name","method_body")),.array~of("class_name","method_name","method_body")))
  out~append(self~tool("MATERIALISE","Reconstruct source from current accepted semantic objects for verification.",.directory~new,.array~new))
  reportProps=.directory~new; p=.directory~new; p["type"]="string"; p["description"]="Concise completion report grounded in verification evidence."; reportProps["report"]=p
  out~append(self~tool("REPORT","Report that the coding challenge is complete after verification evidence supports completion.",reportProps,.array~of("report")))
  return out

::method operationProperties private
  props=.directory~new
  do name over .array~of("operation","class_name","method_name")
    p=.directory~new; p["type"]="string"; props[name]=p
  end
  do name over .array~of("target","source","value","member","message","filename","index","names")
    p=.directory~new; types=.array~of("string","null"); p["type"]=types; props[name]=p
  end
  props["operation"]["description"]="Exact Coding Intention dev13 RexxLanguageKnowledge operation ID."
  props["class_name"]["description"]="Exact semantic class name."
  props["method_name"]["description"]="Exact semantic method name."
  return props

::method properties private
  use strict arg names
  props=.directory~new
  do name over names
    p=.directory~new
    if name=="ordinal" then p["type"]="integer"
    else p["type"]="string"
    select
      when name=="class_name" then p["description"]="Exact semantic class name."
      when name=="method_name" then p["description"]="Exact semantic method name."
      when name=="attribute_name" then p["description"]="Exact semantic attribute name."
      when name=="requires_target" then p["description"]="ooRexx required package/file target."
      when name=="ordinal" then p["description"]="Whole-number semantic projection position."
      when name=="method_body" then p["description"]="Only Rexx statements belonging inside the existing method body."
      when name=="condition" then p["description"]="Semantic comparison value for a guard."
      when name=="return_value" then p["description"]="Semantic return value, for example false or true."
      when name=="value" then p["description"]="Semantic value to assign."
      when name=="filename" then p["description"]="JSON file path/value supplied to the semantic JSON-load step."
      when name=="target_object" then p["description"]="Target variable/object name."
      when name=="source_object" then p["description"]="Existing source object variable name."
      when name=="member" then p["description"]="Named member/key to retrieve."
      when name=="message" then p["description"]="No-argument ooRexx message name. Accepted only with runtime or class-contract evidence."
      when name=="operation" then p["description"]="Exact Coding Intention dev13 RexxLanguageKnowledge operation ID."
      when name=="target" then p["description"]="Target Rexx variable/collection name for the semantic operation."
      when name=="source" then p["description"]="Source Rexx variable/object name for the semantic operation."
      when name=="index" then p["description"]="Array index expression for the semantic operation."
      when name=="names" then p["description"]="Comma-separated argument names for ACCEPT_ARGUMENTS."
      otherwise nop
    end
    props[name]=p
  end
  return props

::method tool private
  use strict arg name,description,properties,required
  parameters=.directory~new
  parameters["type"]="object"
  parameters["properties"]=properties
  parameters["required"]=required
  parameters["additionalProperties"]=.false
  t=.directory~new
  t["type"]="function"
  t["name"]=name
  t["description"]=description
  t["parameters"]=parameters
  t["strict"]=.true
  return t

::method toolDecision private
  use strict arg body
  root=.json~fromJson(body)
  if root==.nil then raise syntax 88.900 array("Luna response is not JSON")
  if root~hasIndex("status") then do
    if root["status"]=="incomplete" then do
      reason=""
      if root~hasIndex("incomplete_details") then do
        details=root["incomplete_details"]
        if details\==.nil then if details~hasIndex("reason") then reason=details["reason"]~string
      end
      raise syntax 88.900 array("Luna response incomplete: "||reason)
    end
  end
  if \root~hasIndex("output") then raise syntax 88.900 array("Luna response has no output")
  calls=.array~new
  do item over root["output"]
    if item~hasIndex("type") then do
      if item["type"]=="function_call" then calls~append(item)
      if item["type"]=="message" then do
        if item~hasIndex("content") then do part over item["content"]
          if part~hasIndex("type") then do
            if part["type"]=="refusal" then do
              refusal="model refusal"
              if part~hasIndex("refusal") then refusal=part["refusal"]~string
              raise syntax 88.900 array("Luna refused coding action: "||refusal)
            end
          end
        end
      end
    end
  end
  if calls~items\==1 then raise syntax 88.900 array("Luna must press exactly one coding tool; calls="||calls~items)
  call=calls~at(1)
  action=translate(call["name"]~string)
  args=.directory~new
  if call~hasIndex("arguments") then do
    decoded=.json~fromJson(call["arguments"]~string)
    if decoded\==.nil then args=decoded
  end
  decisionArgs=args
  report=""
  if action=="REPORT" then do
    if args~hasIndex("report") then report=args["report"]~string
    decisionArgs=.directory~new
  end
  decision=.directory~new
  decision["action"]=action
  decision["args"]=decisionArgs
  decision["report"]=report
  return .json~toJson(decision)

::requires "LlmCodingBoundaryAdapter.cls"
::requires "json.cls"
