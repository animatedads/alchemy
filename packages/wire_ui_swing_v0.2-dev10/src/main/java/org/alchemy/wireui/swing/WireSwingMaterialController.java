package org.alchemy.wireui.swing;

import java.util.LinkedHashMap;
import java.util.Map;

/** Exact material cache. Delivery provenance is not immutable material content. */
final class WireSwingMaterialController {
    private final Map<String, WireMaterialSet> seen = new LinkedHashMap<>();
    private WireMaterialSet current;

    WireMaterialSet accept(WireMaterialSet material) {
        WireMaterialSet prior = seen.get(material.materialKey());
        if (prior != null && !sameImmutableContent(prior, material)) {
            throw new WireSwingException("MATERIAL_IMMUTABILITY_VIOLATION", material.materialKey());
        }
        seen.putIfAbsent(material.materialKey(), material);
        // siteRelease is delivery provenance and can legitimately change.
        WireMaterialSet canonical = seen.get(material.materialKey());
        current = new WireMaterialSet(canonical.materialId(), canonical.version(), canonical.materialKey(), canonical.contentAddress(),
                canonical.tokens(), canonical.recipes(), material.siteRelease());
        return current;
    }

    WireMaterialSet current() { return current; }
    int count() { return seen.size(); }

    private static boolean sameImmutableContent(WireMaterialSet a, WireMaterialSet b) {
        return a.materialId().equals(b.materialId())
                && a.version().equals(b.version())
                && a.contentAddress().equals(b.contentAddress())
                && a.tokens().equals(b.tokens())
                && a.recipes().equals(b.recipes());
    }
}
