package org.alchemy.wireui.swing;

import java.awt.GridBagConstraints;
import java.awt.Insets;
import java.util.Comparator;
import java.util.List;
import java.util.Map;

/** Translates runtime-neutral Builder composition hints into conservative GridBag placement. */
final class WireSwingLayoutEngine {
    LayoutCursor cursor() { return new LayoutCursor(); }

    long orderFor(WireDefinition definition, long fallback) {
        return WireValues.longValue(placement(definition), "order", fallback);
    }

    final class LayoutCursor {
        private int row;
        private int column;
        private int rowHeight = 1;

        GridBagConstraints next(WireDefinition definition) {
            Map<String, Object> placement = placement(definition);
            String model = layoutModel(definition);
            int span = model.equals("FLOW") ? 12 : clamp(WireValues.longValue(placement, "span", 12), 1, 12);
            int rowSpan = clamp(WireValues.longValue(placement, "rowSpan", 1), 1, 1000);
            if (model.equals("FLOW") || column + span > 12) {
                if (column != 0) row += rowHeight;
                column = 0;
                rowHeight = 1;
            }

            GridBagConstraints c = new GridBagConstraints();
            c.gridx = column;
            c.gridy = row;
            c.gridwidth = span;
            c.gridheight = rowSpan;
            c.weightx = span / 12.0;
            c.weighty = 0.0;
            c.fill = GridBagConstraints.HORIZONTAL;
            c.anchor = GridBagConstraints.NORTHWEST;
            c.insets = new Insets(5, 5, 5, 5);

            String align = WireValues.text(placement, "align", "STRETCH").toUpperCase();
            switch (align) {
                case "START" -> { c.anchor = GridBagConstraints.LINE_START; c.fill = GridBagConstraints.NONE; }
                case "CENTER" -> { c.anchor = GridBagConstraints.CENTER; c.fill = GridBagConstraints.NONE; }
                case "END" -> { c.anchor = GridBagConstraints.LINE_END; c.fill = GridBagConstraints.NONE; }
                default -> { }
            }

            rowHeight = Math.max(rowHeight, rowSpan);
            column += span;
            if (model.equals("FLOW") || column >= 12) {
                row += rowHeight;
                column = 0;
                rowHeight = 1;
            }
            return c;
        }
    }

    private String layoutModel(WireDefinition definition) {
        List<Map<String, Object>> hints = WireValues.mapList(definition.metadata().get("compositionHints"));
        if (hints.isEmpty()) return "GRID12";
        return WireValues.text(hints.get(0), "layoutModel", "GRID12").toUpperCase();
    }

    private Map<String, Object> placement(WireDefinition definition) {
        List<Map<String, Object>> hints = WireValues.mapList(definition.metadata().get("compositionHints"));
        return hints.stream()
                .map(h -> WireValues.map(h.get("placement")))
                .filter(p -> !p.isEmpty())
                .min(Comparator.comparingLong(p -> WireValues.longValue(p, "order", Long.MAX_VALUE)))
                .orElse(Map.of());
    }

    private int clamp(long value, int min, int max) {
        return (int) Math.max(min, Math.min(max, value));
    }
}
