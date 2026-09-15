package org.alchemy.wireui.swing;

import javax.swing.AbstractButton;
import javax.swing.BorderFactory;
import javax.swing.JComponent;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.UIManager;
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
    void apply(WireDefinition definition, JComponent component) {
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
    }

    private static boolean isHeading(String role) {
        return role.contains("heading") || role.contains("header") || role.contains("title");
    }

    private static String safeToken(String value) {
        return value.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9_-]+", "-");
    }
}
