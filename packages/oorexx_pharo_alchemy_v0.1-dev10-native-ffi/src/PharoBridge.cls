/* ooRexx Pharo Alchemy v0.1-dev6
 * Abstract resident-runtime contract.  This interface deliberately describes
 * object/message semantics; it does not prescribe a transport or serialization.
 */
::class PharoBridge public abstract

/* Return the stable runtime family name used by Alchemy provenance/inspection. */
::method runtimeName
  return 'PHARO'

/* Ask the resident Pharo runtime whether RECEIVER currently understands SELECTOR.
 * Implementations must perform passive discovery: this method must not send the
 * selector or trigger doesNotUnderstand: as a side effect.
 */
::method understands abstract

/* Send SELECTOR/arguments to a resident Pharo receiver and return the projected
 * result.  Existing methods which raise must propagate as foreign failures; they
 * must never be reclassified as an absent selector.
 */
::method send abstract

/* Export a live ooRexx object into Pharo and return/reuse its stable foreign
 * identity.  Re-exporting the same live object must preserve identity.
 */
::method exportRexxObject abstract

/* Project a resident Pharo identity into ooRexx.  Implementations must intern
 * proxies so repeated import of the same live identity does not fork identity.
 */
::method importPharoObject abstract

/* Compare two Pharo-side identities using resident identity semantics, not value
 * equality or reconstructed state.
 */
::method samePharoIdentity abstract

/* Release one retained foreign identity/root.  A released generation must never
 * alias a subsequently allocated object.
 */
::method release abstract

/* Immutable semantic envelope used by adapters/tests.  Arguments remain objects;
 * this class is not a wire-format DTO.
 */
::class PharoMessage public

/* Construct a message envelope, normalizing omitted arguments to an empty Array. */
::method init
  expose receiver selector arguments positionalCount presence
  use strict arg receiver, selector, arguments = .nil, positionalCount = .nil, presence = .nil
  if arguments == .nil then arguments = .array~new
  if positionalCount == .nil then positionalCount = arguments~items
  if presence == .nil then do
    presence = .array~new(positionalCount)
    do i = 1 to positionalCount
      presence[i] = (i <= arguments~items)
    end
  end

::attribute receiver get
::attribute selector get
::attribute arguments get
::attribute positionalCount get
::attribute presence get

/* Carries a foreign exception without conflating it with message absence. */
::class PharoForeignFailure public

/* Capture the foreign exception class/message and optional opaque payload. */
::method init
  expose foreignClass foreignMessage payload
  use strict arg foreignClass, foreignMessage, payload = .nil

::attribute foreignClass get
::attribute foreignMessage get
::attribute payload get
