/* Optional semantic seam from a live Layered Audio object to the Media
 * Methodologies dynamic intention surface.
 *
 * The selected recording/element/view/composite remains the exact caller-owned
 * ooRexx object.  This bridge neither serializes nor reconstructs it.
 */
::class MediaLayeredAudioMethodologyBridge public
::method surface
  use strict arg audioObject,methodologyProvider,context=.nil
  if audioObject=.nil then raise syntax 93.900 array("Live Audio object is required")
  if methodologyProvider=.nil then raise syntax 93.900 array("Media methodology intention provider is required")
  return methodologyProvider~surface(audioObject,context)

::requires "MediaMethodologyIntentions.cls"
