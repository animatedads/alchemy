/* Qualification sketch for dev7 object-preserving callbacks.
 * A FamilyBook ooRexx object can answer relationship messages from Prolog via
 * rexx_send/4. Returned Person objects are retained as rexx_object(Id) terms,
 * not coerced to names. Names/atoms are requested explicitly with callbackAtom.
 *
 * The executable native qualification is intentionally separate until SWI and
 * ooRexx are available together on the qualification host. */

say 'dev7 family qualification fixture: live object identity, backtracking, negative motherhood inference'
