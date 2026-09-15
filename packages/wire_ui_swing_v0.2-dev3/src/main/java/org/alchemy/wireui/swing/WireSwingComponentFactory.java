package org.alchemy.wireui.swing;

import javax.swing.*;
import javax.swing.event.ListSelectionEvent;
import java.awt.*;
import java.awt.event.ActionListener;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

final class WireSwingComponentFactory {
    private final WireSwingPresentation presentation = new WireSwingPresentation();

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
        presentation.apply(definition, binding.component());
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
        list.setVisibleRowCount(6);
        list.setFixedCellHeight(Math.max(22, list.getFixedCellHeight()));
        list.setCellRenderer(new DefaultListCellRenderer() {
            @Override public Component getListCellRendererComponent(
                    JList<?> owner, Object value, int index, boolean selected, boolean focus) {
                Component rendered = super.getListCellRendererComponent(owner, value, index, selected, focus);
                if (rendered instanceof JLabel label) label.setText(collectionDisplayText(value));
                return rendered;
            }
        });
        JScrollPane pane = new JScrollPane(list);
        if (!definition.action().isBlank()) {
            list.addListSelectionListener((ListSelectionEvent e) -> {
                if (!e.getValueIsAdjusting() && list.getSelectedIndex() >= 0) {
                    sink.accept(action(definition, instance, collectionActionDetail(list.getSelectedIndex(), list.getSelectedValue())));
                }
            });
        }
        return new BaseBinding(pane) {
            @Override public void applySlot(String slot, Object value) {
                common(slot, value);
                if (slot.equals("items") || slot.equals("offers")) {
                    model.clear();
                    for (Object item : WireValues.list(value)) model.addElement(item);
                }
            }
            @Override public Map<String, Object> actionDetail() {
                if (list.getSelectedIndex() < 0) return Map.of();
                return collectionActionDetail(list.getSelectedIndex(), list.getSelectedValue());
            }
        };
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
            JComponent editor = choices && !serverIdentity ? new JCheckBox() : new JTextField(20);
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
            JComponent value = editableActionField ? new JTextField(20) : new JLabel();
            value.setName(semanticName);
            values.put(semanticName, value);
            values.putIfAbsent(projectionName, value);
            if (editableActionField) actionFields.putIfAbsent(semanticName, value);
            GridBagConstraints lc = gbc(0, row, 1); lc.anchor = GridBagConstraints.LINE_END; lc.fill = GridBagConstraints.NONE;
            JLabel fieldLabel = new JLabel(humanLabel(projectionName) + ":");
            fieldLabel.setLabelFor(value);
            panel.add(fieldLabel, lc);
            panel.add(value, gbc(1, row, 11)); row++;
        }
        if (!definition.action().isBlank()) {
            JButton actionButton = new JButton("Send");
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
