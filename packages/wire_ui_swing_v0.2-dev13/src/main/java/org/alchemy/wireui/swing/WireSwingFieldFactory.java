package org.alchemy.wireui.swing;

import javax.swing.JTextField;
import java.util.Locale;

/** Browser-parity presentation hints only; submitted values remain strings. */
final class WireSwingFieldFactory {
    JTextField create(String projectionName) {
        String type = inputType(projectionName);
        JTextField field = new JTextField(columns(type));
        field.putClientProperty("wire.inputType", type);
        if (field.getAccessibleContext() != null) field.getAccessibleContext().setAccessibleDescription(description(type));
        if (type.equals("number")) field.setHorizontalAlignment(JTextField.TRAILING);
        return field;
    }

    static String inputType(String name) {
        String n = String.valueOf(name == null ? "" : name).toLowerCase(Locale.ROOT);
        if (n.contains("date")) return "date";
        if (n.contains("passenger") || n.contains("count") || n.contains("quantity")) return "number";
        if (n.contains("email")) return "email";
        return "text";
    }

    private static int columns(String type) {
        return switch (type) { case "date" -> 12; case "number" -> 8; case "email" -> 24; default -> 20; };
    }
    private static String description(String type) {
        return switch (type) { case "date" -> "Date field; expected format YYYY-MM-DD"; case "number" -> "Numeric field"; case "email" -> "Email address field"; default -> "Text field"; };
    }
}
