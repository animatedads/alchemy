/* Demo-facing service boundary for the GTK/Wire application.
 * GTK does not know SWI handles, modules, predicates, or query lifetime.
 * It gives this service a live ooRexx mail object and receives rule results.
 */
::class EmailRuleService public
::method init
  expose runtime engine rulesPath
  use strict arg rulesPath
  runtime = .AlchemyPrologRuntime~new
  engine = runtime~engine
  self~loadRules

::method loadRules private
  expose runtime engine rulesPath
  q = engine~query("user", "consult", .array~of(runtime~atom(rulesPath)))
  ok = q~nextSolution
  q~close
  if \ok then raise syntax 93.900 array("Unable to load Prolog email rules: " rulesPath)

/* Compatibility surface retained for the existing GTK demo. */
::method route
  expose runtime engine
  use strict arg mail
  route = runtime~variable("Route")
  q = engine~query("email_rules", "route_email", .array~of(runtime~rexxObject(mail), route))
  if \q~nextSolution then do
    q~close
    raise syntax 93.900 array("email_rules:route_email/2 unexpectedly failed")
  end
  answer = route~text
  q~cut
  q~close
  return answer

/* Return [category, evidence] from classify_email/3 for GTK presentation.
 * The first argument is still the same live ooRexx mail object.
 */
::method classify
  expose runtime engine
  use strict arg mail
  category = runtime~variable("Category")
  evidence = runtime~variable("Evidence")
  q = engine~query("email_rules", "classify_email", -
      .array~of(runtime~rexxObject(mail), category, evidence))
  if \q~nextSolution then do
    q~close
    raise syntax 93.900 array("email_rules:classify_email/3 unexpectedly failed")
  end
  answer = .array~of(category~text, evidence~text)
  q~cut
  q~close
  return answer

::method close
  expose engine
  engine~close
  return self

::requires 'AlchemyProlog.cls'
