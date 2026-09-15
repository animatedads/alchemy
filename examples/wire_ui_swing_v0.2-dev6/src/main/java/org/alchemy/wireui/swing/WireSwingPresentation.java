package org.alchemy.wireui.swing;

import javax.swing.AbstractButton;
import javax.swing.BorderFactory;
import javax.swing.JComponent;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.UIManager;
import java.awt.Color;
import java.awt.Font;
import java.awt.Insets;
import java.util.Locale;

/**
 * Conservative renderer-side presentation for semantic Wire UI components.
 *
 * <p>This class intentionally consumes semantic primitive/style-role hints only.
 * It never interprets journey state, business data, permissions, or application
 * identity. Presentation uses the active Swing look-and-feel rather than fixed
 * application colours so a host desktop retains native accessibility/theming.</p>
 */
final class WireSwingPresentation {
    void apply(WireDefinition definition, JComponent component) { apply(definition, component, null); }

    void apply(WireDefinition definition, JComponent component, WireMaterialSet material) {
        WireSwingEdt.requireEdt();
        if (component.getName() == null || component.getName().isBlank()) {
            component.setName("wire-ui-" + definition.primitive().toLowerCase(Locale.ROOT)
                    + "-" + safeToken(definition.definitionId()));
        }
        if (!definition.label().isBlank() && component.getAccessibleContext() != null
                && component.getAccessibleContext().getAccessibleName() == null) {
            component.getAccessibleContext().setAccessibleName(definition.label());
        }

        String primitive = definition.primitive();
        String role = definition.styleRole().toLowerCase(Locale.ROOT);
        if (component instanceof JPanel panel) panel.setOpaque(false);
        if (component instanceof JScrollPane scroll) {
            scroll.setBorder(BorderFactory.createEmptyBorder());
            scroll.getVerticalScrollBar().setUnitIncrement(16);
        }

        if (primitive.equals("FORM") || primitive.equals("TOKEN_FORM")
                || primitive.equals("CHOICE_LIST") || primitive.equals("SEMANTIC_RECORD")) {
            component.setBorder(BorderFactory.createEmptyBorder(6, 8, 8, 8));
        }

        if (component instanceof JLabel label && isHeading(role)) {
            Font base = label.getFont();
            label.setFont(base.deriveFont(Font.BOLD, Math.max(base.getSize2D() + 2.0f, 14.0f)));
        }
        if (component instanceof AbstractButton button && role.contains("primary")) {
            button.setFont(button.getFont().deriveFont(Font.BOLD));
            Insets margin = UIManager.getInsets("Button.margin");
            if (margin != null) {
                button.setMargin(new Insets(
                        Math.max(4, margin.top), Math.max(10, margin.left),
                        Math.max(4, margin.bottom), Math.max(10, margin.right)));
            }
        }
        if (material != null) applySafeMaterial(definition, component, material, role);
    }


    private static void applySafeMaterial(WireDefinition definition, JComponent component, WireMaterialSet material, String role) {
        Color ink = parseColor(material.tokenText("brand.ink"));
        Color accent = parseColor(material.tokenText("brand.accent"));
        Color surface = parseColor(material.tokenText("surface"));
        if (ink != null) component.setForeground(ink);
        if (surface != null && component instanceof JPanel panel) { panel.setBackground(surface); panel.setOpaque(true); }
        if (component instanceof AbstractButton button && role.contains("primary") && accent != null) {
            // Accent is presentation only. Keep L&F text contrast and painting policy intact.
            button.setBorder(BorderFactory.createLineBorder(accent, 2));
        }
        String materialRole = WireValues.text(definition.metadata(), "materialRole", "");
        if (!materialRole.isBlank()) {
            String recipe = material.recipe(materialRole);
            if (!recipe.isBlank()) component.putClientProperty("wire.materialRecipe", recipe);
        }
        int unit = parsePositiveInt(material.tokenText("space.unit"), 0);
        if (unit > 0) component.putClientProperty("wire.spaceUnit", unit);
        component.putClientProperty("wire.materialKey", material.materialKey());
    }

    private static Color parseColor(String text) {
        String v = text == null ? "" : text.trim();
        if (!v.matches("#[0-9a-fA-F]{6}")) return null;
        try { return Color.decode(v); } catch (NumberFormatException ex) { return null; }
    }

    private static int parsePositiveInt(String text, int fallback) {
        try { int n=Integer.parseInt(String.valueOf(text).trim()); return n>0 && n<=64 ? n : fallback; }
        catch (RuntimeException ex) { return fallback; }
    }

    private static boolean isHeading(String role) {
        return role.contains("heading") || role.contains("header") || role.contains("title");
    }

    private static String safeToken(String value) {
        return value.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9_-]+", "-");
    }
}
