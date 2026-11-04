/* Contract/documentation base for Alchemy language crossings.
 * Implementations perform both conversions at this one boundary:
 *   ooRexx variables -> language values/objects -> code block
 *   language result -> ooRexx result
 * Live Alchemy objects remain live; this contract does not prescribe copies,
 * JSON, an engine, or a renderer.
 */
::class WireLanguageBlockBridge public
::method executeBlock abstract
