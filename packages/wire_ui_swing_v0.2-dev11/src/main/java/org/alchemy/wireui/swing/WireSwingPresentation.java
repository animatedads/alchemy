package org.alchemy.wireui.swing;

import javax.swing.*;
import javax.swing.border.AbstractBorder;
import java.awt.*;
import java.util.Locale;

/** Modern renderer-side presentation driven only by semantic primitive/style-role hints. */
final class WireSwingPresentation {
    static final Color CANVAS = new Color(246, 247, 249);
    static final Color SURFACE = Color.WHITE;
    static final Color INK = new Color(31, 35, 42);
    static final Color MUTED = new Color(105, 113, 126);
    static final Color LINE = new Color(226, 230, 236);
    static final Color ACCENT = new Color(50, 86, 211);
    static final Color ACCENT_SOFT = new Color(236, 240, 255);

    void apply(WireDefinition definition, JComponent component) { apply(definition, component, null); }

    void apply(WireDefinition definition, JComponent component, WireMaterialSet material) {
        WireSwingEdt.requireEdt();
        if (component.getName() == null || component.getName().isBlank()) {
            component.setName("wire-ui-" + definition.primitive().toLowerCase(Locale.ROOT) + "-" + safeToken(definition.definitionId()));
        }
        String role = definition.styleRole().isBlank()
                ? WireValues.text(definition.metadata(), "styleRole", "").toLowerCase(Locale.ROOT)
                : definition.styleRole().toLowerCase(Locale.ROOT);
        component.setFont(uiFont(component.getFont(), Font.PLAIN, 14f));
        component.setForeground(INK);

        if (component instanceof JPanel panel) {
            panel.setOpaque(role.contains("card") || role.contains("panel") || role.contains("composer"));
            if (panel.isOpaque()) panel.setBackground(SURFACE);
        }
        if (component instanceof JScrollPane scroll) {
            scroll.setBorder(BorderFactory.createEmptyBorder());
            scroll.getViewport().setBackground(SURFACE);
            scroll.getVerticalScrollBar().setUnitIncrement(18);
        }
        if (component instanceof JLabel label) {
            if (isHeading(role)) label.setFont(uiFont(label.getFont(), Font.BOLD, role.contains("hero") ? 26f : 18f));
            else if (role.contains("muted") || role.contains("eyebrow")) {
                label.setForeground(MUTED);
                label.setFont(uiFont(label.getFont(), Font.BOLD, 12f));
            }
        }
        if (component instanceof AbstractButton button) styleButton(button, role);
        if (component instanceof JTextField field) {
            field.setBorder(new RoundedBorder(LINE, 10, 1, 10));
            field.setBackground(SURFACE);
            field.setForeground(INK);
            field.setCaretColor(ACCENT);
        }

        String primitive = definition.primitive();
        if (primitive.equals("FORM") || primitive.equals("TOKEN_FORM") || primitive.equals("CHOICE_LIST") || primitive.equals("SEMANTIC_RECORD")) {
            component.setBorder(BorderFactory.createCompoundBorder(new RoundedBorder(LINE, 14, 1, 0), BorderFactory.createEmptyBorder(16, 18, 16, 18)));
            component.setOpaque(true);
            component.setBackground(SURFACE);
        } else if (role.contains("card") || role.contains("panel") || role.contains("composer")) {
            component.setBorder(BorderFactory.createCompoundBorder(new RoundedBorder(LINE, 14, 1, 0), BorderFactory.createEmptyBorder(12, 14, 12, 14)));
        }

        if (material != null) {
            String materialRole = WireValues.text(definition.metadata(), "materialRole", "");
            if (!materialRole.isBlank()) {
                String recipe = material.recipe(materialRole);
                if (!recipe.isBlank()) component.putClientProperty("wire.materialRecipe", recipe);
            }
            int unit = parsePositiveInt(material.tokenText("space.unit"), 0);
            if (unit > 0) component.putClientProperty("wire.spaceUnit", unit);
            component.putClientProperty("wire.materialKey", material.materialKey());
        }
    }

    static void styleList(JList<?> list, String role) {
        list.setBackground(role.contains("navigation") ? CANVAS : SURFACE);
        list.setForeground(INK);
        list.setSelectionBackground(ACCENT_SOFT);
        list.setSelectionForeground(INK);
        list.setBorder(BorderFactory.createEmptyBorder(8, 8, 8, 8));
        list.setFixedCellHeight(role.contains("document") ? 58 : 42);
        list.setFont(uiFont(list.getFont(), Font.PLAIN, 14f));
    }

    static void stylePrimaryButton(AbstractButton button) { styleButton(button, "primary-action"); }
    static void styleInput(JTextField field) {
        field.setFont(uiFont(field.getFont(), Font.PLAIN, 14f));
        field.setBorder(BorderFactory.createCompoundBorder(new RoundedBorder(LINE, 10, 1, 0), BorderFactory.createEmptyBorder(8, 10, 8, 10)));
        field.setBackground(SURFACE); field.setForeground(INK); field.setCaretColor(ACCENT);
    }
    static void styleFieldLabel(JLabel label) { label.setForeground(MUTED); label.setFont(uiFont(label.getFont(), Font.BOLD, 11f)); }
    static void styleValueLabel(JLabel label) { label.setForeground(INK); label.setFont(uiFont(label.getFont(), Font.PLAIN, 14f)); }

    static String compactStatus(String status) {
        String value = status == null ? "" : status.trim().toUpperCase(Locale.ROOT);
        if (value.contains("PENDING")) return "PENDING";
        if (value.contains("APPROVED")) return "APPROVED";
        if (value.contains("REJECT")) return "REJECTED";
        if (value.contains("DRAFT")) return "DRAFT";
        if (value.contains("SUCCESS")) return "SUCCESS";
        if (value.contains("FAIL")) return "FAILED";
        return value.isBlank() ? "OPEN" : value;
    }

    static void styleStatusChip(JLabel label, String status) {
        String value = status == null ? "" : status.trim().toUpperCase(Locale.ROOT);
        Color foreground;
        Color background;
        if (value.contains("APPROVED") || value.contains("SUCCESS")) {
            foreground = new Color(35, 101, 62);
            background = new Color(232, 247, 237);
        } else if (value.contains("PENDING") || value.contains("REVIEW")) {
            foreground = new Color(132, 83, 16);
            background = new Color(255, 246, 225);
        } else if (value.contains("REJECT") || value.contains("FAIL")) {
            foreground = new Color(151, 48, 48);
            background = new Color(255, 235, 235);
        } else {
            foreground = new Color(76, 84, 97);
            background = new Color(239, 242, 246);
        }
        label.setForeground(foreground);
        label.setBackground(background);
        label.setBorder(new RoundedBorder(background.darker(), 12, 1, 5));
    }

    private static void styleButton(AbstractButton button, String role) {
        button.setFocusPainted(false);
        button.setOpaque(true);
        button.setFont(uiFont(button.getFont(), Font.BOLD, 13f));
        button.setMargin(new Insets(9, 16, 9, 16));
        boolean primary = role.contains("primary");
        button.setForeground(primary ? Color.WHITE : INK);
        button.setBackground(primary ? ACCENT : SURFACE);
        button.setBorder(new RoundedBorder(primary ? ACCENT : LINE, 10, 1, 0));
        button.setCursor(Cursor.getPredefinedCursor(Cursor.HAND_CURSOR));
    }

    private static Font uiFont(Font base, int style, float size) {
        String family = base == null ? "Dialog" : base.getFamily();
        return new Font(family, style, Math.round(size));
    }

    private static int parsePositiveInt(String text, int fallback) {
        try { int n = Integer.parseInt(String.valueOf(text).trim()); return n > 0 && n <= 64 ? n : fallback; }
        catch (RuntimeException ex) { return fallback; }
    }

    private static boolean isHeading(String role) {
        return role.contains("heading") || role.contains("header") || role.contains("title") || role.contains("hero");
    }

    private static String safeToken(String value) { return value.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9_-]+", "-"); }

    private static final class RoundedBorder extends AbstractBorder {
        private static final long serialVersionUID = 1L;
        private final Color color; private final int radius; private final int thickness; private final int inset;
        RoundedBorder(Color color, int radius, int thickness, int inset) { this.color=color; this.radius=radius; this.thickness=thickness; this.inset=inset; }
        @Override public void paintBorder(Component c, Graphics g, int x, int y, int width, int height) {
            Graphics2D g2=(Graphics2D)g.create();
            try { g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON); g2.setColor(color); g2.setStroke(new BasicStroke(thickness)); g2.drawRoundRect(x, y, width-1, height-1, radius, radius); }
            finally { g2.dispose(); }
        }
        @Override public Insets getBorderInsets(Component c) { return new Insets(inset,inset,inset,inset); }
    }
}
