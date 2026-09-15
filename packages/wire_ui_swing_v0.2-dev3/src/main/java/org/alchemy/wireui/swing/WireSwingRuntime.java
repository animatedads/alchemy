package org.alchemy.wireui.swing;

import javax.swing.JComponent;
import javax.swing.JPanel;
import java.awt.Container;
import java.awt.GridBagConstraints;
import java.awt.GridBagLayout;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Deque;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.time.Duration;
import java.util.Objects;
import java.util.Set;

/**
 * Defensive WIRE-UI/0.1 -> Swing renderer boundary.
 * Swing state is private to this runtime. Server state/journey/action authority is never inferred here.
 */
public final class WireSwingRuntime {
    /** Static factory kept intentionally simple for BSF4ooRexx reflection compatibility. */
    public static WireSwingRuntime create() { return new WireSwingRuntime(); }

    private final Object lock = new Object();
    private final WireSwingEdt edt = new WireSwingEdt();
    private final WireSwingComponentFactory componentFactory = new WireSwingComponentFactory();
    private final WireSwingLayoutEngine layoutEngine = new WireSwingLayoutEngine();
    private final WireSwingActionQueue actions = new WireSwingActionQueue();
    private final Deque<Map<String, Object>> outbound = new ArrayDeque<>();
    private final Map<String, WireDefinition> definitions = new LinkedHashMap<>();
    private final List<Map<String, Object>> pendingPatches = new ArrayList<>();
    private final JPanel stableHost = edt.call(() -> new JPanel(new java.awt.BorderLayout()));
    private WireDefinitionManifest manifest = WireDefinitionManifest.empty();
    private WireViewModel model = WireViewModel.empty();
    private WireSwingRenderTree tree = new WireSwingRenderTree(stableHost);
    private Map<String, Object> pendingSnapshot;
    private boolean waitingForResync;
    private String renderProfileId = "";
    private String applicationId = "";
    private String sessionId = "";
    private String accessPointId = "";
    private Map<String, Object> lastJourneyPlan = Map.of();

    public Map<String, Object> hello(String applicationId, String sessionId, String accessPointId) {
        String app = normalise(applicationId);
        String session = normalise(sessionId);
        String accessPoint = normalise(accessPointId);
        synchronized (lock) {
            this.applicationId = app;
            this.sessionId = session;
            this.accessPointId = accessPoint;
        }
        Map<String, Object> hello = WireSwingProtocol.message(WireSwingProtocol.UI_HELLO);
        if (!app.isBlank()) hello.put("applicationId", app);
        if (!session.isBlank()) hello.put("sessionId", session);
        if (!accessPoint.isBlank()) hello.put("accessPointId", accessPoint);
        Map<String, Object> capabilities = new LinkedHashMap<>();
        capabilities.put("viewportClass", "LARGE");
        capabilities.put("pointer", "FINE");
        capabilities.put("uiToolkit", "JAVA_SWING");
        capabilities.put("javaFeatureVersion", Runtime.version().feature());
        hello.put("renderCapabilities", capabilities);
        hello.put("capabilityFingerprint", "java-swing-" + Runtime.version().feature());
        return deepCopyMap(hello);
    }

    public void accept(Map<String, Object> message) {
        Objects.requireNonNull(message, "message");
        final Map<String, Object> stable;
        try { stable = deepCopyMap(message); }
        catch (RuntimeException ex) { emitError("WIRE_MESSAGE_INVALID", "RUNTIME", ex.getMessage(), Map.of()); return; }
        String protocol = WireValues.text(stable, "protocolVersion", WireSwingProtocol.VERSION);
        if (!WireSwingProtocol.VERSION.equals(protocol)) {
            emitError("PROTOCOL_VERSION_UNSUPPORTED", "RUNTIME", protocol, Map.of("protocolVersion", protocol));
            return;
        }
        String type = WireValues.text(stable, "type", "");
        switch (type) {
            case WireSwingProtocol.UI_RENDER_PROFILE -> acceptRenderProfile(stable);
            case WireSwingProtocol.UI_DEFINITION_MANIFEST -> acceptManifest(stable);
            case WireSwingProtocol.UI_DEFINITION -> acceptDefinition(stable);
            case WireSwingProtocol.UI_VIEW_SNAPSHOT -> acceptSnapshot(stable);
            case WireSwingProtocol.UI_VIEW_PATCH -> acceptPatch(stable);
            case WireSwingProtocol.UI_JOURNEY_PLAN -> { synchronized (lock) { lastJourneyPlan = stable; } }
            default -> emitError("UNSUPPORTED_MESSAGE", "RUNTIME", "Unsupported inbound message: " + type, Map.of("type", type));
        }
    }

    public void acceptDefinition(Map<String, Object> message) {
        WireDefinition definition;
        try { definition = WireDefinition.fromWire(message); }
        catch (RuntimeException ex) { emitError("DEFINITION_INVALID", "COMPONENT", ex.getMessage(), Map.of()); return; }
        synchronized (lock) {
            if (!manifest.contentAddresses().isEmpty() && !manifest.allows(definition)) {
                emitErrorLocked("DEFINITION_NOT_AUTHORISED_BY_MANIFEST", "COMPONENT", definition.definitionKey(), Map.of("definitionKey", definition.definitionKey()));
                return;
            }
            WireDefinition prior = definitions.get(definition.definitionKey());
            if (prior != null && !sameDefinition(prior, definition)) {
                emitErrorLocked("DEFINITION_IMMUTABILITY_VIOLATION", "COMPONENT", definition.definitionKey(), Map.of("definitionKey", definition.definitionKey()));
                return;
            }
            definitions.putIfAbsent(definition.definitionKey(), definition);
        }
        drainPendingSnapshotAndPatches();
    }

    public void acceptSnapshot(Map<String, Object> message) {
        acceptSnapshotInternal(message, false);
    }

    private void acceptSnapshotInternal(Map<String, Object> message, boolean preserveQueuedPatches) {
        final Map<String, Object> stable;
        try { stable = deepCopyMap(message); }
        catch (RuntimeException ex) { emitError("WIRE_MESSAGE_INVALID", "RUNTIME", ex.getMessage(), Map.of()); return; }

        WireViewModel proposed;
        try {
            proposed = parseSnapshot(stable);
            validateStructure(proposed);
        } catch (RuntimeException ex) {
            String code = ex instanceof WireSwingException wse ? wse.code() : "SNAPSHOT_INVALID";
            emitError(code, "PATCH", ex.getMessage(), Map.of());
            synchronized (lock) { if (preserveQueuedPatches) pendingSnapshot = null; }
            return;
        }

        Set<String> missing = missingDefinitions(proposed.instances().values());
        if (!missing.isEmpty()) {
            synchronized (lock) {
                if (!preserveQueuedPatches) pendingPatches.clear();
                pendingSnapshot = stable;
            }
            requestDefinitions(missing);
            return;
        }

        WireSwingRenderTree proposedTree;
        try { proposedTree = edt.call(() -> buildTree(proposed)); }
        catch (RuntimeException ex) {
            emitError("SNAPSHOT_RENDER_FAILED", "SUBTREE", ex.getMessage(), Map.of("viewRef", proposed.viewRef()));
            synchronized (lock) { if (preserveQueuedPatches) pendingSnapshot = null; }
            return;
        }

        try { edt.run(() -> installSnapshot(proposedTree, proposed, preserveQueuedPatches)); }
        catch (RuntimeException ex) {
            emitError("SNAPSHOT_INSTALL_FAILED", "SUBTREE", ex.getMessage(), Map.of("viewRef", proposed.viewRef()));
            return;
        }
        if (preserveQueuedPatches) drainPendingPatches();
    }

    public void acceptPatch(Map<String, Object> patch) {
        final Map<String, Object> stable;
        try { stable = deepCopyMap(patch); }
        catch (RuntimeException ex) { emitError("WIRE_MESSAGE_INVALID", "RUNTIME", ex.getMessage(), Map.of()); return; }

        long previous = WireValues.longValue(stable, "previousRevision", Long.MIN_VALUE);
        long next = WireValues.longValue(stable, "newRevision", Long.MIN_VALUE);
        String patchViewRef = WireValues.text(stable, "viewRef", "");
        String expectedViewRef;
        long expectedPrevious;
        WireViewModel current;
        synchronized (lock) {
            if (waitingForResync) return;
            current = model;
            if (pendingSnapshot != null) {
                expectedViewRef = WireValues.text(pendingSnapshot, "viewRef", current.viewRef());
                expectedPrevious = WireValues.longValue(pendingSnapshot, "revision", current.revision());
            } else {
                expectedViewRef = current.viewRef();
                expectedPrevious = current.revision();
            }
            if (!pendingPatches.isEmpty()) expectedPrevious = WireValues.longValue(pendingPatches.get(pendingPatches.size() - 1), "newRevision", expectedPrevious);
        }

        if (!patchViewRef.isBlank() && !expectedViewRef.isBlank() && !patchViewRef.equals(expectedViewRef)) {
            emitError("PATCH_VIEW_MISMATCH", "PATCH", patchViewRef + " != " + expectedViewRef, Map.of("viewRef", expectedViewRef));
            requestResync(current, previous);
            return;
        }
        if (previous != expectedPrevious) {
            requestResync(current, previous);
            return;
        }
        if (next <= previous) {
            emitError("PATCH_REVISION_INVALID", "PATCH", previous + " -> " + next, Map.of());
            requestResync(current, previous);
            return;
        }

        synchronized (lock) { pendingPatches.add(stable); }
        drainPendingPatches();
    }

    public JComponent rootComponent() {
        synchronized (lock) { return tree.root == null ? tree.host : tree.root; }
    }

    public JPanel hostComponent() { synchronized (lock) { return tree.host; } }
    public long revision() { synchronized (lock) { return model.revision(); } }
    public String viewRef() { synchronized (lock) { return model.viewRef(); } }
    public String renderProfileId() { synchronized (lock) { return renderProfileId; } }
    public int definitionCount() { synchronized (lock) { return definitions.size(); } }
    public int heldPatchCount() { synchronized (lock) { return pendingPatches.size(); } }
    public Map<String, Object> lastJourneyPlan() { synchronized (lock) { return deepCopyMap(lastJourneyPlan); } }
    public Map<String, Object> pollAction() { return actions.poll(); }
    public Map<String, Object> pollAction(long timeoutMillis) throws InterruptedException {
        if (timeoutMillis < 0) throw new IllegalArgumentException("timeoutMillis must be >= 0");
        return actions.poll(Duration.ofMillis(timeoutMillis));
    }

    /** Capture renderer revision at the UI event boundary, not when the transport later drains it. */
    private void queueAction(Map<String, Object> action) {
        synchronized (lock) {
            Map<String, Object> enriched = new LinkedHashMap<>(action);
            if (!applicationId.isBlank()) enriched.put("applicationId", applicationId);
            if (!sessionId.isBlank()) enriched.put("sessionId", sessionId);
            if (!accessPointId.isBlank()) enriched.put("accessPointId", accessPointId);
            enriched.put("viewRef", model.viewRef());
            enriched.put("renderedRevision", model.revision());
            actions.offer(deepCopyMap(enriched));
        }
    }

    public List<Map<String, Object>> drainOutbound() {
        synchronized (lock) {
            List<Map<String, Object>> result = new ArrayList<>(outbound);
            outbound.clear();
            return Collections.unmodifiableList(result);
        }
    }

    private void acceptRenderProfile(Map<String, Object> message) {
        synchronized (lock) { renderProfileId = WireValues.text(message, "profileId", WireValues.text(message, "renderProfileId", "")); }
    }

    private void acceptManifest(Map<String, Object> message) {
        String manifestId = WireValues.text(message, "manifestId", "");
        String profileId = WireValues.text(message, "profileId", renderProfileId);
        Map<String, String> refs = new LinkedHashMap<>();
        Object raw = message.containsKey("definitions") ? message.get("definitions") : message.get("entries");
        for (Map<String, Object> ref : WireValues.mapList(raw)) {
            String id = WireValues.text(ref, "id", WireValues.text(ref, "definitionId", ""));
            long version = WireValues.longValue(ref, "version", WireValues.longValue(ref, "definitionVersion", -1));
            if (!id.isBlank() && version >= 1) refs.put(id + "@" + version, WireValues.text(ref, "contentAddress", ""));
        }
        synchronized (lock) {
            manifest = new WireDefinitionManifest(manifestId, profileId, refs);
            definitions.entrySet().removeIf(e -> !manifest.allows(e.getValue()));
        }
    }

    private WireViewModel parseSnapshot(Map<String, Object> message) {
        String viewRef = WireValues.text(message, "viewRef", "");
        long revision = WireValues.longValue(message, "revision", -1);
        String root = WireValues.text(message, "rootInstanceId", WireValues.text(message, "rootInstance", ""));
        if (revision < 0) throw new IllegalArgumentException("snapshot revision is required");
        Map<String, WireInstance> instances = new LinkedHashMap<>();
        Object raw = message.containsKey("instances") ? message.get("instances") : message.get("elementInstances");
        for (Map<String, Object> row : WireValues.mapList(raw)) {
            WireInstance instance = WireInstance.fromWire(row);
            if (instances.putIfAbsent(instance.instanceId(), instance) != null) throw new IllegalArgumentException("duplicate instance " + instance.instanceId());
        }
        return new WireViewModel(viewRef, revision, root, instances);
    }

    private PatchPlan planPatch(WireViewModel base, Map<String, Object> patch, long next) {
        Map<String, WireInstance> proposed = new LinkedHashMap<>(base.instances());
        List<PlannedOperation> ops = new ArrayList<>();
        Set<String> missing = new LinkedHashSet<>();
        for (Map<String, Object> op : WireValues.mapList(patch.get("operations"))) {
            String kind = WireValues.text(op, "op", "");
            switch (kind) {
                case "CREATE_INSTANCE" -> {
                    WireInstance i = WireInstance.fromWire(WireValues.map(op.get("instance")));
                    if (proposed.containsKey(i.instanceId())) throw new IllegalArgumentException("instance exists: " + i.instanceId());
                    if (!i.parentInstanceId().isBlank() && !proposed.containsKey(i.parentInstanceId())) throw new IllegalArgumentException("parent missing: " + i.parentInstanceId());
                    synchronized (lock) { if (!definitions.containsKey(i.definitionKey())) missing.add(i.definitionKey()); }
                    proposed.put(i.instanceId(), i); ops.add(new CreateOperation(i));
                }
                case "SET_SLOT" -> {
                    String id = WireValues.text(op, "instanceId", "");
                    String slot = WireValues.text(op, "slot", "");
                    if (!proposed.containsKey(id)) throw new IllegalArgumentException("instance missing: " + id);
                    if (slot.isBlank()) throw new IllegalArgumentException("slot is required");
                    Object value = op.get("value");
                    proposed.put(id, proposed.get(id).withSlot(slot, value)); ops.add(new SlotOperation(id, slot, value));
                }
                default -> throw new IllegalArgumentException("unsupported patch op: " + kind);
            }
        }
        WireViewModel proposedView = new WireViewModel(base.viewRef(), next, base.rootInstanceId(), proposed);
        validateStructure(proposedView);
        if (!missing.isEmpty()) throw new MissingDefinitionException(missing);
        return new PatchPlan(base, proposedView, ops);
    }

    private WireSwingRenderTree buildTree(WireViewModel view) {
        WireSwingEdt.requireEdt();
        WireSwingRenderTree result = new WireSwingRenderTree();
        for (WireInstance instance : view.instances().values()) {
            WireDefinition definition = definition(instance.definitionKey());
            WireSwingComponentBinding binding = componentFactory.create(definition, instance, this::queueAction);
            applyInitialSlots(binding, instance);
            result.bindings.put(instance.instanceId(), binding);
            if (instance.instanceId().equals(view.rootInstanceId())) result.root = binding.component();
        }
        relayoutParent(result, view, "");
        for (WireInstance instance : view.instances().values()) {
            if (hasChildren(view, instance.instanceId())) relayoutParent(result, view, instance.instanceId());
        }
        if (result.root == null && result.host.getComponentCount() == 1 && result.host.getComponent(0) instanceof JComponent jc) result.root = jc;
        if (result.root == null) result.root = result.host;
        return result;
    }

    private void commitPatchVisual(PatchPlan plan) {
        WireSwingEdt.requireEdt();
        WireSwingRenderTree current;
        synchronized (lock) { current = tree; }

        Map<String, WireSwingComponentBinding> created = new LinkedHashMap<>();
        Set<String> affectedParents = new LinkedHashSet<>();
        for (PlannedOperation op : plan.operations) {
            if (!(op instanceof CreateOperation create)) continue;
            WireInstance instance = create.instance;
            WireDefinition definition = definition(instance.definitionKey());
            WireSwingComponentBinding binding = componentFactory.create(definition, instance, this::queueAction);
            applyInitialSlots(binding, instance);
            created.put(instance.instanceId(), binding);
            affectedParents.add(instance.parentInstanceId());
        }

        if (!created.isEmpty()) {
            current.bindings.putAll(created);
            try {
                for (String parentId : affectedParents) relayoutParent(current, plan.proposed, parentId);
            } catch (RuntimeException ex) {
                for (String id : created.keySet()) current.bindings.remove(id);
                for (String parentId : affectedParents) relayoutParent(current, plan.base, parentId);
                throw ex;
            }
        }

        for (PlannedOperation op : plan.operations) {
            if (!(op instanceof SlotOperation slot)) continue;
            WireSwingComponentBinding binding = current.bindings.get(slot.instanceId);
            if (binding == null) throw new WireSwingException("INSTANCE_NOT_RENDERED", slot.instanceId);
            try { binding.applySlot(slot.slot, slot.value); }
            catch (RuntimeException ex) {
                emitError("SLOT_RENDER_FAILED", "PROPERTY", ex.getMessage(), Map.of("instanceId", slot.instanceId, "slot", slot.slot));
            }
        }
        current.host.revalidate(); current.host.repaint();
    }

    private void installSnapshot(WireSwingRenderTree proposedTree, WireViewModel proposed, boolean preserveQueuedPatches) {
        WireSwingEdt.requireEdt();
        WireSwingRenderTree priorTree;
        WireViewModel priorModel;
        synchronized (lock) { priorTree = tree; priorModel = model; }

        WireSwingRenderTree committed = new WireSwingRenderTree(stableHost);
        committed.bindings.putAll(proposedTree.bindings);
        committed.root = proposedTree.root == proposedTree.host ? stableHost : proposedTree.root;
        try {
            relayoutParent(committed, proposed, "");
        } catch (RuntimeException ex) {
            try { relayoutParent(priorTree, priorModel, ""); }
            catch (RuntimeException ignored) { stableHost.removeAll(); }
            throw ex;
        }
        synchronized (lock) {
            model = proposed;
            tree = committed;
            pendingSnapshot = null;
            waitingForResync = false;
            if (!preserveQueuedPatches) pendingPatches.clear();
        }
    }

    private void applyInitialSlots(WireSwingComponentBinding binding, WireInstance instance) {
        for (Map.Entry<String, Object> slot : instance.slots().entrySet()) {
            try { binding.applySlot(slot.getKey(), slot.getValue()); }
            catch (RuntimeException ex) { emitError("SLOT_RENDER_FAILED", "PROPERTY", ex.getMessage(), Map.of("instanceId", instance.instanceId(), "slot", slot.getKey())); }
        }
    }

    private void relayoutParent(WireSwingRenderTree renderTree, WireViewModel view, String parentId) {
        WireSwingEdt.requireEdt();
        Container target;
        if (parentId.isBlank()) target = renderTree.host;
        else {
            WireSwingComponentBinding parent = renderTree.bindings.get(parentId);
            if (parent == null) throw new WireSwingException("PARENT_NOT_RENDERED", parentId);
            target = layoutTarget(parent.component());
        }

        List<WireInstance> children = childrenOf(view, parentId);
        target.removeAll();
        WireSwingLayoutEngine.LayoutCursor cursor = layoutEngine.cursor();
        int nextFreeRow = 0;
        for (WireInstance child : children) {
            WireSwingComponentBinding binding = renderTree.bindings.get(child.instanceId());
            if (binding == null) throw new WireSwingException("INSTANCE_NOT_RENDERED", child.instanceId());
            GridBagConstraints constraints = cursor.next(definition(child.definitionKey()));
            nextFreeRow = Math.max(nextFreeRow, constraints.gridy + constraints.gridheight);
            if (target.getLayout() instanceof java.awt.GridBagLayout) target.add(binding.component(), constraints);
            else if (target.getLayout() instanceof java.awt.BorderLayout) {
                if (target.getComponentCount() != 0) throw new WireSwingException("MULTIPLE_VIEW_ROOTS", "desktop host accepts one authoritative root");
                target.add(binding.component(), java.awt.BorderLayout.CENTER);
            } else target.add(binding.component());
        }
        if (target.getLayout() instanceof java.awt.GridBagLayout && !children.isEmpty()) {
            javax.swing.JPanel filler = new javax.swing.JPanel();
            filler.setName("wire-ui-layout-filler");
            filler.setOpaque(false);
            GridBagConstraints fc = new GridBagConstraints();
            fc.gridx = 0; fc.gridy = nextFreeRow; fc.gridwidth = 12; fc.weightx = 1.0; fc.weighty = 1.0; fc.fill = GridBagConstraints.BOTH;
            target.add(filler, fc);
        }
        target.invalidate();
        target.validate();
        target.repaint();
    }

    private List<WireInstance> childrenOf(WireViewModel view, String parentId) {
        List<WireInstance> children = new ArrayList<>();
        Map<String, Integer> insertion = new LinkedHashMap<>();
        int n = 0;
        for (WireInstance instance : view.instances().values()) {
            insertion.put(instance.instanceId(), n++);
            if (instance.parentInstanceId().equals(parentId)) children.add(instance);
        }
        children.sort((a, b) -> {
            long ao = layoutEngine.orderFor(definition(a.definitionKey()), insertion.get(a.instanceId()));
            long bo = layoutEngine.orderFor(definition(b.definitionKey()), insertion.get(b.instanceId()));
            int cmp = Long.compare(ao, bo);
            return cmp != 0 ? cmp : Integer.compare(insertion.get(a.instanceId()), insertion.get(b.instanceId()));
        });
        return children;
    }

    private boolean hasChildren(WireViewModel view, String parentId) {
        for (WireInstance instance : view.instances().values()) if (instance.parentInstanceId().equals(parentId)) return true;
        return false;
    }

    private Container layoutTarget(JComponent parent) {
        if (parent instanceof javax.swing.JScrollPane scroll) return scroll.getViewport();
        return parent;
    }

    private WireDefinition definition(String key) {
        synchronized (lock) {
            WireDefinition d = definitions.get(key);
            if (d == null) throw new WireSwingException("DEFINITION_MISSING", key);
            return d;
        }
    }

    private Set<String> missingDefinitions(Iterable<WireInstance> instances) {
        Set<String> missing = new LinkedHashSet<>();
        synchronized (lock) {
            for (WireInstance i : instances) if (!definitions.containsKey(i.definitionKey())) missing.add(i.definitionKey());
        }
        return missing;
    }

    private void validateStructure(WireViewModel view) {
        if (view.rootInstanceId().isBlank()) throw new WireSwingException("VIEW_ROOT_REQUIRED", "rootInstanceId is required");
        WireInstance root = view.instances().get(view.rootInstanceId());
        if (root == null) throw new WireSwingException("VIEW_ROOT_MISSING", view.rootInstanceId());
        if (!root.parentInstanceId().isBlank()) throw new WireSwingException("VIEW_ROOT_HAS_PARENT", root.instanceId());

        Set<String> seen = new LinkedHashSet<>();
        int topLevel = 0;
        for (WireInstance instance : view.instances().values()) {
            if (instance.parentInstanceId().isBlank()) {
                topLevel++;
                if (!instance.instanceId().equals(view.rootInstanceId())) throw new WireSwingException("MULTIPLE_VIEW_ROOTS", instance.instanceId());
            } else if (!seen.contains(instance.parentInstanceId())) {
                throw new WireSwingException("SNAPSHOT_PARENT_ORDER_INVALID", instance.instanceId() + " -> " + instance.parentInstanceId());
            }
            seen.add(instance.instanceId());
        }
        if (topLevel != 1) throw new WireSwingException("VIEW_ROOT_CARDINALITY_INVALID", String.valueOf(topLevel));
    }

    private void requestDefinitions(Set<String> keys) {
        Map<String, Object> request = WireSwingProtocol.message(WireSwingProtocol.UI_DEFINITION_REQUIRED);
        synchronized (lock) {
            if (!manifest.manifestId().isBlank()) request.put("manifestId", manifest.manifestId());
            if (!manifest.profileId().isBlank()) request.put("profileId", manifest.profileId());
            List<Map<String, Object>> refs = new ArrayList<>();
            for (String key : keys) {
                int at = key.lastIndexOf('@');
                if (at <= 0) continue;
                Map<String, Object> ref = new LinkedHashMap<>();
                ref.put("id", key.substring(0, at));
                try { ref.put("version", Long.parseLong(key.substring(at + 1))); } catch (NumberFormatException ex) { continue; }
                String address = manifest.address(key); if (!address.isBlank()) ref.put("contentAddress", address);
                refs.add(ref);
            }
            request.put("definitions", refs);
            outbound.add(deepCopyMap(request));
        }
    }

    private void requestResync(WireViewModel base, long suppliedPrevious) {
        Map<String, Object> request = WireSwingProtocol.message(WireSwingProtocol.UI_RESYNC_REQUEST);
        request.put("viewRef", base.viewRef());
        request.put("haveRevision", base.revision());
        request.put("receivedPreviousRevision", suppliedPrevious);
        synchronized (lock) {
            waitingForResync = true;
            outbound.add(deepCopyMap(request));
        }
    }

    private void drainPendingSnapshotAndPatches() {
        Map<String, Object> snapshot;
        synchronized (lock) { snapshot = pendingSnapshot; }
        if (snapshot != null) {
            acceptSnapshotInternal(snapshot, true);
            synchronized (lock) { if (pendingSnapshot != null) return; }
        }
        drainPendingPatches();
    }

    private void drainPendingPatches() {
        while (true) {
            Map<String, Object> patch;
            WireViewModel base;
            synchronized (lock) {
                if (waitingForResync || pendingSnapshot != null || pendingPatches.isEmpty()) return;
                patch = pendingPatches.get(0);
                base = model;
            }

            long previous = WireValues.longValue(patch, "previousRevision", Long.MIN_VALUE);
            long next = WireValues.longValue(patch, "newRevision", Long.MIN_VALUE);
            String patchViewRef = WireValues.text(patch, "viewRef", "");
            if ((!patchViewRef.isBlank() && !base.viewRef().isBlank() && !patchViewRef.equals(base.viewRef())) || previous != base.revision()) {
                emitError("PENDING_PATCH_SEQUENCE_INVALID", "PATCH", patchViewRef + " " + previous, Map.of("viewRef", base.viewRef(), "revision", base.revision()));
                requestResync(base, previous);
                return;
            }

            final PatchPlan plan;
            try { plan = planPatch(base, patch, next); }
            catch (MissingDefinitionException ex) { requestDefinitions(ex.keys); return; }
            catch (RuntimeException ex) {
                emitError("PATCH_INVALID", "PATCH", ex.getMessage(), Map.of("viewRef", base.viewRef()));
                requestResync(base, previous);
                return;
            }

            try {
                edt.run(() -> {
                    commitPatchVisual(plan);
                    synchronized (lock) { model = plan.proposed; }
                });
            } catch (RuntimeException ex) {
                emitError("PATCH_RENDER_FAILED", "SUBTREE", ex.getMessage(), Map.of("viewRef", base.viewRef()));
                requestResync(base, previous);
                return;
            }
            synchronized (lock) {
                if (!pendingPatches.isEmpty() && pendingPatches.get(0) == patch) pendingPatches.remove(0);
                else pendingPatches.remove(patch);
            }
        }
    }

    private void emitError(String code, String scope, String detail, Map<String, Object> context) {
        synchronized (lock) { emitErrorLocked(code, scope, detail, context); }
    }

    private void emitErrorLocked(String code, String scope, String detail, Map<String, Object> context) {
        Map<String, Object> error = WireSwingProtocol.message(WireSwingProtocol.UI_ERROR);
        error.put("code", code); error.put("scope", scope); error.put("detail", detail == null ? "" : detail);
        if (context != null && !context.isEmpty()) error.put("context", new LinkedHashMap<>(context));
        outbound.add(deepCopyMap(error));
    }

    private static String normalise(String value) { return value == null ? "" : value.trim(); }

    private static boolean sameDefinition(WireDefinition a, WireDefinition b) {
        return a.definitionKey().equals(b.definitionKey()) && a.primitive().equals(b.primitive()) && a.action().equals(b.action())
                && a.label().equals(b.label()) && a.styleRole().equals(b.styleRole()) && a.contentAddress().equals(b.contentAddress())
                && a.profileId().equals(b.profileId()) && a.metadata().equals(b.metadata());
    }

    private static Map<String, Object> deepCopyMap(Map<String, Object> source) { return WireValues.map(source); }

    private sealed interface PlannedOperation permits CreateOperation, SlotOperation { }
    private static final class CreateOperation implements PlannedOperation { final WireInstance instance; CreateOperation(WireInstance instance) { this.instance = instance; } }
    private static final class SlotOperation implements PlannedOperation { final String instanceId; final String slot; final Object value; SlotOperation(String instanceId, String slot, Object value) { this.instanceId = instanceId; this.slot = slot; this.value = value; } }
    private record PatchPlan(WireViewModel base, WireViewModel proposed, List<PlannedOperation> operations) { }
    private static final class MissingDefinitionException extends RuntimeException {
        private static final long serialVersionUID = 1L;
        transient final Set<String> keys;
        MissingDefinitionException(Set<String> keys) { super(keys.toString()); this.keys = Set.copyOf(keys); }
    }
}
