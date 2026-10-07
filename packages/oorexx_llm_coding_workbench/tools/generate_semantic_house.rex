/* Generate an executable House proof from Coding Intention semantic steps. */
parse arg outputPath
if strip(outputPath)=="" then raise syntax 88.900 array("output path required")
bridge=.LlmSemanticCodingBridge~new("House","openDoor")
/* Deliberately add mutation first; renderer must order the prior-state guard first. */
bridge~addSetAttribute("door","open")
bridge~addReturnIfAlready("door","open","false")
body=bridge~renderMethodBody
out=.stream~new(outputPath)
out~open("write replace")
out~lineout('house=.House~new')
out~lineout('if house~openDoor \== .true then raise syntax 88.900 array("first openDoor should return true")')
out~lineout('if house~openDoor \== .false then raise syntax 88.900 array("second openDoor should return false")')
out~lineout('if house~door \== "open" then raise syntax 88.900 array("door should remain open")')
out~lineout('say "PASS generated semantic House runtime behaviour"')
out~lineout('exit 0')
out~lineout('')
out~lineout('::class House public')
out~lineout('::attribute door')
out~lineout('::method init')
out~lineout('  expose door')
out~lineout('  door = "closed"')
out~lineout('::method openDoor')
remaining=body||"0a"x
do while remaining\==""
  parse var remaining line "0a"x remaining
  if line\=="" then out~lineout("  "||line)
end
out~close
say "GENERATED" outputPath
exit 0
::requires "../src/LlmSemanticCodingBridge.cls"
