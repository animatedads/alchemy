/**
 * Capability negotiation happens once. Hot rendering receives a profile id;
 * it does not repeatedly branch on browser brands or viewport properties.
 */
export function detectRenderCapabilities({ window = globalThis.window, document = globalThis.document } = {}) {
  const width = window?.innerWidth ?? 1024;
  const coarse = window?.matchMedia?.('(pointer: coarse)')?.matches ?? false;
  const reducedMotion = window?.matchMedia?.('(prefers-reduced-motion: reduce)')?.matches ?? false;
  const dark = window?.matchMedia?.('(prefers-color-scheme: dark)')?.matches ?? false;
  const viewportClass = width < 640 ? 'compact' : width < 1024 ? 'medium' : 'large';

  return Object.freeze({
    viewportClass,
    pointer: coarse ? 'coarse' : 'fine',
    reducedMotion,
    colourScheme: dark ? 'dark' : 'light',
    features: Object.freeze({
      dialog: !!document?.createElement?.('dialog')?.showModal,
      adoptedStyleSheets: !!document?.adoptedStyleSheets,
      resizeObserver: typeof globalThis.ResizeObserver !== 'undefined'
    })
  });
}

export function capabilityFingerprint(capabilities) {
  const f = capabilities.features;
  return [
    capabilities.viewportClass,
    capabilities.pointer,
    capabilities.reducedMotion ? 'rm1' : 'rm0',
    capabilities.colourScheme,
    f.dialog ? 'd1' : 'd0',
    f.adoptedStyleSheets ? 's1' : 's0',
    f.resizeObserver ? 'r1' : 'r0'
  ].join('.');
}
