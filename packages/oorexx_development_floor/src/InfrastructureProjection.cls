/* InfrastructureProjection.cls
   Read-only, identity-preserving infrastructure projection for Development Floor.

   Provider/control-plane facts remain independently attributable.  The projection
   presents one stable node object while retaining every divergent observation.
   Mutation authority remains with the registered control plane/resource provider.
*/

::class DFInfrastructureObservation public
::method init
  expose name source value status observedAt evidence metadata
  use strict arg nameArg, sourceArg, valueArg=.nil, statusArg="OBSERVED", observedAtArg="", evidenceArg=""
  name = self~canonicalName(nameArg)
  source = translate(sourceArg~strip)
  value = valueArg
  status = translate(statusArg~strip)
  if status = "" then status = "OBSERVED"
  observedAt = observedAtArg
  evidence = evidenceArg
  metadata = .Directory~new
::attribute name get
::attribute source get
::attribute value get
::attribute status get
::attribute observedAt get
::attribute evidence get
::attribute metadata get
::method setMetadata
  expose metadata
  use strict arg key, item
  metadata[key] = item
  return self
::method canonicalName private
  use strict arg raw
  answer = translate(raw~string)
  answer = answer~changestr("_", "")
  answer = answer~changestr("-", "")
  answer = answer~changestr(".", "")
  answer = answer~changestr(" ", "")
  return answer

::class DFObservedFact public
::method init
  expose name observations preferences
  use strict arg nameArg
  name = self~canonicalName(nameArg)
  observations = .Array~new
  preferences = .Array~new
::attribute name get
::attribute observations get
::method prefer
  expose preferences
  use strict arg source
  wanted = translate(source~strip)
  do item over preferences
    if item = wanted then return self
  end
  preferences~append(wanted)
  return self
::method add
  expose observations
  use strict arg observation
  if observation~name <> self~name then raise syntax 93.900 array("Observation name does not match fact", self~name, observation~name)
  observations~append(observation)
  return observation
::method bySource
  expose observations
  use strict arg source
  wanted = translate(source~strip)
  i = observations~items
  do while i > 0
    observation = observations[i]
    if observation~source = wanted then return observation
    i -= 1
  end
  return .nil
::method currentObservation
  expose observations preferences
  do source over preferences
    observation = self~bySource(source)
    if observation <> .nil then return observation
  end
  if observations~items = 0 then return .nil
  return observations[observations~items]
::method value
  observation = self~currentObservation
  if observation == .nil then return .nil
  return observation~value
::method sources
  expose observations
  answer = .Array~new
  seen = .Directory~new
  do observation over observations
    if seen~at(observation~source) == .nil then do
      seen[observation~source] = 1
      answer~append(observation~source)
    end
  end
  return answer
::method canonicalName private
  use strict arg raw
  answer = translate(raw~string)
  answer = answer~changestr("_", "")
  answer = answer~changestr("-", "")
  answer = answer~changestr(".", "")
  answer = answer~changestr(" ", "")
  return answer

::class DFFirewallRule public
::method init
  expose scope source direction protocol action portFrom portTo sourceSpec destinationSpec evidence metadata
  use strict arg scopeArg, sourceArg, directionArg="INBOUND", protocolArg="ANY", actionArg="OBSERVE", portFromArg="", portToArg="", sourceSpecArg="", destinationSpecArg="", evidenceArg=""
  scope = translate(scopeArg~strip)
  source = translate(sourceArg~strip)
  direction = translate(directionArg~strip)
  protocol = translate(protocolArg~strip)
  action = translate(actionArg~strip)
  portFrom = portFromArg
  portTo = portToArg
  sourceSpec = sourceSpecArg
  destinationSpec = destinationSpecArg
  evidence = evidenceArg
  metadata = .Directory~new
::attribute scope get
::attribute source get
::attribute direction get
::attribute protocol get
::attribute action get
::attribute portFrom get
::attribute portTo get
::attribute sourceSpec get
::attribute destinationSpec get
::attribute evidence get
::attribute metadata get
::method setMetadata
  expose metadata
  use strict arg key, item
  metadata[key] = item
  return self

::class DFFirewallFacet public
::method init
  expose scope source status observedAt evidence rules metadata
  use strict arg scopeArg, sourceArg="", statusArg="UNKNOWN", observedAtArg="", evidenceArg=""
  scope = translate(scopeArg~strip)
  source = translate(sourceArg~strip)
  status = translate(statusArg~strip)
  observedAt = observedAtArg
  evidence = evidenceArg
  rules = .Array~new
  metadata = .Directory~new
::attribute scope get
::attribute source get
::attribute status
::attribute observedAt
::attribute evidence
::attribute rules get
::attribute metadata get
::method addRule
  expose rules
  use strict arg rule
  rules~append(rule)
  return rule
::method setMetadata
  expose metadata
  use strict arg key, item
  metadata[key] = item
  return self

::class DFFirewallProjection public
::method init
  expose nodeId facets
  use strict arg nodeIdArg
  nodeId = nodeIdArg
  facets = .Directory~new
::attribute nodeId get
::method putFacet
  expose facets
  use strict arg facet
  facets[self~facetKey(facet~scope, facet~source)] = facet
  return facet
::method facet
  expose facets
  use strict arg scope, source=""
  wantedScope = translate(scope~strip)
  wantedSource = translate(source~strip)
  if wantedSource <> "" then return facets~at(self~facetKey(wantedScope, wantedSource))
  do facet over facets~allItems
    if facet~scope = wantedScope then return facet
  end
  return .nil
::method facets
  expose facets
  return facets~allItems
::method rules
  expose facets
  answer = .Array~new
  do facet over facets~allItems
    do rule over facet~rules
      answer~append(rule)
    end
  end
  return answer
::method status
  expose facets
  if facets~items = 0 then return "UNKNOWN"
  good = 0
  bad = 0
  do facet over facets~allItems
    if facet~status = "OBSERVED" | facet~status = "ACTIVE" | facet~status = "OK" then good += 1
    else bad += 1
  end
  if good > 0 then do
    if bad = 0 then return "OBSERVED"
    return "PARTIAL"
  end
  return "UNAVAILABLE"
::method cloudFacet
  return self~facet("CLOUD")
::method localFacet
  return self~facet("LOCAL")
::method guestInternalFacet
  return self~facet("GUEST_INTERNAL")
::method facetKey private
  use strict arg scope, source
  return translate(scope~strip) || "|" || translate(source~strip)

::class DFManagedNodeProjection public
::method init
  expose id provider providerAccountId facts firewall metadata
  use strict arg idArg, providerArg="", providerAccountIdArg=""
  if idArg~strip = "" then raise syntax 93.900 array("Managed node id must not be empty")
  id = translate(idArg~strip)
  provider = translate(providerArg~strip)
  providerAccountId = providerAccountIdArg
  facts = .Directory~new
  firewall = .DFFirewallProjection~new(id)
  metadata = .Directory~new
  self~fact("CLOUD_STATE")~prefer("ALCHEMY_CLOUD_CONTROL")
  self~fact("REACHABLE")~prefer("SSHNODE")~prefer("ALCHEMY_CLOUD_CONTROL")
  self~fact("FREE_SPACE")~prefer("SSHNODE")
  self~fact("MEMORY")~prefer("SSHNODE")
  self~fact("OOREXX_VERSION")~prefer("SSHNODE")
  self~fact("QEMU_VERSION")~prefer("SSHNODE")
  self~fact("TASK_PROCESSES")~prefer("SSHNODE")
::attribute id get
::attribute provider
::attribute providerAccountId
::attribute firewall get
::attribute metadata get
::method setMetadata
  expose metadata
  use strict arg key, item
  metadata[key] = item
  return self
::method fact
  expose facts
  use strict arg name
  key = self~canonicalName(name)
  current = facts~at(key)
  if current == .nil then do
    current = .DFObservedFact~new(key)
    facts[key] = current
  end
  return current
::method observe
  use strict arg name, source, value=.nil, status="OBSERVED", observedAt="", evidence=""
  observation = .DFInfrastructureObservation~new(name, source, value, status, observedAt, evidence)
  self~fact(name)~add(observation)
  return observation
::method observations
  use strict arg name
  return self~fact(name)~observations~copy
::method resolvedValue
  use strict arg name
  return self~fact(name)~value
::method cloudState; return self~resolvedValue("CLOUD_STATE")
::method reachable; return self~resolvedValue("REACHABLE")
::method freeSpace; return self~resolvedValue("FREE_SPACE")
::method memory; return self~resolvedValue("MEMORY")
::method ooRexxVersion; return self~resolvedValue("OOREXX_VERSION")
::method qemuVersion; return self~resolvedValue("QEMU_VERSION")
::method taskProcesses; return self~resolvedValue("TASK_PROCESSES")
::method snapshot
  expose facts firewall
  answer = .Directory~new
  answer["node_id"] = self~id
  answer["provider"] = self~provider
  answer["provider_account_id"] = self~providerAccountId
  normalized = .Directory~new
  do key over facts
    normalized[key] = facts[key]~value
  end
  answer["facts"] = normalized
  answer["firewall_status"] = firewall~status
  answer["firewall_rules"] = firewall~rules
  return answer
::method unknown
  expose facts
  use arg messageName, args
  if args~items = 0 then do
    key = self~canonicalName(messageName)
    existing = facts~at(key)
    if existing <> .nil then return existing~value
  end
  raise syntax 97.1 array(self, messageName)
::method canonicalName private
  use strict arg raw
  answer = translate(raw~string)
  answer = answer~changestr("_", "")
  answer = answer~changestr("-", "")
  answer = answer~changestr(".", "")
  answer = answer~changestr(" ", "")
  return answer

::class DFNodeProjectionRegistry public
::method init
  expose nodes
  nodes = .Directory~new
::method node
  expose nodes
  use strict arg id, provider="", providerAccountId=""
  key = translate(id~strip)
  current = nodes~at(key)
  if current == .nil then do
    current = .DFManagedNodeProjection~new(key, provider, providerAccountId)
    nodes[key] = current
  end
  else do
    if provider <> "" then current~provider = translate(provider~strip)
    if providerAccountId <> "" then current~providerAccountId = providerAccountId
  end
  return current
::method at
  expose nodes
  use strict arg id
  return nodes~at(translate(id~strip))
::method all
  expose nodes
  return nodes~allItems
::method applySnapshot
  use strict arg snapshot
  if \snapshot~isA(.Directory) then raise syntax 93.900 array("Node observation snapshot must be a Directory")
  schema = snapshot~at("schema")
  if schema <> "development.floor.node-observation/0.1" then raise syntax 93.900 array("Unsupported node observation schema", schema)
  id = snapshot~at("node_id")
  provider = self~valueOr(snapshot, "provider", "")
  providerAccountId = self~valueOr(snapshot, "provider_account_id", "")
  target = self~node(id, provider, providerAccountId)

  observations = snapshot~at("observations")
  if observations <> .nil then do item over observations
    target~observe(item["name"], item["source"], item~at("value"), self~valueOr(item,"status","OBSERVED"), self~valueOr(item,"observed_at",""), self~valueOr(item,"evidence",""))
  end

  firewallItems = snapshot~at("firewall")
  if firewallItems <> .nil then do item over firewallItems
    facet = .DFFirewallFacet~new(item["scope"], self~valueOr(item,"source",""), self~valueOr(item,"status","UNKNOWN"), self~valueOr(item,"observed_at",""), self~valueOr(item,"evidence",""))
    rules = item~at("rules")
    if rules <> .nil then do ruleData over rules
      portFrom = self~valueOr(ruleData,"port_from","")
      portTo = self~valueOr(ruleData,"port_to",portFrom)
      rule = .DFFirewallRule~new(facet~scope, facet~source, self~valueOr(ruleData,"direction","INBOUND"), self~valueOr(ruleData,"protocol","ANY"), self~valueOr(ruleData,"action","OBSERVE"), portFrom, portTo, self~valueOr(ruleData,"source_spec",""), self~valueOr(ruleData,"destination_spec",""), self~valueOr(ruleData,"evidence",""))
      facet~addRule(rule)
    end
    target~firewall~putFacet(facet)
  end
  return target
::method valueOr private
  use strict arg directory, key, defaultValue
  value = directory~at(key)
  if value == .nil then return defaultValue
  return value
