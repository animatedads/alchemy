package org.alchemy.wireui.swing;

import javax.swing.*;
import java.awt.*;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class WireSwingRuntimeTest {
    private static int tests;

    public static void main(String[] args) throws Exception {
        System.setProperty("java.awt.headless", "true");
        testHelloSeparatesRendererCapability();
        testExactManifestAndSnapshot();
        testParentBeforeChildRequired();
        testSnapshotRequiresExactlyOneDeclaredRoot();
        testPatchCannotCreateSecondRoot();
        testPatchRevisionMismatchResyncs();
        testPatchWaitsForExactDefinitionThenReplays();
        testSequentialPatchesQueueBehindMissingDefinition();
        testColdCacheSnapshotWaitsForDefinitions();
        testUnknownPrimitiveIsContained();
        testButtonActionLeavesEdtThroughQueue();
        testSlotPatchMutatesOnEdt();
        testTransactionalPatchRejectsBeforeVisualMutation();
        testFormCollectsFields();
        testBuilderCompiledTopLevelBindingsAreAccepted();
        testChoiceListPreservesServerIdentityAsString();
        testSemanticRecordMessageIsActionField();
        testActionableCollectionReturnsOnlyServerIdentity();
        testGrid12CompositionAllocation();
        testGrid12RowSpanAdvancesWholeRow();
        testStructuralInsertPreservesLocalInput();
        testSnapshotKeepsStableHostComponent();
        testPatchViewMismatchResyncs();
        testNullListItemActionIsContained();
        testManifestRequiresExpectedContentAddress();
        testInboundMessagesAreDefensivelyFrozen();
        testCyclicInboundValueIsContained();
        testFormLabelDoesNotRenameContinueAction();
        testFormEnterQueuesSemanticAction();
        testCollectionPresentationKeepsAuthorityNarrow();
        testHeadingStyleRoleIsPresentationOnly();
        testStandaloneDemoJourneyAuthorityIsOutsideRenderer();
        testServerOrderedCollectionAppendMovePreservesIdentity();
        testServerOrderedCollectionDestroyThenRemove();
        testListRemoveWithLiveDescendantRejectsTransaction();
        testListAppendWaitsForExactDefinition();
        testCollectionSelectionIsLocalUntilExplicitActivation();
        testCollectionSelectionSurvivesReorderByServerIdentity();
        testInlineRenderProfileManifestRequestsColdDefinitions();
        testManifestDeauthorisationKeepsCacheAndBlocksActions();
        testWarmReauthorisationUsesRetainedDefinitionCache();
        testRenderProfileManifestMismatchFailsClosed();
        testProfileIdIsNotDefinitionContentIdentity();
        testWorkspaceContextOpaqueEventTimePassthrough();
        testWorkspaceContextMissingFailsClosed();
        testWorkspaceContextMismatchFailsClosed();
        testWorkspaceContextCannotBeForgedByLocalDetail();
        testMaterialExactIdentityAndSiteReleaseProvenance();
        testMaterialMutationRejected();
        testMaterialReappliesWithoutReplacingComponent();
        testManifestIdReuseAndBlankAddressRejected();
        testTypedFieldHintsKeepStringSemantics();
        System.out.println("PASS " + tests + "/" + tests);
    }

    private static void testHelloSeparatesRendererCapability() {
        WireSwingRuntime runtime = new WireSwingRuntime();
        Map<String, Object> hello = runtime.hello("app", "s", "a");
        eq("UI_HELLO", hello.get("type"), "hello type");
        Map<String, Object> caps = castMap(hello.get("renderCapabilities"));
        eq("JAVA_SWING", caps.get("uiToolkit"), "toolkit capability");
        check(!hello.containsKey("interactionProfile"), "renderer hello must not choose interaction profile");
        pass();
    }

    private static void testExactManifestAndSnapshot() {
        WireSwingRuntime runtime = baseRuntime();
        runtime.accept(def("ROOT", 1, "PANEL", "", "", "addr-root", Map.of()));
        runtime.accept(def("TITLE", 1, "TEXT", "", "", "addr-title", Map.of()));
        runtime.accept(snapshot(7, List.of(
                inst("root", "ROOT@1", "", Map.of()),
                inst("title", "TITLE@1", "root", Map.of("text", "Hello Swing")))));
        eq(7L, runtime.revision(), "snapshot revision");
        JLabel label = find(runtime.rootComponent(), JLabel.class);
        eq("Hello Swing", label.getText(), "snapshot slot render");
        pass();
    }

    private static void testParentBeforeChildRequired() {
        WireSwingRuntime runtime = baseRuntime();
        runtime.accept(def("ROOT", 1, "PANEL", "", "", "addr-root", Map.of()));
        runtime.accept(def("TITLE", 1, "TEXT", "", "", "addr-title", Map.of()));
        runtime.accept(msg("UI_VIEW_SNAPSHOT", Map.of(
                "viewRef", "view-1", "revision", 1, "rootInstanceId", "root",
                "instances", List.of(inst("child", "TITLE@1", "root", Map.of()), inst("root", "ROOT@1", "", Map.of())))));
        eq(-1L, runtime.revision(), "bad snapshot must not commit");
        check(hasOutbound(runtime, "UI_ERROR", "SNAPSHOT_PARENT_ORDER_INVALID", "SNAPSHOT_INVALID"), "parent ordering error expected");
        pass();
    }

    private static void testSnapshotRequiresExactlyOneDeclaredRoot() {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("ROOT", 1, "r"), ref("TITLE", 1, "t")));
        runtime.accept(def("ROOT", 1, "PANEL", "", "", "r", Map.of()));
        runtime.accept(def("TITLE", 1, "TEXT", "", "", "t", Map.of()));
        runtime.accept(snapshot(1, List.of(inst("root", "ROOT@1", "", Map.of()), inst("orphan", "TITLE@1", "", Map.of("text", "orphan")))));
        eq(-1L, runtime.revision(), "multiple top-level instances must not commit");
        check(hasOutbound(runtime, "UI_ERROR", "MULTIPLE_VIEW_ROOTS"), "multiple roots are contained at snapshot boundary");
        pass();
    }

    private static void testPatchCannotCreateSecondRoot() {
        WireSwingRuntime runtime = basicTextRuntime();
        runtime.accept(def("BTN", 1, "BUTTON", "", "", "addr-btn", Map.of()));
        runtime.accept(patch(3, 4, List.of(Map.of("op", "CREATE_INSTANCE", "instance", inst("other-root", "BTN@1", "", Map.of())))));
        eq(3L, runtime.revision(), "second-root patch must not commit");
        check(hasOutbound(runtime, "UI_ERROR", "PATCH_INVALID"), "second-root patch rejected in preflight");
        pass();
    }

    private static void testPatchRevisionMismatchResyncs() {
        WireSwingRuntime runtime = basicTextRuntime();
        Map<String, Object> patch = patch(99, 100, List.of(Map.of("op", "SET_SLOT", "instanceId", "title", "slot", "text", "value", "Wrong")));
        runtime.accept(patch);
        eq(3L, runtime.revision(), "revision mismatch must not commit");
        check(hasOutbound(runtime, "UI_RESYNC_REQUEST", null, null), "resync request expected");
        pass();
    }

    private static void testPatchWaitsForExactDefinitionThenReplays() {
        WireSwingRuntime runtime = basicTextRuntime();
        Map<String, Object> create = Map.of("op", "CREATE_INSTANCE", "instance", inst("button", "BTN@1", "root", Map.of("text", "Go")));
        runtime.accept(patch(3, 4, List.of(create)));
        eq(3L, runtime.revision(), "missing definition patch must be held");
        eq(1, runtime.heldPatchCount(), "one held patch");
        check(hasOutbound(runtime, "UI_DEFINITION_REQUIRED", null, null), "definition request expected");
        runtime.accept(def("BTN", 1, "BUTTON", "GO", "Go", "addr-btn", Map.of()));
        eq(4L, runtime.revision(), "held patch replays after definition");
        eq(0, runtime.heldPatchCount(), "held patch cleared");
        pass();
    }

    private static void testSequentialPatchesQueueBehindMissingDefinition() {
        WireSwingRuntime runtime = basicTextRuntime();
        runtime.accept(patch(3, 4, List.of(Map.of("op", "CREATE_INSTANCE", "instance", inst("button", "BTN@1", "root", Map.of("text", "Go"))))));
        runtime.accept(patch(4, 5, List.of(Map.of("op", "SET_SLOT", "instanceId", "button", "slot", "text", "value", "Go 2"))));
        eq(3L, runtime.revision(), "definition barrier keeps committed revision");
        eq(2, runtime.heldPatchCount(), "subsequent patch queues behind definition barrier");
        List<Map<String, Object>> outbound = runtime.drainOutbound();
        check(outbound.stream().anyMatch(m -> "UI_DEFINITION_REQUIRED".equals(m.get("type"))), "definition request expected");
        check(outbound.stream().noneMatch(m -> "UI_RESYNC_REQUEST".equals(m.get("type"))), "sequential pending patch must not be misclassified as revision gap");
        runtime.accept(def("BTN", 1, "BUTTON", "GO", "Go", "addr-btn", Map.of()));
        eq(5L, runtime.revision(), "queued patches drain in order after definition");
        eq(0, runtime.heldPatchCount(), "pending patch queue drained");
        JButton button = find(runtime.rootComponent(), JButton.class);
        eq("Go 2", button.getText(), "second queued patch rendered");
        pass();
    }

    private static void testColdCacheSnapshotWaitsForDefinitions() {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("ROOT", 1, "addr-root"), ref("TITLE", 1, "addr-title")));
        runtime.accept(snapshot(7, List.of(inst("root", "ROOT@1", "", Map.of()), inst("title", "TITLE@1", "root", Map.of("text", "Cold")))));
        eq(-1L, runtime.revision(), "cold-cache snapshot is held");
        runtime.accept(def("ROOT", 1, "PANEL", "", "", "addr-root", Map.of()));
        eq(-1L, runtime.revision(), "snapshot remains held until every exact definition arrives");
        runtime.accept(def("TITLE", 1, "TEXT", "", "", "addr-title", Map.of()));
        eq(7L, runtime.revision(), "held snapshot applies after final definition");
        eq("Cold", find(runtime.rootComponent(), JLabel.class).getText(), "held snapshot rendered");
        pass();
    }

    private static void testUnknownPrimitiveIsContained() {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("MYSTERY", 1, "addr-m")));
        runtime.accept(def("MYSTERY", 1, "TELEPATHIC_ORB", "", "", "addr-m", Map.of()));
        runtime.accept(snapshot(0, List.of(inst("m", "MYSTERY@1", "", Map.of()))));
        eq(0L, runtime.revision(), "unknown primitive still commits as placeholder");
        JPanel panel = (JPanel) runtime.rootComponent();
        eq("wire-ui-unsupported", panel.getName(), "unsupported placeholder");
        pass();
    }

    private static void testButtonActionLeavesEdtThroughQueue() throws Exception {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("BTN", 1, "addr-btn")));
        runtime.accept(def("BTN", 1, "BUTTON", "PAY", "Pay", "addr-btn", Map.of()));
        runtime.accept(snapshot(12, List.of(inst("pay", "BTN@1", "", Map.of()))));
        JButton button = (JButton) runtime.rootComponent();
        SwingUtilities.invokeAndWait(button::doClick);
        runtime.accept(patch(12, 13, List.of(Map.of("op", "SET_SLOT", "instanceId", "pay", "slot", "text", "value", "Paid?"))));
        eq(13L, runtime.revision(), "renderer may advance before transport drains action");
        Map<String, Object> action = runtime.pollAction();
        eq("UI_ACTION", action.get("type"), "action type");
        eq("PAY", action.get("action"), "semantic action");
        eq("pay", action.get("elementInstance"), "server action element field");
        eq(12L, ((Number) action.get("renderedRevision")).longValue(), "action revision captured at click time");
        eq("app", action.get("applicationId"), "application ownership");
        eq("session", action.get("sessionId"), "session ownership");
        eq("ap", action.get("accessPointId"), "access-point ownership");
        pass();
    }

    private static void testSlotPatchMutatesOnEdt() {
        WireSwingRuntime runtime = basicTextRuntime();
        runtime.accept(patch(3, 4, List.of(Map.of("op", "SET_SLOT", "instanceId", "title", "slot", "text", "value", "Patched"))));
        eq(4L, runtime.revision(), "patch revision");
        JLabel label = find(runtime.rootComponent(), JLabel.class);
        eq("Patched", label.getText(), "slot patch rendered");
        pass();
    }

    private static void testTransactionalPatchRejectsBeforeVisualMutation() {
        WireSwingRuntime runtime = basicTextRuntime();
        JLabel before = find(runtime.rootComponent(), JLabel.class);
        eq("Before", before.getText(), "precondition");
        List<Map<String, Object>> ops = List.of(
                Map.of("op", "SET_SLOT", "instanceId", "title", "slot", "text", "value", "Should not appear"),
                Map.of("op", "SET_SLOT", "instanceId", "missing", "slot", "text", "value", "boom"));
        runtime.accept(patch(3, 4, ops));
        eq(3L, runtime.revision(), "invalid plan does not commit");
        JLabel after = find(runtime.rootComponent(), JLabel.class);
        eq("Before", after.getText(), "first operation not partially applied");
        pass();
    }

    private static void testFormCollectsFields() throws Exception {
        Map<String, Object> bindings = new LinkedHashMap<>();
        bindings.put("From", "from"); bindings.put("To", "to");
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("SEARCH", 1, "addr-search")));
        runtime.accept(def("SEARCH", 1, "FORM", "SEARCH.SUBMIT", "Search", "addr-search", Map.of("bindings", bindings)));
        runtime.accept(snapshot(5, List.of(inst("search", "SEARCH@1", "", Map.of("from", "LHR", "to", "IOM")))));
        JPanel form = (JPanel) runtime.rootComponent();
        JTextField[] fields = findAll(form, JTextField.class).toArray(JTextField[]::new);
        eq(2, fields.length, "form field count");
        JButton submit = find(form, JButton.class);
        SwingUtilities.invokeAndWait(submit::doClick);
        Map<String, Object> action = runtime.pollAction();
        Map<String, Object> detail = castMap(action.get("detail"));
        eq("LHR", detail.get("from"), "form from");
        eq("IOM", detail.get("to"), "form to");
        check(!detail.containsKey("From") && !detail.containsKey("To"), "projection aliases must not duplicate semantic action fields");
        pass();
    }


    private static void testBuilderCompiledTopLevelBindingsAreAccepted() throws Exception {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("BUILDER_FORM", 1, "addr-builder-form")));
        Map<String, Object> definition = msg("UI_DEFINITION", Map.ofEntries(
                Map.entry("definitionId", "BUILDER_FORM"),
                Map.entry("definitionVersion", 1),
                Map.entry("definitionKey", "BUILDER_FORM@1"),
                Map.entry("primitive", "FORM"),
                Map.entry("action", "SEARCH.SUBMIT"),
                Map.entry("contentAddress", "addr-builder-form"),
                Map.entry("profile", "HUMAN_VISUAL"),
                Map.entry("bindings", Map.of("origin", "origin", "destination", "destination")),
                Map.entry("metadata", Map.of("compositionHints", List.of(Map.of("layoutModel", "GRID12", "placement", Map.of("order", 10, "span", 12, "rowSpan", 1, "align", "STRETCH", "region", "main")))))));
        runtime.accept(definition);
        runtime.accept(snapshot(29, List.of(inst("search", "BUILDER_FORM@1", "", Map.of("origin", "PIK", "destination", "EWR")))));
        java.util.ArrayList<JTextField> fields = findAll(runtime.rootComponent(), JTextField.class);
        eq(2, fields.size(), "Builder top-level bindings produce form fields");
        JButton submit = find(runtime.rootComponent(), JButton.class);
        SwingUtilities.invokeAndWait(submit::doClick);
        Map<String, Object> detail = castMap(runtime.pollAction().get("detail"));
        eq("PIK", detail.get("origin"), "Builder origin binding");
        eq("EWR", detail.get("destination"), "Builder destination binding");
        pass();
    }

    private static void testChoiceListPreservesServerIdentityAsString() throws Exception {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("EXTRAS", 1, "addr-extras")));
        Map<String, Object> bindings = new LinkedHashMap<>();
        bindings.put("saleId", "saleId");
        bindings.put("CABIN_BAG", "CABIN_BAG");
        bindings.put("CHECKED_BAG", "CHECKED_BAG");
        runtime.accept(def("EXTRAS", 1, "CHOICE_LIST", "ANCILLARY.SAVE", "Continue", "addr-extras", Map.of("bindings", bindings)));
        runtime.accept(snapshot(30, List.of(inst("extras", "EXTRAS@1", "", Map.of("saleId", "SALE-1", "CABIN_BAG", true, "CHECKED_BAG", false)))));
        java.util.ArrayList<JCheckBox> boxes = findAll(runtime.rootComponent(), JCheckBox.class);
        eq(2, boxes.size(), "server identity must not become a checkbox");
        SwingUtilities.invokeAndWait(() -> boxes.get(1).setSelected(true));
        JButton submit = find(runtime.rootComponent(), JButton.class);
        SwingUtilities.invokeAndWait(submit::doClick);
        Map<String, Object> detail = castMap(runtime.pollAction().get("detail"));
        eq("SALE-1", detail.get("saleId"), "saleId remains exact string server identity");
        eq(Boolean.TRUE, detail.get("CABIN_BAG"), "first choice remains boolean");
        eq(Boolean.TRUE, detail.get("CHECKED_BAG"), "edited choice remains boolean");
        pass();
    }

    private static void testSemanticRecordMessageIsActionField() throws Exception {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("ASK", 1, "addr-ask")));
        Map<String, Object> bindings = new LinkedHashMap<>();
        bindings.put("message", "message");
        bindings.put("answer", "answer");
        runtime.accept(def("ASK", 1, "SEMANTIC_RECORD", "ASSISTANT.ASK", "Assistant", "addr-ask", Map.of("bindings", bindings)));
        runtime.accept(snapshot(31, List.of(inst("ask", "ASK@1", "", Map.of("message", "old question", "answer", "server answer")))));
        JTextField message = find(runtime.rootComponent(), JTextField.class);
        eq("old question", message.getText(), "semantic record message is editable");
        SwingUtilities.invokeAndWait(() -> message.setText("new question"));
        JButton send = find(runtime.rootComponent(), JButton.class);
        eq("Send", send.getText(), "semantic record action follows browser adapter label");
        SwingUtilities.invokeAndWait(send::doClick);
        Map<String, Object> detail = castMap(runtime.pollAction().get("detail"));
        eq("new question", detail.get("message"), "semantic record returns edited message");
        check(!detail.containsKey("answer"), "read-only server answer must not be echoed as action detail");
        pass();
    }

    private static void testActionableCollectionReturnsOnlyServerIdentity() throws Exception {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("OFFERS", 1, "addr-offers")));
        runtime.accept(def("OFFERS", 1, "OFFER_LIST", "FLIGHT.SELECT", "", "addr-offers", Map.of()));
        List<Map<String, Object>> offers = List.of(
                Map.of("offerId", "OFF-7", "origin", "PIK", "destination", "EWR", "fare", "199.00", "currency", "GBP"),
                Map.of("offerId", "OFF-8", "fare", "249.00", "currency", "GBP"));
        runtime.accept(snapshot(32, List.of(inst("offers", "OFFERS@1", "", Map.of("offers", offers)))));
        JList<?> list = find(runtime.rootComponent(), JList.class);
        SwingUtilities.invokeAndWait(() -> {
            list.setSelectedIndex(0);
            Action activate = list.getActionMap().get("wire.activate");
            activate.actionPerformed(new java.awt.event.ActionEvent(list, java.awt.event.ActionEvent.ACTION_PERFORMED, "test"));
        });
        Map<String, Object> detail = castMap(runtime.pollAction().get("detail"));
        eq(0, ((Number) detail.get("index")).intValue(), "collection index");
        eq("OFF-7", detail.get("offerId"), "collection server identity");
        check(!detail.containsKey("item") && !detail.containsKey("fare") && !detail.containsKey("origin"), "collection action must not echo presentation object");
        pass();
    }

    private static void testGrid12CompositionAllocation() {
        Map<String, Object> leftMeta = composition(10, 6, "STRETCH");
        Map<String, Object> rightMeta = composition(20, 6, "STRETCH");
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("ROOT", 1, "r"), ref("LEFT", 1, "l"), ref("RIGHT", 1, "rr")));
        runtime.accept(def("ROOT", 1, "PANEL", "", "", "r", Map.of()));
        runtime.accept(def("LEFT", 1, "BUTTON", "", "Left", "l", leftMeta));
        runtime.accept(def("RIGHT", 1, "BUTTON", "", "Right", "rr", rightMeta));
        runtime.accept(snapshot(1, List.of(inst("root", "ROOT@1", "", Map.of()), inst("left", "LEFT@1", "root", Map.of()), inst("right", "RIGHT@1", "root", Map.of()))));
        JPanel root = (JPanel) runtime.rootComponent();
        java.util.ArrayList<JButton> buttons = findAll(root, JButton.class);
        eq(2, buttons.size(), "composition button count");
        GridBagLayout layout = (GridBagLayout) root.getLayout();
        GridBagConstraints a = layout.getConstraints(buttons.get(0));
        GridBagConstraints b = layout.getConstraints(buttons.get(1));
        eq(0, a.gridx, "left gridx"); eq(6, a.gridwidth, "left span");
        eq(6, b.gridx, "right gridx"); eq(6, b.gridwidth, "right span");
        pass();
    }

    private static void testGrid12RowSpanAdvancesWholeRow() {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("ROOT", 1, "r"), ref("A", 1, "a"), ref("B", 1, "b"), ref("C", 1, "c")));
        runtime.accept(def("ROOT", 1, "PANEL", "", "", "r", Map.of()));
        runtime.accept(def("A", 1, "BUTTON", "", "A", "a", composition(10, 6, 2, "STRETCH")));
        runtime.accept(def("B", 1, "BUTTON", "", "B", "b", composition(20, 6, 1, "STRETCH")));
        runtime.accept(def("C", 1, "BUTTON", "", "C", "c", composition(30, 12, 1, "STRETCH")));
        runtime.accept(snapshot(1, List.of(inst("root", "ROOT@1", "", Map.of()), inst("a", "A@1", "root", Map.of()), inst("b", "B@1", "root", Map.of()), inst("c", "C@1", "root", Map.of()))));
        JPanel root = (JPanel) runtime.rootComponent();
        java.util.ArrayList<JButton> buttons = findAll(root, JButton.class);
        GridBagLayout layout = (GridBagLayout) root.getLayout();
        eq(0, layout.getConstraints(buttons.get(0)).gridy, "rowspan item row");
        eq(2, layout.getConstraints(buttons.get(2)).gridy, "next row must clear tallest sibling rowspan");
        pass();
    }

    private static void testStructuralInsertPreservesLocalInput() throws Exception {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("ROOT", 1, "r"), ref("INPUT", 1, "i"), ref("NOTE", 1, "n")));
        runtime.accept(def("ROOT", 1, "PANEL", "", "", "r", Map.of()));
        runtime.accept(def("INPUT", 1, "INPUT", "", "", "i", composition(20, 12, "STRETCH")));
        runtime.accept(def("NOTE", 1, "TEXT", "", "", "n", composition(10, 12, "STRETCH")));
        runtime.accept(snapshot(2, List.of(inst("root", "ROOT@1", "", Map.of()), inst("input", "INPUT@1", "root", Map.of("value", "server")))));
        JTextField fieldBefore = find(runtime.rootComponent(), JTextField.class);
        SwingUtilities.invokeAndWait(() -> fieldBefore.setText("local-unsent"));
        runtime.accept(patch(2, 3, List.of(Map.of("op", "CREATE_INSTANCE", "instance", inst("note", "NOTE@1", "root", Map.of("text", "Inserted"))))));
        JTextField fieldAfter = find(runtime.rootComponent(), JTextField.class);
        check(fieldBefore == fieldAfter, "structural relayout must preserve component identity");
        eq("local-unsent", fieldAfter.getText(), "local unsent edit preserved");
        pass();
    }

    private static void testSnapshotKeepsStableHostComponent() {
        WireSwingRuntime runtime = basicTextRuntime();
        JPanel before = runtime.hostComponent();
        runtime.accept(snapshot(20, List.of(inst("root", "ROOT@1", "", Map.of()), inst("title", "TITLE@1", "root", Map.of("text", "Replacement snapshot")))));
        JPanel after = runtime.hostComponent();
        check(before == after, "desktop shell host must remain stable across snapshot replacement");
        eq("Replacement snapshot", find(after, JLabel.class).getText(), "stable host contains replacement snapshot");
        pass();
    }

    private static void testPatchViewMismatchResyncs() {
        WireSwingRuntime runtime = basicTextRuntime();
        Map<String, Object> wrongView = msg("UI_VIEW_PATCH", Map.of("viewRef", "other-view", "previousRevision", 3, "newRevision", 4,
                "operations", List.of(Map.of("op", "SET_SLOT", "instanceId", "title", "slot", "text", "value", "Wrong view"))));
        runtime.accept(wrongView);
        eq(3L, runtime.revision(), "wrong-view patch must not commit");
        List<Map<String, Object>> outbound = runtime.drainOutbound();
        check(outbound.stream().anyMatch(m -> "UI_ERROR".equals(m.get("type")) && "PATCH_VIEW_MISMATCH".equals(m.get("code"))), "view mismatch error");
        check(outbound.stream().anyMatch(m -> "UI_RESYNC_REQUEST".equals(m.get("type"))), "view mismatch resync");
        pass();
    }

    private static void testNullListItemActionIsContained() throws Exception {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("LIST", 1, "list")));
        runtime.accept(def("LIST", 1, "LIST", "SELECT", "", "list", Map.of()));
        java.util.ArrayList<Object> items = new java.util.ArrayList<>(); items.add(null); items.add("second");
        Map<String, Object> slots = new LinkedHashMap<>(); slots.put("items", items);
        runtime.accept(snapshot(9, List.of(inst("list", "LIST@1", "", slots))));
        JList<?> list = find(runtime.rootComponent(), JList.class);
        SwingUtilities.invokeAndWait(() -> {
            list.setSelectedIndex(0);
            list.getActionMap().get("wire.activate").actionPerformed(new java.awt.event.ActionEvent(list, 0, "test"));
        });
        Map<String, Object> action = runtime.pollAction();
        check(action != null, "explicit activation of null list item still queues action");
        Map<String, Object> detail = castMap(action.get("detail"));
        check(detail.containsKey("value") && detail.get("value") == null, "null list item preserved without EDT exception");
        pass();
    }

    private static void testManifestRequiresExpectedContentAddress() {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("SAFE", 1, "sha256:expected")));
        runtime.accept(def("SAFE", 1, "TEXT", "", "Safe", "", Map.of()));
        eq(0, runtime.definitionCount(), "manifest address must not accept blank definition address");
        check(hasOutbound(runtime, "UI_ERROR", "DEFINITION_NOT_AUTHORISED_BY_MANIFEST"), "manifest address rejection expected");
        runtime.accept(def("SAFE", 1, "TEXT", "", "Safe", "sha256:expected", Map.of()));
        eq(1, runtime.definitionCount(), "exact manifest content address accepted");
        pass();
    }

    private static void testInboundMessagesAreDefensivelyFrozen() {
        WireSwingRuntime runtime = new WireSwingRuntime();
        java.util.ArrayList<Object> stages = new java.util.ArrayList<>();
        stages.add("SEARCH");
        Map<String, Object> plan = msg("UI_JOURNEY_PLAN", Map.of("journeyId", "J1", "stages", stages));
        runtime.accept(plan);
        stages.add("PAY");
        Map<String, Object> retained = runtime.lastJourneyPlan();
        @SuppressWarnings("unchecked")
        List<Object> retainedStages = (List<Object>) retained.get("stages");
        eq(1, retainedStages.size(), "caller mutation must not rewrite retained Wire message");
        eq("SEARCH", retainedStages.get(0), "retained journey stage");
        pass();
    }

    private static void testCyclicInboundValueIsContained() {
        WireSwingRuntime runtime = new WireSwingRuntime();
        Map<String, Object> cyclic = new LinkedHashMap<>();
        cyclic.put("type", "UI_JOURNEY_PLAN");
        cyclic.put("protocolVersion", "WIRE-UI/0.1");
        cyclic.put("self", cyclic);
        runtime.accept(cyclic);
        check(hasOutbound(runtime, "UI_ERROR", "WIRE_MESSAGE_INVALID"), "cyclic message must be reported, not overflow the runtime");
        pass();
    }


    private static void testFormLabelDoesNotRenameContinueAction() {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("FORM", 1, "form")));
        runtime.accept(def("FORM", 1, "FORM", "GO", "Search flights", "form", Map.of("bindings", Map.of("query", "query"))));
        runtime.accept(snapshot(1, List.of(inst("form", "FORM@1", "", Map.of("query", "wire")))));
        JButton button = find(runtime.rootComponent(), JButton.class);
        eq("Continue", button.getText(), "rich form submit text follows browser semantic adapter");
        pass();
    }

    private static void testFormEnterQueuesSemanticAction() throws Exception {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("FORM", 1, "form")));
        runtime.accept(def("FORM", 1, "FORM", "SEARCH", "Ignored title", "form", Map.of("bindings", Map.of("query", "query"))));
        runtime.accept(snapshot(4, List.of(inst("form", "FORM@1", "", Map.of("query", "before")))));
        JTextField field = find(runtime.rootComponent(), JTextField.class);
        SwingUtilities.invokeAndWait(() -> { field.setText("after"); field.postActionEvent(); });
        Map<String, Object> action = runtime.pollAction();
        check(action != null, "enter in form field queues semantic action");
        eq("SEARCH", action.get("action"), "enter action semantic name");
        eq("after", castMap(action.get("detail")).get("query"), "enter action captures current field value");
        eq(4L, ((Number) action.get("renderedRevision")).longValue(), "enter action captures event-time revision");
        pass();
    }

    private static void testCollectionPresentationKeepsAuthorityNarrow() throws Exception {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("LIST", 1, "list")));
        runtime.accept(def("LIST", 1, "OFFER_LIST", "SELECT", "", "list", Map.of()));
        Map<String, Object> offer = Map.of("offerId", "offer-17", "label", "Flexible fare", "secret", "must-not-return");
        runtime.accept(snapshot(8, List.of(inst("offers", "LIST@1", "", Map.of("offers", List.of(offer))))));
        JList<?> list = find(runtime.rootComponent(), JList.class);
        final String[] rendered = new String[1];
        SwingUtilities.invokeAndWait(() -> {
            rendered[0] = renderedListText(list, 0);
            list.setSelectedIndex(0);
            list.getActionMap().get("wire.activate").actionPerformed(new java.awt.event.ActionEvent(list, 0, "test"));
        });
        eq("Flexible fare", rendered[0], "collection map uses human-facing label");
        Map<String, Object> detail = castMap(runtime.pollAction().get("detail"));
        eq(2, detail.size(), "collection action remains narrow despite richer renderer text");
        eq(0, ((Number) detail.get("index")).intValue(), "collection index");
        eq("offer-17", detail.get("offerId"), "server identity returned");
        check(!detail.containsKey("secret") && !detail.containsKey("label"), "display data is not echoed as authority detail");
        pass();
    }

    private static void testHeadingStyleRoleIsPresentationOnly() {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("TITLE", 1, "title")));
        Map<String, Object> definition = def("TITLE", 1, "TEXT", "", "Visible heading", "title", Map.of("styleRole", "page-heading"));
        runtime.accept(definition);
        runtime.accept(snapshot(2, List.of(inst("title", "TITLE@1", "", Map.of("text", "Heading")))));
        JLabel label = find(runtime.rootComponent(), JLabel.class);
        check(label.getFont().isBold(), "heading style role affects Swing presentation");
        eq("Heading", label.getText(), "style role does not rewrite semantic value");
        check(runtime.pollAction() == null, "presentation role creates no application action");
        pass();
    }

    private static void testStandaloneDemoJourneyAuthorityIsOutsideRenderer() throws Exception {
        WireSwingRuntime runtime = WireSwingStandaloneDemo.createRuntime();
        eq("SEARCH", runtime.viewRef(), "demo begins at search");
        JButton continueButton = findButton(runtime.rootComponent(), "Continue");
        SwingUtilities.invokeAndWait(continueButton::doClick);
        eq("SEARCH", runtime.viewRef(), "renderer must not navigate itself after UI event");
        Map<String, Object> action = runtime.pollAction();
        eq("FLIGHT.SEARCH", action.get("action"), "renderer emits semantic search action");
        WireSwingStandaloneDemo.handleAction(runtime, action);
        eq("SUMMARY", runtime.viewRef(), "external demo authority supplies summary snapshot");
        check(findButton(runtime.rootComponent(), "Book this fare") != null, "summary snapshot is visibly distinct");
        pass();
    }

    private static void testServerOrderedCollectionAppendMovePreservesIdentity() {
        WireSwingRuntime runtime = structuralCollectionRuntime();
        runtime.accept(patch(0, 1, List.of(Map.of(
                "op", "LIST_APPEND", "parentInstanceId", "positions", "index", 0,
                "instance", inst("row-a", "ROW@1", "", Map.of())))));
        runtime.accept(patch(1, 2, List.of(Map.of(
                "op", "LIST_APPEND", "parentInstanceId", "positions", "index", 1,
                "instance", inst("row-b", "ROW@1", "", Map.of())))));
        JPanel mount = structuralCollectionMount(runtime);
        Component rowA = mount.getComponent(0);
        Component rowB = mount.getComponent(1);
        runtime.accept(patch(2, 3, List.of(Map.of(
                "op", "LIST_MOVE", "parentInstanceId", "positions", "childInstanceId", "row-b", "index", 0))));
        eq(3L, runtime.revision(), "list move revision");
        check(mount.getComponent(0) == rowB && mount.getComponent(1) == rowA, "server list order is rendered exactly");
        check(mount.getComponent(0) == rowB, "retained row component identity survives list move");
        pass();
    }

    private static void testServerOrderedCollectionDestroyThenRemove() {
        WireSwingRuntime runtime = structuralCollectionRuntime();
        runtime.accept(patch(0, 1, List.of(Map.of(
                "op", "LIST_APPEND", "parentInstanceId", "positions", "index", 0,
                "instance", inst("row-a", "ROW@1", "", Map.of())))));
        runtime.accept(patch(1, 2, List.of(Map.of(
                "op", "CREATE_INSTANCE", "instance", inst("chip", "CHIP@1", "row-a", Map.of("text", "Risk"))))));
        JPanel mount = structuralCollectionMount(runtime);
        Component row = mount.getComponent(0);
        runtime.accept(patch(2, 3, List.of(
                Map.of("op", "DESTROY_INSTANCE", "instanceId", "chip"),
                Map.of("op", "LIST_REMOVE", "parentInstanceId", "positions", "childInstanceId", "row-a"))));
        eq(3L, runtime.revision(), "destroy/remove revision");
        check(mount.getComponentCount() == 0, "collection row removed after explicit descendant destroy");
        check(row.getParent() == null, "removed row detached from live Swing tree");
        pass();
    }

    private static void testListRemoveWithLiveDescendantRejectsTransaction() {
        WireSwingRuntime runtime = structuralCollectionRuntime();
        runtime.accept(patch(0, 1, List.of(Map.of(
                "op", "LIST_APPEND", "parentInstanceId", "positions", "index", 0,
                "instance", inst("row-a", "ROW@1", "", Map.of())))));
        runtime.accept(patch(1, 2, List.of(Map.of(
                "op", "CREATE_INSTANCE", "instance", inst("chip", "CHIP@1", "row-a", Map.of("text", "Risk"))))));
        JPanel mount = structuralCollectionMount(runtime);
        Component row = mount.getComponent(0);
        runtime.drainOutbound();
        runtime.accept(patch(2, 3, List.of(Map.of(
                "op", "LIST_REMOVE", "parentInstanceId", "positions", "childInstanceId", "row-a"))));
        eq(2L, runtime.revision(), "invalid list remove does not advance revision");
        check(mount.getComponent(0) == row, "invalid list remove leaves visual tree unchanged");
        check(hasOutbound(runtime, "UI_ERROR", "PATCH_INVALID"), "invalid list remove is reported before mutation");
        pass();
    }

    private static void testListAppendWaitsForExactDefinition() {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("ROOT", 1, "root"), ref("COLL", 1, "coll"), ref("ROW", 1, "row")));
        runtime.accept(def("ROOT", 1, "PANEL", "", "", "root", Map.of()));
        runtime.accept(def("COLL", 1, "SEMANTIC_COLLECTION", "", "", "coll", Map.of()));
        runtime.accept(snapshot(0, List.of(inst("root", "ROOT@1", "", Map.of()), inst("positions", "COLL@1", "root", Map.of()))));
        runtime.accept(patch(0, 1, List.of(Map.of(
                "op", "LIST_APPEND", "parentInstanceId", "positions", "index", 0,
                "instance", inst("row-a", "ROW@1", "", Map.of())))));
        eq(0L, runtime.revision(), "list append waits for missing exact row definition");
        eq(1, runtime.heldPatchCount(), "list append held behind definition barrier");
        check(hasOutbound(runtime, "UI_DEFINITION_REQUIRED", null, null), "list append requests exact definition");
        runtime.accept(def("ROW", 1, "PANEL", "", "", "row", Map.of()));
        eq(1L, runtime.revision(), "held list append replays after exact definition arrives");
        check(structuralCollectionMount(runtime).getComponentCount() >= 1, "replayed list append materialises row");
        pass();
    }


    private static void testCollectionSelectionIsLocalUntilExplicitActivation() throws Exception {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("OFFERS", 1, "addr-offers")));
        runtime.accept(def("OFFERS", 1, "OFFER_LIST", "FLIGHT.SELECT", "", "addr-offers", Map.of()));
        runtime.accept(snapshot(1, List.of(inst("offers", "OFFERS@1", "", Map.of("offers", List.of(Map.of("offerId", "A", "label", "A")))))));
        JList<?> list = find(runtime.rootComponent(), JList.class);
        SwingUtilities.invokeAndWait(() -> list.setSelectedIndex(0));
        eq(null, runtime.pollAction(), "selection alone is local presentation state");
        SwingUtilities.invokeAndWait(() -> list.getActionMap().get("wire.activate").actionPerformed(new java.awt.event.ActionEvent(list, 0, "enter")));
        eq("A", castMap(runtime.pollAction().get("detail")).get("offerId"), "explicit activation emits stable server identity");
        pass();
    }

    private static void testCollectionSelectionSurvivesReorderByServerIdentity() throws Exception {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("OFFERS", 1, "addr-offers")));
        runtime.accept(def("OFFERS", 1, "OFFER_LIST", "FLIGHT.SELECT", "", "addr-offers", Map.of()));
        List<Map<String,Object>> first = List.of(Map.of("offerId", "A", "label", "Alpha"), Map.of("offerId", "B", "label", "Beta"));
        runtime.accept(snapshot(4, List.of(inst("offers", "OFFERS@1", "", Map.of("offers", first)))));
        JList<?> list = find(runtime.rootComponent(), JList.class);
        SwingUtilities.invokeAndWait(() -> list.setSelectedIndex(1));
        List<Map<String,Object>> second = List.of(Map.of("offerId", "B", "label", "Beta changed"), Map.of("offerId", "A", "label", "Alpha"));
        runtime.accept(patch(4, 5, List.of(Map.of("op", "SET_SLOT", "instanceId", "offers", "slot", "offers", "value", second))));
        eq(0, list.getSelectedIndex(), "selection follows stable server identity after reorder");
        eq(null, runtime.pollAction(), "refresh/reorder does not activate selection");
        runtime.accept(patch(5, 6, List.of(Map.of("op", "SET_SLOT", "instanceId", "offers", "slot", "offers", "value", List.of(Map.of("offerId", "A", "label", "Alpha"))))));
        eq(-1, list.getSelectedIndex(), "selection drops silently if server identity disappears");
        pass();
    }

    private static void testInlineRenderProfileManifestRequestsColdDefinitions() {
        WireSwingRuntime runtime = new WireSwingRuntime();
        runtime.hello("app", "session", "ap");
        runtime.accept(msg("UI_RENDER_PROFILE", Map.of("profileId", "swing-large-fine", "manifestId", "inline-1", "definitions", List.of(ref("BTN", 1, "addr-btn")))));
        List<Map<String,Object>> out = runtime.drainOutbound();
        check(out.stream().anyMatch(m -> "UI_DEFINITION_REQUIRED".equals(m.get("type"))), "inline render profile proactively requests exact cold definitions");
        runtime.accept(def("BTN", 1, "BUTTON", "GO", "Go", "addr-btn", Map.of()));
        eq(1, runtime.definitionCount(), "exact definition cached after inline profile request");
        pass();
    }

    private static void testManifestDeauthorisationKeepsCacheAndBlocksActions() throws Exception {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("BTN", 1, "addr-btn"), ref("OTHER", 1, "addr-other")));
        runtime.accept(def("BTN", 1, "BUTTON", "GO", "Go", "addr-btn", Map.of()));
        runtime.accept(def("OTHER", 1, "TEXT", "", "", "addr-other", Map.of()));
        runtime.accept(snapshot(1, List.of(inst("go", "BTN@1", "", Map.of()))));
        runtime.drainOutbound();
        runtime.accept(msg("UI_DEFINITION_MANIFEST", Map.of("manifestId", "m2", "profileId", "swing-large-fine", "definitions", List.of(ref("OTHER", 1, "addr-other")))));
        eq(2, runtime.definitionCount(), "deauthorisation does not prune immutable cache");
        JButton button = (JButton) runtime.rootComponent();
        SwingUtilities.invokeAndWait(button::doClick);
        eq(null, runtime.pollAction(), "deauthorised committed pixels cannot emit actions");
        List<Map<String,Object>> out = runtime.drainOutbound();
        check(out.stream().anyMatch(m -> "UI_ERROR".equals(m.get("type")) && "COMMITTED_VIEW_DEAUTHORISED".equals(m.get("code"))), "deauthorisation emits scoped error");
        check(out.stream().anyMatch(m -> "UI_RESYNC_REQUEST".equals(m.get("type"))), "deauthorisation requests resync");
        pass();
    }

    private static void testWarmReauthorisationUsesRetainedDefinitionCache() {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("BTN", 1, "addr-btn"), ref("OTHER", 1, "addr-other")));
        runtime.accept(def("BTN", 1, "BUTTON", "GO", "Go", "addr-btn", Map.of()));
        runtime.accept(def("OTHER", 1, "TEXT", "", "", "addr-other", Map.of()));
        runtime.accept(snapshot(1, List.of(inst("go", "BTN@1", "", Map.of()))));
        runtime.drainOutbound();
        runtime.accept(msg("UI_DEFINITION_MANIFEST", Map.of("manifestId", "m2", "profileId", "swing-large-fine", "definitions", List.of(ref("OTHER", 1, "addr-other")))));
        runtime.drainOutbound();
        runtime.accept(msg("UI_DEFINITION_MANIFEST", Map.of("manifestId", "m3", "profileId", "swing-large-fine", "definitions", List.of(ref("BTN", 1, "addr-btn")))));
        eq(2, runtime.definitionCount(), "warm reauthorisation retains exact cache entry");
        check(runtime.drainOutbound().stream().noneMatch(m -> "UI_DEFINITION_REQUIRED".equals(m.get("type"))), "warm reauthorisation must not re-request retained exact definition");
        pass();
    }

    private static void testRenderProfileManifestMismatchFailsClosed() {
        WireSwingRuntime runtime = new WireSwingRuntime();
        runtime.accept(msg("UI_RENDER_PROFILE", Map.of("profileId", "profile-a")));
        runtime.accept(msg("UI_DEFINITION_MANIFEST", Map.of("manifestId", "wrong-profile", "profileId", "profile-b", "definitions", List.of(ref("BTN", 1, "addr-btn")))));
        check(hasOutbound(runtime, "UI_ERROR", "RENDER_PROFILE_MANIFEST_MISMATCH"), "manifest bound to a different render profile must fail closed");
        eq(0, runtime.definitionCount(), "profile mismatch cannot authorise definition content");
        pass();
    }

    private static void testProfileIdIsNotDefinitionContentIdentity() {
        WireSwingRuntime runtime = new WireSwingRuntime();
        runtime.accept(msg("UI_RENDER_PROFILE", Map.of("profileId", "profile-a")));
        runtime.accept(msg("UI_DEFINITION_MANIFEST", Map.of("manifestId", "ma", "profileId", "profile-a", "definitions", List.of(ref("BTN", 1, "same")))));
        runtime.accept(defWithProfile("BTN", 1, "BUTTON", "GO", "Go", "same", "profile-a", Map.of()));
        runtime.accept(msg("UI_RENDER_PROFILE", Map.of("profileId", "profile-b")));
        runtime.accept(msg("UI_DEFINITION_MANIFEST", Map.of("manifestId", "mb", "profileId", "profile-b", "definitions", List.of(ref("BTN", 1, "same")))));
        runtime.accept(defWithProfile("BTN", 1, "BUTTON", "GO", "Go", "same", "profile-b", Map.of()));
        eq(1, runtime.definitionCount(), "delivery profile is not immutable definition content");
        check(runtime.drainOutbound().stream().noneMatch(m -> "DEFINITION_IMMUTABILITY_VIOLATION".equals(m.get("code"))), "profile change must not look like definition mutation");
        pass();
    }

    private static void testWorkspaceContextOpaqueEventTimePassthrough() throws Exception {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("BTN", 1, "addr-btn")));
        runtime.accept(def("BTN", 1, "BUTTON", "POSITION.BULK.CLOSE", "Close", "addr-btn", Map.of()));
        Map<String,Object> contextA = workspaceContext("POSITIONS", 1, List.of("P1"), Map.of("resultRevision", 7L, "resultCurrent", true, "futureField", Map.of("nested", List.of("x", 2L))));
        runtime.accept(snapshot(10, List.of(inst("close", "BTN@1", "", Map.of("workspaceRef", "POSITIONS", "workspaceContext", contextA)))));
        JButton button = (JButton) runtime.rootComponent();
        SwingUtilities.invokeAndWait(button::doClick);
        Map<String,Object> contextB = workspaceContext("POSITIONS", 2, List.of("P2"), Map.of("resultRevision", 8L, "futureField", "later"));
        runtime.accept(patch(10, 11, List.of(Map.of("op", "SET_SLOT", "instanceId", "close", "slot", "workspaceContext", "value", contextB))));
        Map<String,Object> first = runtime.pollAction();
        eq(10L, ((Number)first.get("renderedRevision")).longValue(), "workspace action revision captured at event time");
        eq(contextA, castMap(castMap(first.get("detail")).get("workspaceContext")), "queued action retains opaque event-time workspace context including future fields");
        SwingUtilities.invokeAndWait(button::doClick);
        Map<String,Object> second = runtime.pollAction();
        eq(contextB, castMap(castMap(second.get("detail")).get("workspaceContext")), "later click uses newly projected workspace context");
        pass();
    }

    private static void testWorkspaceContextMissingFailsClosed() throws Exception {
        WireSwingRuntime runtime = workspaceButtonRuntime(Map.of("workspaceRef", "POSITIONS"));
        SwingUtilities.invokeAndWait(((JButton)runtime.rootComponent())::doClick);
        eq(null, runtime.pollAction(), "workspace-bound action without context is blocked");
        check(hasOutbound(runtime, "UI_ERROR", "WORKSPACE_CONTEXT_REQUIRED"), "missing workspace context error");
        pass();
    }

    private static void testWorkspaceContextMismatchFailsClosed() throws Exception {
        Map<String,Object> slots = Map.of("workspaceRef", "POSITIONS", "workspaceContext", workspaceContext("ORDERS", 1, List.of(), Map.of()));
        WireSwingRuntime runtime = workspaceButtonRuntime(slots);
        SwingUtilities.invokeAndWait(((JButton)runtime.rootComponent())::doClick);
        eq(null, runtime.pollAction(), "mismatched workspace context is blocked");
        check(hasOutbound(runtime, "UI_ERROR", "WORKSPACE_CONTEXT_MISMATCH"), "workspaceRef mismatch error");
        pass();
    }

    private static void testWorkspaceContextCannotBeForgedByLocalDetail() throws Exception {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("COLL", 1, "addr-coll")));
        runtime.accept(def("COLL", 1, "OFFER_LIST", "POSITION.BULK.CLOSE", "", "addr-coll", Map.of()));
        Map<String,Object> authoritative = workspaceContext("POSITIONS", 5, List.of("SERVER-1"), Map.of("future", "kept"));
        runtime.accept(snapshot(2, List.of(inst("positions", "COLL@1", "", Map.of(
                "workspaceRef", "POSITIONS", "workspaceContext", authoritative,
                "offers", List.of(Map.of("id", "LOCAL-ROW", "label", "Locally highlighted")))))));
        JList<?> list = find(runtime.rootComponent(), JList.class);
        SwingUtilities.invokeAndWait(() -> {
            list.setSelectedIndex(0);
            list.getActionMap().get("wire.activate").actionPerformed(new java.awt.event.ActionEvent(list, 0, "test"));
        });
        Map<String,Object> detail = castMap(runtime.pollAction().get("detail"));
        eq("LOCAL-ROW", detail.get("id"), "local activated row identity remains ordinary action detail");
        eq(List.of("SERVER-1"), castMap(detail.get("workspaceContext")).get("selectedIds"), "server projected selectedIds cannot be forged from local selection");
        pass();
    }


    private static void testMaterialExactIdentityAndSiteReleaseProvenance() {
        WireSwingRuntime runtime = new WireSwingRuntime();
        Map<String,Object> tokens = Map.of("brand.accent", "#4f46e5", "brand.ink", "#172033", "surface", "#ffffff", "space.unit", 8);
        Map<String,Object> recipes = Map.of("primary", "surface/action");
        runtime.accept(material("MAT", "1", "addr-mat", tokens, recipes, Map.of("releaseId", "A")));
        runtime.accept(material("MAT", "1", "addr-mat", tokens, recipes, Map.of("releaseId", "B")));
        eq(1, runtime.materialCount(), "same exact material remains one cached identity across release provenance");
        eq("MAT@1", runtime.materialKey(), "current exact material key");
        check(runtime.drainOutbound().stream().noneMatch(m -> "MATERIAL_IMMUTABILITY_VIOLATION".equals(m.get("code"))), "site release provenance is not immutable material content");
        pass();
    }

    private static void testMaterialMutationRejected() {
        WireSwingRuntime runtime = new WireSwingRuntime();
        runtime.accept(material("MAT", "1", "addr-mat", Map.of("space.unit", 8), Map.of(), Map.of()));
        runtime.drainOutbound();
        runtime.accept(material("MAT", "1", "addr-mat", Map.of("space.unit", 10), Map.of(), Map.of()));
        eq(1, runtime.materialCount(), "mutated same-key material does not replace cached content");
        check(hasOutbound(runtime, "UI_ERROR", "MATERIAL_IMMUTABILITY_VIOLATION"), "material immutable content mutation rejected");
        pass();
    }

    private static void testMaterialReappliesWithoutReplacingComponent() {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("BTN", 1, "btn")));
        runtime.accept(def("BTN", 1, "BUTTON", "GO", "Go", "btn", Map.of("materialRole", "primary")));
        runtime.accept(snapshot(1, List.of(inst("go", "BTN@1", "", Map.of()))));
        JButton before = (JButton) runtime.rootComponent();
        runtime.accept(material("MAT", "1", "mat", Map.of("brand.accent", "#4f46e5", "space.unit", 8), Map.of("primary", "surface/action"), Map.of()));
        JButton after = (JButton) runtime.rootComponent();
        check(before == after, "material refresh preserves Swing component identity and local widget state");
        eq("MAT@1", after.getClientProperty("wire.materialKey"), "material applied to existing component");
        eq("surface/action", after.getClientProperty("wire.materialRecipe"), "semantic recipe exposed without executing arbitrary recipe code");
        pass();
    }

    private static void testManifestIdReuseAndBlankAddressRejected() {
        WireSwingRuntime runtime = new WireSwingRuntime();
        runtime.accept(msg("UI_RENDER_PROFILE", Map.of("profileId", "p")));
        runtime.accept(msg("UI_DEFINITION_MANIFEST", Map.of("manifestId", "same", "profileId", "p", "definitions", List.of(ref("A", 1, "a")))));
        runtime.drainOutbound();
        runtime.accept(msg("UI_DEFINITION_MANIFEST", Map.of("manifestId", "same", "profileId", "p", "definitions", List.of(ref("A", 1, "b")))));
        check(hasOutbound(runtime, "UI_ERROR", "DEFINITION_MANIFEST_ID_REUSE"), "same manifest id cannot name different exact contents");
        runtime.accept(msg("UI_DEFINITION_MANIFEST", Map.of("manifestId", "blank", "profileId", "p", "definitions", List.of(ref("B", 1, "")))));
        check(hasOutbound(runtime, "UI_ERROR", "DEFINITION_MANIFEST_INVALID"), "blank manifest content address rejected");
        pass();
    }

    private static void testTypedFieldHintsKeepStringSemantics() throws Exception {
        Map<String,Object> bindings = new LinkedHashMap<>();
        bindings.put("travelDate", "travelDate"); bindings.put("passengerCount", "passengerCount"); bindings.put("email", "email");
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("FORM", 1, "form")));
        runtime.accept(def("FORM", 1, "FORM", "SUBMIT", "", "form", Map.of("bindings", bindings)));
        runtime.accept(snapshot(3, List.of(inst("form", "FORM@1", "", Map.of("travelDate", "2026-09-01", "passengerCount", "2", "email", "a@example.test")))));
        java.util.ArrayList<JTextField> fields=findAll(runtime.rootComponent(), JTextField.class);
        eq("date", fields.get(0).getClientProperty("wire.inputType"), "date presentation hint");
        eq("number", fields.get(1).getClientProperty("wire.inputType"), "number presentation hint");
        eq("email", fields.get(2).getClientProperty("wire.inputType"), "email presentation hint");
        SwingUtilities.invokeAndWait(find(runtime.rootComponent(), JButton.class)::doClick);
        Map<String,Object> detail=castMap(runtime.pollAction().get("detail"));
        check(detail.get("passengerCount") instanceof String, "typed presentation hint does not coerce semantic submitted value");
        eq("2", detail.get("passengerCount"), "number-like value remains browser-parity string");
        pass();
    }

    private static WireSwingRuntime workspaceButtonRuntime(Map<String,Object> slots) {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(ref("BTN", 1, "addr-btn")));
        runtime.accept(def("BTN", 1, "BUTTON", "POSITION.BULK.CLOSE", "Close", "addr-btn", Map.of()));
        runtime.accept(snapshot(1, List.of(inst("close", "BTN@1", "", slots))));
        runtime.drainOutbound();
        return runtime;
    }

    private static Map<String,Object> workspaceContext(String ref, long selectionRevision, List<String> selectedIds, Map<String,Object> extra) {
        Map<String,Object> c = new LinkedHashMap<>();
        c.put("workspaceRef", ref); c.put("queryRevision", 11L); c.put("scopeRevision", 12L); c.put("orderRevision", 13L);
        c.put("selectionRevision", selectionRevision); c.put("selectedIds", selectedIds); c.putAll(extra); return c;
    }

    private static WireSwingRuntime structuralCollectionRuntime() {
        WireSwingRuntime runtime = baseRuntimeWithManifest(List.of(
                ref("ROOT", 1, "root"), ref("COLL", 1, "coll"), ref("ROW", 1, "row"), ref("CHIP", 1, "chip")));
        runtime.accept(def("ROOT", 1, "PANEL", "", "", "root", Map.of()));
        runtime.accept(def("COLL", 1, "SEMANTIC_COLLECTION", "", "", "coll", Map.of()));
        runtime.accept(def("ROW", 1, "PANEL", "", "", "row", Map.of()));
        runtime.accept(def("CHIP", 1, "TEXT", "", "", "chip", Map.of()));
        runtime.accept(snapshot(0, List.of(
                inst("root", "ROOT@1", "", Map.of()),
                inst("positions", "COLL@1", "root", Map.of()))));
        return runtime;
    }

    private static JPanel structuralCollectionMount(WireSwingRuntime runtime) {
        JScrollPane pane = find(runtime.rootComponent(), JScrollPane.class);
        Component view = pane.getViewport().getView();
        if (!(view instanceof JPanel panel)) throw new AssertionError("structural collection mount is not active");
        return panel;
    }

    private static Map<String, Object> composition(long order, long span, String align) { return composition(order, span, 1, align); }
    private static Map<String, Object> composition(long order, long span, long rowSpan, String align) {
        Map<String, Object> placement = Map.of("order", order, "span", span, "rowSpan", rowSpan, "align", align, "region", "main");
        Map<String, Object> hint = Map.of("layoutModel", "GRID12", "stateId", "STATE", "placement", placement);
        return Map.of("compositionHints", List.of(hint));
    }

    private static WireSwingRuntime basicTextRuntime() {
        WireSwingRuntime runtime = baseRuntime();
        runtime.accept(def("ROOT", 1, "PANEL", "", "", "addr-root", Map.of()));
        runtime.accept(def("TITLE", 1, "TEXT", "", "", "addr-title", Map.of()));
        runtime.accept(snapshot(3, List.of(inst("root", "ROOT@1", "", Map.of()), inst("title", "TITLE@1", "root", Map.of("text", "Before")))));
        return runtime;
    }

    private static WireSwingRuntime baseRuntime() {
        return baseRuntimeWithManifest(List.of(ref("ROOT", 1, "addr-root"), ref("TITLE", 1, "addr-title"), ref("BTN", 1, "addr-btn")));
    }

    private static WireSwingRuntime baseRuntimeWithManifest(List<Map<String, Object>> refs) {
        WireSwingRuntime runtime = new WireSwingRuntime();
        runtime.hello("app", "session", "ap");
        runtime.accept(msg("UI_RENDER_PROFILE", Map.of("profileId", "swing-large-fine")));
        runtime.accept(msg("UI_DEFINITION_MANIFEST", Map.of("manifestId", "m1", "profileId", "swing-large-fine", "definitions", refs)));
        return runtime;
    }

    private static Map<String, Object> def(String id, long version, String primitive, String action, String label, String address, Map<String, Object> metadata) {
        return msg("UI_DEFINITION", Map.of("definitionId", id, "definitionVersion", version, "definitionKey", id + "@" + version,
                "primitive", primitive, "action", action, "label", label, "styleRole", "", "contentAddress", address,
                "profileId", "swing-large-fine", "metadata", metadata));
    }

    private static Map<String, Object> defWithProfile(String id, long version, String primitive, String action, String label, String address, String profile, Map<String, Object> metadata) {
        return msg("UI_DEFINITION", Map.of("definitionId", id, "definitionVersion", version, "definitionKey", id + "@" + version,
                "primitive", primitive, "action", action, "label", label, "styleRole", "", "contentAddress", address,
                "profileId", profile, "metadata", metadata));
    }
    private static Map<String, Object> ref(String id, long version, String address) { return Map.of("id", id, "version", version, "contentAddress", address); }
    private static Map<String, Object> inst(String id, String key, String parent, Map<String, Object> slots) { return Map.of("instanceId", id, "definitionKey", key, "parentId", parent, "slots", slots); }
    private static Map<String, Object> snapshot(long revision, List<Map<String, Object>> instances) { return msg("UI_VIEW_SNAPSHOT", Map.of("viewRef", "view-1", "revision", revision, "rootInstanceId", instances.get(0).get("instanceId"), "instances", instances)); }
    private static Map<String, Object> patch(long previous, long next, List<Map<String, Object>> ops) { return msg("UI_VIEW_PATCH", Map.of("viewRef", "view-1", "previousRevision", previous, "newRevision", next, "operations", ops)); }

    private static Map<String,Object> material(String id, String version, String address, Map<String,Object> tokens, Map<String,Object> recipes, Map<String,Object> siteRelease) {
        Map<String,Object> fields = new LinkedHashMap<>(); fields.put("materialId", id); fields.put("version", version); fields.put("contentAddress", address);
        fields.put("tokens", tokens); fields.put("recipes", recipes); fields.put("siteRelease", siteRelease);
        return msg("UI_MATERIAL_SET", fields);
    }

    private static Map<String, Object> msg(String type, Map<String, Object> fields) {
        Map<String, Object> m = new LinkedHashMap<>(); m.put("type", type); m.put("protocolVersion", "WIRE-UI/0.1"); m.putAll(fields); return m;
    }

    private static boolean hasOutbound(WireSwingRuntime runtime, String type, String... codes) {
        for (Map<String, Object> m : runtime.drainOutbound()) {
            if (!type.equals(m.get("type"))) continue;
            if (codes == null || codes.length == 0 || codes[0] == null) return true;
            for (String c : codes) if (c != null && c.equals(m.get("code"))) return true;
        }
        return false;
    }

    @SuppressWarnings({"rawtypes", "unchecked"})
    private static String renderedListText(JList<?> list, int index) {
        ListCellRenderer renderer = list.getCellRenderer();
        Component cell = renderer.getListCellRendererComponent(
                list, list.getModel().getElementAt(index), index, false, false);
        return ((JLabel) cell).getText();
    }

    @SuppressWarnings("unchecked") private static Map<String, Object> castMap(Object o) { return (Map<String, Object>) o; }

    private static JButton findButton(Component root, String text) {
        if (root instanceof JButton button && text.equals(button.getText())) return button;
        if (root instanceof Container c) {
            for (Component child : c.getComponents()) {
                JButton found = findButtonOrNull(child, text);
                if (found != null) return found;
            }
        }
        throw new AssertionError("button not found: " + text);
    }

    private static JButton findButtonOrNull(Component root, String text) {
        if (root instanceof JButton button && text.equals(button.getText())) return button;
        if (root instanceof Container c) {
            for (Component child : c.getComponents()) {
                JButton found = findButtonOrNull(child, text);
                if (found != null) return found;
            }
        }
        return null;
    }

    private static <T extends Component> T find(Component root, Class<T> type) {
        if (type.isInstance(root)) return type.cast(root);
        if (root instanceof Container c) for (Component child : c.getComponents()) { T found = findOrNull(child, type); if (found != null) return found; }
        throw new AssertionError("not found: " + type.getSimpleName());
    }
    private static <T extends Component> T findOrNull(Component root, Class<T> type) {
        if (type.isInstance(root)) return type.cast(root);
        if (root instanceof Container c) for (Component child : c.getComponents()) { T found = findOrNull(child, type); if (found != null) return found; }
        return null;
    }
    private static <T extends Component> java.util.ArrayList<T> findAll(Component root, Class<T> type) {
        java.util.ArrayList<T> out = new java.util.ArrayList<>(); collect(root, type, out); return out;
    }
    private static <T extends Component> void collect(Component root, Class<T> type, java.util.List<T> out) {
        if (type.isInstance(root)) out.add(type.cast(root));
        if (root instanceof Container c) for (Component child : c.getComponents()) collect(child, type, out);
    }

    private static void eq(Object expected, Object actual, String label) { if (!java.util.Objects.equals(expected, actual)) throw new AssertionError(label + ": expected=" + expected + " actual=" + actual); }
    private static void check(boolean value, String label) { if (!value) throw new AssertionError(label); }
    private static void pass() { tests++; }
}
