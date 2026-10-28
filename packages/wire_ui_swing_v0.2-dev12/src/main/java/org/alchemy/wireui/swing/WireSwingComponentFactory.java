package org.alchemy.wireui.swing;

import javax.swing.*;
import java.awt.*;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.KeyEvent;
import java.awt.event.MouseAdapter;
import java.awt.event.MouseEvent;
import java.awt.event.MouseWheelEvent;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

final class WireSwingComponentFactory {
    private final WireSwingPresentation presentation = new WireSwingPresentation();
    private final WireSwingFieldFactory fieldFactory = new WireSwingFieldFactory();
    private WireMaterialSet material;

    void setMaterial(WireMaterialSet material) { this.material = material; }
    void applyPresentation(WireDefinition definition, JComponent component) { presentation.apply(definition, component, material); }

    WireSwingComponentBinding create(WireDefinition definition, WireInstance instance, Consumer<Map<String, Object>> actionSink) {
        WireSwingEdt.requireEdt();
        WireSwingComponentBinding binding = switch (definition.primitive()) {
            case "PANEL", "CONTAINER" -> container();
            case "TEXT", "STATUS" -> label(definition.label());
            case "ACTION_BUTTON", "BUTTON", "MODE_SWITCH_OFFER" -> button(definition, instance, actionSink);
            case "INPUT" -> input(definition, instance, actionSink);
            case "DOCUMENT" -> document();
            case "LIST", "OFFER_LIST", "OFFER_SELECTOR", "SEMANTIC_COLLECTION" -> list(definition, instance, actionSink);
            case "FORM", "TOKEN_FORM" -> form(definition, instance, actionSink, false);
            case "CHOICE_LIST" -> form(definition, instance, actionSink, true);
            case "SEMANTIC_RECORD" -> semanticRecord(definition, instance, actionSink);
            default -> unsupported(definition);
        };
        presentation.apply(definition, binding.component(), material);
        return binding;
    }

    private WireSwingComponentBinding container() {
        JPanel panel = new JPanel(new GridBagLayout());
        panel.setOpaque(false);
        return simple(panel);
    }

    private WireSwingComponentBinding label(String initial) {
        JLabel label = new JLabel(initial == null ? "" : initial);
        return new BaseBinding(label) {
            @Override public void applySlot(String slot, Object value) {
                common(slot, value);
                if (slot.equals("value") || slot.equals("text")) label.setText(value == null ? "" : String.valueOf(value));
            }
        };
    }

    private WireSwingComponentBinding button(WireDefinition definition, WireInstance instance, Consumer<Map<String, Object>> sink) {
        JButton button = new JButton(definition.label().isBlank() ? "Continue" : definition.label());
        if (!definition.action().isBlank()) button.addActionListener(e -> sink.accept(action(definition, instance, Map.of())));
        return new BaseBinding(button) {
            @Override public void applySlot(String slot, Object value) {
                common(slot, value);
                if (slot.equals("text") || slot.equals("label")) button.setText(value == null ? "" : String.valueOf(value));
            }
        };
    }

    private WireSwingComponentBinding input(WireDefinition definition, WireInstance instance, Consumer<Map<String, Object>> sink) {
        JTextField field = new JTextField(20);
        if (!definition.action().isBlank()) field.addActionListener(e -> sink.accept(action(definition, instance, Map.of("value", field.getText()))));
        return new BaseBinding(field) {
            @Override public void applySlot(String slot, Object value) {
                common(slot, value);
                if (slot.equals("value")) field.setText(value == null ? "" : String.valueOf(value));
            }
            @Override public Map<String, Object> actionDetail() { return Map.of("value", field.getText()); }
        };
    }

    private WireSwingComponentBinding document() {
        JTextArea area = new JTextArea(12, 60);
        area.setEditable(false);
        area.setLineWrap(true);
        area.setWrapStyleWord(true);
        JScrollPane pane = new JScrollPane(area);
        return new BaseBinding(pane) {
            @Override public void applySlot(String slot, Object value) {
                common(slot, value);
                if (slot.equals("value") || slot.equals("text")) area.setText(value == null ? "" : String.valueOf(value));
            }
        };
    }

    private WireSwingComponentBinding list(WireDefinition definition, WireInstance instance, Consumer<Map<String, Object>> sink) {
        DefaultListModel<Object> model = new DefaultListModel<>();
        JList<Object> list = new JList<>(model);
        list.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);
        list.setVisibleRowCount(8);
        WireSwingPresentation.styleList(list, definition.styleRole().toLowerCase(java.util.Locale.ROOT));
        list.setCellRenderer(new DefaultListCellRenderer() {
            @Override public Component getListCellRendererComponent(
                    JList<?> owner, Object value, int index, boolean selected, boolean focus) {
                JLabel label = (JLabel) super.getListCellRendererComponent(owner, value, index, selected, focus);
                label.setText(collectionDisplayText(value));
                label.setBorder(BorderFactory.createEmptyBorder(8, 12, 8, 12));
                label.setFont(label.getFont().deriveFont(definition.styleRole().toLowerCase(java.util.Locale.ROOT).contains("navigation") ? Font.BOLD : Font.PLAIN, 14f));
                if (!selected) label.setBackground(definition.styleRole().toLowerCase(java.util.Locale.ROOT).contains("navigation") ? WireSwingPresentation.CANVAS : WireSwingPresentation.SURFACE);
                return label;
            }
        });
        JPanel structuralMount = new JPanel(new GridBagLayout());
        structuralMount.setOpaque(false);
        JScrollPane pane = new JScrollPane(list);
        JScrollBar virtualBar = new JScrollBar(Adjustable.VERTICAL);
        virtualBar.setVisible(false);
        JPanel shell = new JPanel(new BorderLayout());
        shell.setOpaque(false);
        shell.add(pane, BorderLayout.CENTER);
        shell.add(virtualBar, BorderLayout.LINE_END);
        final long[] rangeStart = {0};
        final int[] rangeCount = {0};
        final long[] rangeTotal = {0};
        final boolean[] virtual = {false};
        final boolean[] synchronising = {false};
        final long[] lastDemandStart = {-1};

        Runnable emitDemand = () -> {
            if (!virtual[0] || synchronising[0] || rangeCount[0] <= 0) return;
            long wanted = decodeVirtualStart(virtualBar, rangeCount[0], rangeTotal[0]);
            if (wanted == rangeStart[0] || wanted == lastDemandStart[0]) return;
            lastDemandStart[0] = wanted;
            sink.accept(rangeAction(instance, wanted, rangeCount[0]));
        };
        virtualBar.addAdjustmentListener(e -> emitDemand.run());
        pane.addMouseWheelListener((MouseWheelEvent e) -> {
            if (!virtual[0] || e.getWheelRotation() == 0) return;
            long step = Math.max(1L, rangeCount[0]);
            long wanted = clampRangeStart(rangeStart[0] + (e.getWheelRotation() > 0 ? step : -step), rangeCount[0], rangeTotal[0]);
            synchronising[0] = true;
            try { setVirtualBarPosition(virtualBar, wanted, rangeCount[0], rangeTotal[0]); }
            finally { synchronising[0] = false; }
            if (wanted != rangeStart[0] && wanted != lastDemandStart[0]) {
                lastDemandStart[0] = wanted;
                sink.accept(rangeAction(instance, wanted, rangeCount[0]));
            }
            e.consume();
        });
        if (!definition.action().isBlank()) {
            Action activate = new AbstractAction() {
                @Override public void actionPerformed(ActionEvent e) {
                    int index = list.getSelectedIndex();
                    if (index >= 0) sink.accept(action(definition, instance, collectionActionDetail(index, list.getSelectedValue())));
                }
            };
            list.getActionMap().put("wire.activate", activate);
            list.getInputMap(JComponent.WHEN_FOCUSED).put(KeyStroke.getKeyStroke(KeyEvent.VK_ENTER, 0), "wire.activate");
            list.addMouseListener(new MouseAdapter() {
                @Override public void mouseClicked(MouseEvent e) {
                    if (e.getClickCount() == 2 && SwingUtilities.isLeftMouseButton(e)) activate.actionPerformed(new ActionEvent(list, ActionEvent.ACTION_PERFORMED, "double-click"));
                }
            });
        }
        return new BaseBinding(shell) {
            @Override public Container mount() {
                WireSwingEdt.requireEdt();
                if (pane.getViewport().getView() != structuralMount) pane.setViewportView(structuralMount);
                return structuralMount;
            }
            @Override public void applySlot(String slot, Object value) {
                common(slot, value);
                if (slot.equals("items") || slot.equals("offers")) {
                    String selectedIdentity = collectionServerIdentity(list.getSelectedValue());
                    model.clear();
                    for (Object item : WireValues.list(value)) model.addElement(item);
                    if (!selectedIdentity.isBlank()) {
                        for (int i = 0; i < model.size(); i++) {
                            if (selectedIdentity.equals(collectionServerIdentity(model.get(i)))) { list.setSelectedIndex(i); break; }
                        }
                    }
                    if (pane.getViewport().getView() != list) pane.setViewportView(list);
                } else if (slot.equals("rangeWindow")) {
                    Map<String, Object> window = WireValues.map(value);
                    long start = WireValues.longValue(window, "start", -1);
                    long countLong = WireValues.longValue(window, "count", -1);
                    long total = WireValues.longValue(window, "total", -1);
                    applyRangeWindow(start, countLong, total);
                } else if (slot.equals("windowOffset")) {
                    rangeStart[0] = WireValues.longValue(Map.of("value", value), "value", -1);
                    applyProjectedServerWindowIfComplete();
                } else if (slot.equals("windowLimit")) {
                    long countLong = WireValues.longValue(Map.of("value", value), "value", -1);
                    if (countLong <= 0 || countLong > Integer.MAX_VALUE) throw new IllegalArgumentException("windowLimit requires 0<count<=Integer.MAX_VALUE");
                    rangeCount[0] = (int) countLong;
                    applyProjectedServerWindowIfComplete();
                } else if (slot.equals("windowTotalCount")) {
                    rangeTotal[0] = WireValues.longValue(Map.of("value", value), "value", -1);
                    applyProjectedServerWindowIfComplete();
                }
            }

            private void applyProjectedServerWindowIfComplete() {
                if (rangeStart[0] < 0 || rangeCount[0] <= 0 || rangeTotal[0] < 0) return;
                long effectiveCount = Math.min((long) rangeCount[0], Math.max(0L, rangeTotal[0] - rangeStart[0]));
                if (rangeTotal[0] == 0L) {
                    virtual[0] = false;
                    virtualBar.setVisible(false);
                    virtualBar.putClientProperty("wire.rangeStart", 0L);
                    virtualBar.putClientProperty("wire.rangeCount", 0);
                    virtualBar.putClientProperty("wire.rangeTotal", 0L);
                    return;
                }
                if (effectiveCount <= 0) throw new IllegalArgumentException("projected server window requires offset within totalCount");
                applyRangeWindow(rangeStart[0], effectiveCount, rangeTotal[0]);
            }

            private void applyRangeWindow(long start, long countLong, long total) {
                if (start < 0 || countLong <= 0 || countLong > Integer.MAX_VALUE || total < 0 || start > total || countLong > total - start) {
                    throw new IllegalArgumentException("range window requires 0<=start, 0<count<=remaining total");
                }
                rangeStart[0] = start;
                rangeCount[0] = (int) countLong;
                rangeTotal[0] = total;
                virtual[0] = true;
                lastDemandStart[0] = -1;
                synchronising[0] = true;
                try { setVirtualBarPosition(virtualBar, start, rangeCount[0], total); }
                finally { synchronising[0] = false; }
                virtualBar.putClientProperty("wire.rangeStart", start);
                virtualBar.putClientProperty("wire.rangeCount", rangeCount[0]);
                virtualBar.putClientProperty("wire.rangeTotal", total);
                virtualBar.setVisible(total > countLong);
                pane.setVerticalScrollBarPolicy(ScrollPaneConstants.VERTICAL_SCROLLBAR_NEVER);
            }
            @Override public Map<String, Object> actionDetail() {
                if (list.getSelectedIndex() < 0) return Map.of();
                return collectionActionDetail(list.getSelectedIndex(), list.getSelectedValue());
            }
        };
    }

    private static Map<String, Object> rangeAction(WireInstance instance, long start, int count) {
        Map<String, Object> detail = new LinkedHashMap<>();
        detail.put("start", start);
        detail.put("count", count);
        Map<String, Object> action = new LinkedHashMap<>();
        action.put("type", WireSwingProtocol.UI_ACTION);
        action.put("protocolVersion", WireSwingProtocol.VERSION);
        action.put("elementInstance", instance.instanceId());
        action.put("action", "RangeRequested");
        action.put("detail", detail);
        return action;
    }

    private static long clampRangeStart(long start, int count, long total) {
        long max = Math.max(0L, total - count);
        return Math.max(0L, Math.min(start, max));
    }

    private static void setVirtualBarPosition(JScrollBar bar, long start, int count, long total) {
        long clamped = clampRangeStart(start, count, total);
        if (total <= Integer.MAX_VALUE) {
            int maximum = (int) Math.max(1L, total);
            int extent = (int) Math.min((long) count, maximum);
            int value = (int) Math.min(clamped, (long) maximum - extent);
            bar.setValues(value, extent, 0, maximum);
            bar.setUnitIncrement(Math.max(1, count / 10));
            bar.setBlockIncrement(Math.max(1, count));
            return;
        }
        int scale = 1_000_000;
        int extent = Math.max(1, (int) Math.min(scale, Math.round((double) count * scale / total)));
        int maxValue = scale - extent;
        long maxStart = Math.max(1L, total - count);
        int value = (int) Math.round((double) clamped * maxValue / maxStart);
        bar.setValues(Math.min(value, maxValue), extent, 0, scale);
        bar.setUnitIncrement(Math.max(1, extent / 10));
        bar.setBlockIncrement(Math.max(1, extent));
    }

    private static long decodeVirtualStart(JScrollBar bar, int count, long total) {
        if (total <= Integer.MAX_VALUE) return clampRangeStart(bar.getValue(), count, total);
        long maxStart = Math.max(0L, total - count);
        int maxValue = Math.max(1, bar.getMaximum() - bar.getVisibleAmount());
        long decoded = Math.round((double) bar.getValue() * maxStart / maxValue);
        return clampRangeStart(decoded, count, total);
    }

    private WireSwingComponentBinding form(WireDefinition definition, WireInstance instance, Consumer<Map<String, Object>> sink, boolean choices) {
        JPanel panel = new JPanel(new GridBagLayout());
        panel.setOpaque(false);
        Map<String, JComponent> editors = new LinkedHashMap<>();
        Map<String, JComponent> canonicalEditors = new LinkedHashMap<>();
        Map<String, Object> bindings = WireValues.map(definition.metadata().get("bindings"));
        int row = 0;
        for (Map.Entry<String, Object> entry : bindings.entrySet()) {
            String projectionName = entry.getKey();
            String semanticName = String.valueOf(entry.getValue() == null ? projectionName : entry.getValue());
            boolean serverIdentity = projectionName.equalsIgnoreCase("saleId") || semanticName.equalsIgnoreCase("saleId");
            boolean hidden = serverIdentity;
            JComponent editor = choices && !serverIdentity ? new JCheckBox() : fieldFactory.create(projectionName);
            editor.setName(semanticName);
            editors.put(semanticName, editor);
            canonicalEditors.putIfAbsent(semanticName, editor);
            if (!semanticName.equals(projectionName)) editors.put(projectionName, editor);
            if (!hidden) {
                GridBagConstraints lc = gbc(0, row, 1); lc.anchor = GridBagConstraints.LINE_END; lc.fill = GridBagConstraints.NONE;
                JLabel fieldLabel = new JLabel(humanLabel(projectionName) + ":");
                fieldLabel.setLabelFor(editor);
                panel.add(fieldLabel, lc);
                GridBagConstraints ec = gbc(1, row, 11); panel.add(editor, ec);
                row++;
            }
        }
        JButton submit = new JButton("Continue");
        ActionListener submitAction = e -> sink.accept(action(definition, instance, collectEditors(canonicalEditors)));
        if (!definition.action().isBlank()) {
            submit.addActionListener(submitAction);
            for (JComponent editor : canonicalEditors.values()) {
                if (editor instanceof JTextField text) text.addActionListener(submitAction);
            }
        }
        GridBagConstraints bc = gbc(0, Math.max(row, 0), 12); bc.fill = GridBagConstraints.NONE; bc.anchor = GridBagConstraints.LINE_END;
        panel.add(submit, bc);
        return new BaseBinding(panel) {
            @Override public void applySlot(String slot, Object value) {
                common(slot, value);
                JComponent editor = editors.get(slot);
                if (editor instanceof JTextField text) text.setText(value == null ? "" : String.valueOf(value));
                else if (editor instanceof JCheckBox box) box.setSelected(WireValues.bool(value, false));
            }
            @Override public Map<String, Object> actionDetail() { return collectEditors(canonicalEditors); }
        };
    }

    private WireSwingComponentBinding semanticRecord(WireDefinition definition, WireInstance instance, Consumer<Map<String, Object>> sink) {
        JPanel panel = new JPanel(new GridBagLayout());
        panel.setOpaque(false);
        Map<String, JComponent> values = new LinkedHashMap<>();
        Map<String, JComponent> actionFields = new LinkedHashMap<>();
        Map<String, Object> bindings = WireValues.map(definition.metadata().get("bindings"));
        int row = 0;
        for (Map.Entry<String, Object> entry : bindings.entrySet()) {
            String projectionName = entry.getKey();
            String semanticName = String.valueOf(entry.getValue() == null ? projectionName : entry.getValue());
            boolean editableActionField = !definition.action().isBlank() && projectionName.equalsIgnoreCase("message");
            JComponent value = editableActionField ? fieldFactory.create(projectionName) : new JLabel();
            value.setName(semanticName);
            values.put(semanticName, value);
            values.putIfAbsent(projectionName, value);
            if (editableActionField) actionFields.putIfAbsent(semanticName, value);
            GridBagConstraints lc = gbc(0, row, 1); lc.anchor = GridBagConstraints.LINE_END; lc.fill = GridBagConstraints.NONE;
            JLabel fieldLabel = new JLabel(humanLabel(projectionName).toUpperCase(java.util.Locale.ROOT));
            WireSwingPresentation.styleFieldLabel(fieldLabel);
            fieldLabel.setLabelFor(value);
            lc.anchor = GridBagConstraints.LINE_START;
            panel.add(fieldLabel, lc);
            if (value instanceof JLabel valueLabel) WireSwingPresentation.styleValueLabel(valueLabel);
            else if (value instanceof JTextField textField) WireSwingPresentation.styleInput(textField);
            GridBagConstraints vc = gbc(1, row, 11); vc.anchor = GridBagConstraints.LINE_START;
            panel.add(value, vc); row++;
        }
        if (!definition.action().isBlank()) {
            JButton actionButton = new JButton("Send");
            WireSwingPresentation.stylePrimaryButton(actionButton);
            ActionListener sendAction = e -> sink.accept(action(definition, instance, collectEditors(actionFields)));
            actionButton.addActionListener(sendAction);
            for (JComponent field : actionFields.values()) {
                if (field instanceof JTextField text) text.addActionListener(sendAction);
            }
            panel.add(actionButton, gbc(0, row, 12));
        }
        return new BaseBinding(panel) {
            @Override public void applySlot(String slot, Object value) {
                common(slot, value);
                JComponent target = values.get(slot);
                if (target instanceof JTextField text) text.setText(value == null ? "" : String.valueOf(value));
                else if (target instanceof JLabel label) label.setText(value == null ? "" : String.valueOf(value));
            }
            @Override public Map<String, Object> actionDetail() { return collectEditors(actionFields); }
        };
    }

    private WireSwingComponentBinding unsupported(WireDefinition definition) {
        JPanel panel = new JPanel(new BorderLayout());
        panel.setName("wire-ui-unsupported");
        JLabel label = new JLabel("Unable to render " + definition.definitionKey() + " (" + definition.primitive() + ")");
        panel.add(label, BorderLayout.CENTER);
        return simple(panel);
    }

    private WireSwingComponentBinding simple(JComponent component) {
        return new BaseBinding(component) { @Override public void applySlot(String slot, Object value) { common(slot, value); } };
    }

    private static Map<String, Object> action(WireDefinition definition, WireInstance instance, Map<String, Object> detail) {
        Map<String, Object> action = WireSwingProtocol.message(WireSwingProtocol.UI_ACTION);
        action.put("elementInstance", instance.instanceId());
        action.put("action", definition.action());
        if (!detail.isEmpty()) action.put("detail", new LinkedHashMap<>(detail));
        return action;
    }

    private static Map<String, Object> collectionActionDetail(int index, Object item) {
        Map<String, Object> detail = new LinkedHashMap<>();
        detail.put("index", index);
        if (item instanceof Map<?, ?> raw) {
            for (String key : List.of("offerId", "id", "key", "code", "ref")) {
                Object value = raw.get(key);
                if (value != null) {
                    detail.put(key, value);
                    break;
                }
            }
        } else {
            detail.put("value", item);
        }
        return detail;
    }

    private static String collectionServerIdentity(Object item) {
        if (item instanceof Map<?, ?> raw) {
            for (String key : List.of("offerId", "id", "key", "code", "ref")) {
                Object value = raw.get(key);
                if (value != null && !String.valueOf(value).isBlank()) return key + "=" + value;
            }
        }
        return "";
    }

    private static String collectionDisplayText(Object item) {
        if (item == null) return "";
        if (item instanceof Map<?, ?> raw) {
            for (String key : List.of("label", "title", "name", "summary", "route", "code", "offerId", "id")) {
                Object value = raw.get(key);
                if (value != null && !String.valueOf(value).isBlank()) return String.valueOf(value);
            }
        }
        return String.valueOf(item);
    }

    private static Map<String, Object> collectEditors(Map<String, JComponent> editors) {
        Map<String, Object> detail = new LinkedHashMap<>();
        for (Map.Entry<String, JComponent> entry : editors.entrySet()) {
            if (detail.containsKey(entry.getKey())) continue;
            if (entry.getValue() instanceof JTextField text) detail.put(entry.getKey(), text.getText());
            else if (entry.getValue() instanceof JCheckBox box) detail.put(entry.getKey(), box.isSelected());
        }
        return detail;
    }

    private static GridBagConstraints gbc(int x, int y, int span) {
        GridBagConstraints c = new GridBagConstraints();
        c.gridx = x; c.gridy = y; c.gridwidth = span; c.weightx = span; c.fill = GridBagConstraints.HORIZONTAL;
        c.insets = new Insets(4, 4, 4, 4);
        return c;
    }

    private static String humanLabel(String s) {
        String v = s.replace('_', ' ').replace('-', ' ');
        if (v.isBlank()) return v;
        return Character.toUpperCase(v.charAt(0)) + v.substring(1);
    }

    private abstract static class BaseBinding implements WireSwingComponentBinding {
        private final JComponent component;
        BaseBinding(JComponent component) { this.component = component; }
        @Override public JComponent component() { return component; }
        void common(String slot, Object value) {
            WireSwingEdt.requireEdt();
            switch (slot) {
                case "visible" -> component.setVisible(WireValues.bool(value, true));
                case "enabled" -> component.setEnabled(WireValues.bool(value, true));
                case "ariaLabel" -> {
                    if (component.getAccessibleContext() != null) component.getAccessibleContext().setAccessibleName(value == null ? null : String.valueOf(value));
                }
                default -> { }
            }
        }
    }
}
