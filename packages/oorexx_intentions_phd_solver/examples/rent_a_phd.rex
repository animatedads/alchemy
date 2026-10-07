/* Minimal consumer pattern.  The actual Maths/ML/Physics/Rexxtronics adapter
 * is registered by the application and receives native Rexx objects. */
parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || base || "/../deps/intention_service/src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

service = .IntentionService~new
service~useNlp("META")
solver = .ScientificSolverProvider~new
solver~install(service)

say "Scientific solver provider ready. Example: solve a coupled physics/electronics problem"
::requires "ScientificSolverProvider.cls"
