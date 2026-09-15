parse arg root qid
if root == "" | qid == "" then do; say "FAIL usage"; exit 2; end
requirement = .QueueWLURequirement~managedDemand("queuebash-bridge", "queue/bridge", 2000000, 3000000, 4, 500000)
bridge = .QueueBashWLUBridge~new(root, .QueueStaticWLURequirementProvider~new(requirement))
receipt = bridge~stage(qid)
if \receipt~ok then do
  say "FAIL bridge" .QueueWLUBridgeStatus~name(receipt~status) receipt~detail
  exit 1
end
say "PASS staged" qid
::requires "QueueRexxWLUBridge.cls"
