/* Native backend behavioral conformance template.
 *
 * Load only the native compatibility adapter package; do not import two
 * colliding public class namespaces into one ooRexx package.
 *
 * Provider contract:
 *   name
 *   supports(capability)
 *   reset(scenario)
 *   database
 *
 * Example:
 *   provider = .MyNativeConformanceProvider~new(...)
 *   suiteResult = .DatabaseBackendConformanceSuite~new~run(provider)
 *   do line over suiteResult~details
 *     say line
 *   end
 *   if \suiteResult~success then exit 9
 */
say "NATIVE BACKEND CONFORMANCE TEMPLATE: NOT CONFIGURED"
exit 64

::requires "database_core.cls"
