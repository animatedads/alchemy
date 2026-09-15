package org.alchemy.wireui.swing;

import java.util.Map;
import java.util.Objects;

/** Exact, immutable Builder material-set payload accepted from WIRE-UI/0.1. */
public record WireMaterialSet(
        String materialId,
        String version,
        String materialKey,
        String contentAddress,
        Map<String, Object> tokens,
        Map<String, Object> recipes,
        Map<String, Object> siteRelease) {

    public WireMaterialSet {
        materialId = requireText(materialId, "materialId");
        version = requireText(version, "version");
        materialKey = requireText(materialKey, "materialKey");
        String exact = materialId + "@" + version;
        if (!materialKey.equals(exact)) throw new IllegalArgumentException("materialKey must be exact: " + exact);
        contentAddress = requireText(contentAddress, "contentAddress");
        tokens = WireValues.map(tokens);
        recipes = WireValues.map(recipes);
        siteRelease = WireValues.map(siteRelease);
    }

    public static WireMaterialSet fromWire(Map<String, Object> wire) {
        Objects.requireNonNull(wire, "wire");
        String id = WireValues.text(wire, "materialId", "").trim();
        String version = WireValues.text(wire, "version", "").trim();
        return new WireMaterialSet(id, version, id + "@" + version,
                WireValues.text(wire, "contentAddress", ""),
                WireValues.map(wire.get("tokens")),
                WireValues.map(wire.get("recipes")),
                WireValues.map(wire.get("siteRelease")));
    }

    public String tokenText(String name) {
        Object value = tokens.get(name);
        return value == null ? "" : String.valueOf(value);
    }

    public String recipe(String role) {
        Object value = recipes.get(role);
        return value == null ? "" : String.valueOf(value);
    }

    private static String requireText(String value, String field) {
        if (value == null || value.isBlank()) throw new IllegalArgumentException(field + " is required");
        return value.trim();
    }
}
