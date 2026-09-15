package org.alchemy.wireui.swing;

import javax.swing.JComponent;
import javax.swing.JPanel;
import javax.swing.SwingUtilities;
import java.awt.Component;
import java.awt.Container;
import java.awt.KeyboardFocusManager;
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
    private final WireSwingMaterialController materials = new WireSwingMaterialController();
    private final WireSwingLayoutEngine layoutEngine = new WireSwingLayoutEngine();
    private final WireSwingActionQueue actions = new WireSwingActionQueue();
    private final Deque<Map<String, Object>> outbound = new ArrayDeque<>();
    private final Map<String, WireDefinition> definitions = new LinkedHashMap<>();
    private final Map<String, WireDefinitionManifest> seenManifests = new LinkedHashMap<>();
    private final List<Map<String, Object>> pendingPatches = new ArrayList<>();
    private final JPanel stableHost = edt.call(() -> new JPanel(new java.awt.BorderLayout()));
    private WireDefinitionManifest manifest = WireDefinitionManifest.empty();
    private WireViewModel model = WireViewModel.empty();
    private WireSwingRenderTree tree = new WireSwingRenderTree(stableHost);
    private Map<String, Object> pendingSnapshot;
    private boolean waitingForResync;
    private boolean actionsBlockedByAuthority;
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
            case WireSwingProtocol.UI_MATERIAL_SET -> acceptMaterial(stable);
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
            validateParentBeforeChild(proposed);
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
    public int materialCount() { synchronized (lock) { return materials.count(); } }
    public String materialKey() { synchronized (lock) { return materials.current() == null ? "" : materials.current().materialKey(); } }
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
            if (actionsBlockedByAuthority) {
                emitErrorLocked("ACTION_BLOCKED_BY_DEFINITION_AUTHORITY", "ACTION", "Committed view is no longer authorised by the active definition manifest", Map.of("viewRef", model.viewRef(), "revision", model.revision()));
                return;
            }
            Map<String, Object> enriched = new LinkedHashMap<>(action);
            String elementInstance = WireValues.text(enriched, "elementInstance", "");
            WireInstance instance = model.instances().get(elementInstance);
            if (instance == null) {
                emitErrorLocked("ACTION_INSTANCE_NOT_CURRENT", "ACTION", elementInstance, Map.of("viewRef", model.viewRef(), "revision", model.revision()));
                return;
            }
            String workspaceRef = WireValues.text(instance.slots(), "workspaceRef", "").trim();
            if (!workspaceRef.isBlank()) {
                Object rawContext = instance.slots().get("workspaceContext");
                if (!(rawContext instanceof Map<?, ?>)) {
                    emitErrorLocked("WORKSPACE_CONTEXT_REQUIRED", "ACTION", workspaceRef, Map.of("instanceId", elementInstance, "workspaceRef", workspaceRef));
                    return;
                }
                Map<String, Object> context = WireValues.map(rawContext);
                String contextRef = WireValues.text(context, "workspaceRef", "").trim();
                if (!workspaceRef.equals(contextRef)) {
                    emitErrorLocked("WORKSPACE_CONTEXT_MISMATCH", "ACTION", contextRef, Map.of("instanceId", elementInstance, "workspaceRef", workspaceRef));
                    return;
                }
                Map<String, Object> detail = new LinkedHashMap<>(WireValues.map(enriched.get("detail")));
                // Server-projected context is authoritative. Local widgets cannot manufacture or amend it.
                detail.put("workspaceContext", WireValues.freezeValue(context));
                enriched.put("detail", detail);
            }
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

    private void acceptMaterial(Map<String, Object> message) {
        final WireMaterialSet material;
        try { material = WireMaterialSet.fromWire(message); }
        catch (RuntimeException ex) { emitError("MATERIAL_INVALID", "RUNTIME", ex.getMessage(), Map.of()); return; }
        synchronized (lock) {
            try { materials.accept(material); }
            catch (WireSwingException ex) { emitErrorLocked(ex.code(), "RUNTIME", ex.getMessage(), Map.of("materialKey", material.materialKey())); return; }
            componentFactory.setMaterial(materials.current());
        }
        try {
            edt.run(() -> {
                WireSwingRenderTree current; WireViewModel currentModel;
                synchronized (lock) { current=tree; currentModel=model; }
                for (Map.Entry<String, WireSwingComponentBinding> e : current.bindings.entrySet()) {
                    WireInstance instance=currentModel.instances().get(e.getKey());
                    if (instance != null) componentFactory.applyPresentation(definition(instance.definitionKey()), e.getValue().component());
                }
                current.host.revalidate(); current.host.repaint();
            });
        } catch (RuntimeException ex) { emitError("MATERIAL_APPLY_FAILED", "SUBTREE", ex.getMessage(), Map.of("materialKey", material.materialKey())); }
    }

    private void acceptRenderProfile(Map<String, Object> message) {
        String profileId = WireValues.text(message, "profileId", WireValues.text(message, "renderProfileId", "")).trim();
        if (profileId.isBlank()) {
            emitError("RENDER_PROFILE_INVALID", "RUNTIME", "profileId is required", Map.of());
            return;
        }
        synchronized (lock) { renderProfileId = profileId; }
        // Server v0.16+ carries the exact authorised manifest inline in UI_RENDER_PROFILE.
        if (message.containsKey("definitions") || message.containsKey("entries")) acceptManifest(message);
    }

    private void acceptManifest(Map<String, Object> message) {
        final WireDefinitionManifest proposed;
        try { proposed = parseManifest(message); }
        catch (RuntimeException ex) { emitError("DEFINITION_MANIFEST_INVALID", "COMPONENT", ex.getMessage(), Map.of()); return; }

        Set<String> cold = new LinkedHashSet<>();
        boolean committedViewDeauthorised = false;
        synchronized (lock) {
            if (!renderProfileId.isBlank() && !proposed.profileId().isBlank() && !renderProfileId.equals(proposed.profileId())) {
                emitErrorLocked("RENDER_PROFILE_MANIFEST_MISMATCH", "COMPONENT", proposed.profileId() + " != " + renderProfileId, Map.of("manifestId", proposed.manifestId()));
                return;
            }
            WireDefinitionManifest priorSameId = seenManifests.get(proposed.manifestId());
            if (priorSameId != null && !priorSameId.equals(proposed)) {
                emitErrorLocked("DEFINITION_MANIFEST_ID_REUSE", "COMPONENT", proposed.manifestId(), Map.of());
                return;
            }
            for (Map.Entry<String, String> e : proposed.contentAddresses().entrySet()) {
                WireDefinition cached = definitions.get(e.getKey());
                if (cached != null && !e.getValue().equals(cached.contentAddress())) {
                    emitErrorLocked("DEFINITION_CACHE_ADDRESS_CONFLICT", "COMPONENT", e.getKey(), Map.of("cached", cached.contentAddress(), "manifest", e.getValue()));
                    return;
                }
                if (cached == null) cold.add(e.getKey());
            }
            seenManifests.putIfAbsent(proposed.manifestId(), proposed);
            manifest = proposed;
            for (WireInstance instance : model.instances().values()) {
                WireDefinition cached = definitions.get(instance.definitionKey());
                if (cached == null || !proposed.allows(cached)) { committedViewDeauthorised = true; break; }
            }
            if (committedViewDeauthorised && model.revision() >= 0) {
                actionsBlockedByAuthority = true;
                emitErrorLocked("COMMITTED_VIEW_DEAUTHORISED", "SUBTREE", model.viewRef(), Map.of("revision", model.revision(), "manifestId", proposed.manifestId()));
                if (!waitingForResync) {
                    Map<String, Object> request = WireSwingProtocol.message(WireSwingProtocol.UI_RESYNC_REQUEST);
                    request.put("viewRef", model.viewRef()); request.put("haveRevision", model.revision()); request.put("reason", "DEFINITION_AUTHORITY_CHANGED");
                    waitingForResync = true; outbound.add(deepCopyMap(request));
                }
            }
        }
        if (!cold.isEmpty()) requestDefinitions(cold);
    }

    private WireDefinitionManifest parseManifest(Map<String, Object> message) {
        String manifestId = WireValues.text(message, "manifestId", "").trim();
        String profileId = WireValues.text(message, "profileId", renderProfileId).trim();
        if (manifestId.isBlank()) throw new IllegalArgumentException("manifestId is required");
        if (profileId.isBlank()) throw new IllegalArgumentException("profileId is required");
        Map<String, String> refs = new LinkedHashMap<>();
        Object raw = message.containsKey("definitions") ? message.get("definitions") : message.get("entries");
        for (Map<String, Object> ref : WireValues.mapList(raw)) {
            String id = WireValues.text(ref, "id", WireValues.text(ref, "definitionId", "")).trim();
            long version = WireValues.longValue(ref, "version", WireValues.longValue(ref, "definitionVersion", -1));
            String address = WireValues.text(ref, "contentAddress", "").trim();
            if (id.isBlank() || version < 1) throw new IllegalArgumentException("manifest definition id/version invalid");
            if (address.isBlank()) throw new IllegalArgumentException("blank contentAddress for " + id + "@" + version);
            String key = id + "@" + version;
            String prior = refs.putIfAbsent(key, address);
            if (prior != null && !prior.equals(address)) throw new IllegalArgumentException("duplicate exact key with conflicting address: " + key);
        }
        return new WireDefinitionManifest(manifestId, profileId, refs);
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
        return WireViewModel.fromOrderedInstances(viewRef, revision, root, instances);
    }

    private PatchPlan planPatch(WireViewModel base, Map<String, Object> patch, long next) {
        Map<String, WireInstance> proposed = new LinkedHashMap<>(base.instances());
        Map<String, List<String>> order = mutableChildOrder(base);
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
                    proposed.put(i.instanceId(), i);
                    order.computeIfAbsent(i.parentInstanceId(), ignored -> new ArrayList<>()).add(i.instanceId());
                }
                case "SET_SLOT" -> {
                    String id = WireValues.text(op, "instanceId", "");
                    String slot = WireValues.text(op, "slot", "");
                    if (!proposed.containsKey(id)) throw new IllegalArgumentException("instance missing: " + id);
                    if (slot.isBlank()) throw new IllegalArgumentException("slot is required");
                    Object value = op.get("value");
                    proposed.put(id, proposed.get(id).withSlot(slot, value));
                    ops.add(new SlotOperation(id, slot, value));
                }
                case "LIST_APPEND" -> {
                    String parentId = WireValues.text(op, "parentInstanceId", "");
                    if (parentId.isBlank() || !proposed.containsKey(parentId)) throw new IllegalArgumentException("parent missing: " + parentId);
                    List<String> children = order.computeIfAbsent(parentId, ignored -> new ArrayList<>());
                    long rawIndex = WireValues.longValue(op, "index", children.size());
                    if (rawIndex < 0 || rawIndex > children.size() || rawIndex > Integer.MAX_VALUE) throw new IllegalArgumentException("list index invalid: " + rawIndex);
                    int index = (int) rawIndex;
                    Map<String, Object> wireInstance = WireValues.map(op.get("instance"));
                    if (!wireInstance.isEmpty()) {
                        WireInstance i = WireInstance.fromWire(wireInstance).withParent(parentId);
                        if (proposed.containsKey(i.instanceId())) throw new IllegalArgumentException("instance exists: " + i.instanceId());
                        synchronized (lock) { if (!definitions.containsKey(i.definitionKey())) missing.add(i.definitionKey()); }
                        proposed.put(i.instanceId(), i);
                        children.add(index, i.instanceId());
                    } else {
                        String childId = WireValues.text(op, "childInstanceId", "");
                        WireInstance child = proposed.get(childId);
                        if (child == null) throw new IllegalArgumentException("instance missing: " + childId);
                        if (childId.equals(base.rootInstanceId())) throw new IllegalArgumentException("cannot attach declared root: " + childId);
                        List<String> oldSiblings = order.computeIfAbsent(child.parentInstanceId(), ignored -> new ArrayList<>());
                        if (!oldSiblings.remove(childId)) throw new IllegalArgumentException("list membership mismatch: " + childId);
                        if (child.parentInstanceId().equals(parentId) && index > children.size()) index = children.size();
                        children.add(index, childId);
                        proposed.put(childId, child.withParent(parentId));
                    }
                }
                case "LIST_MOVE" -> {
                    String parentId = WireValues.text(op, "parentInstanceId", "");
                    String childId = WireValues.text(op, "childInstanceId", "");
                    if (!proposed.containsKey(parentId)) throw new IllegalArgumentException("parent missing: " + parentId);
                    WireInstance child = proposed.get(childId);
                    if (child == null || !child.parentInstanceId().equals(parentId)) throw new IllegalArgumentException("list membership mismatch: " + childId);
                    List<String> children = order.computeIfAbsent(parentId, ignored -> new ArrayList<>());
                    long rawIndex = WireValues.longValue(op, "index", -1);
                    if (rawIndex < 0 || rawIndex >= children.size() || rawIndex > Integer.MAX_VALUE) throw new IllegalArgumentException("list index invalid: " + rawIndex);
                    if (!children.remove(childId)) throw new IllegalArgumentException("list membership mismatch: " + childId);
                    children.add((int) rawIndex, childId);
                }
                case "DESTROY_INSTANCE" -> {
                    String id = WireValues.text(op, "instanceId", "");
                    WireInstance doomed = proposed.get(id);
                    if (doomed == null) throw new IllegalArgumentException("instance missing: " + id);
                    if (id.equals(base.rootInstanceId())) throw new IllegalArgumentException("cannot destroy declared root: " + id);
                    if (!order.getOrDefault(id, List.of()).isEmpty()) throw new IllegalArgumentException("destroy instance still has children: " + id);
                    List<String> siblings = order.computeIfAbsent(doomed.parentInstanceId(), ignored -> new ArrayList<>());
                    if (!siblings.remove(id)) throw new IllegalArgumentException("parent membership missing: " + id);
                    order.remove(id);
                    proposed.remove(id);
                }
                case "LIST_REMOVE" -> {
                    String parentId = WireValues.text(op, "parentInstanceId", "");
                    String childId = WireValues.text(op, "childInstanceId", "");
                    WireInstance child = proposed.get(childId);
                    if (!proposed.containsKey(parentId)) throw new IllegalArgumentException("parent missing: " + parentId);
                    if (child == null || !child.parentInstanceId().equals(parentId)) throw new IllegalArgumentException("list membership mismatch: " + childId);
                    if (!order.getOrDefault(childId, List.of()).isEmpty()) throw new IllegalArgumentException("list remove child still has descendants: " + childId);
                    List<String> children = order.computeIfAbsent(parentId, ignored -> new ArrayList<>());
                    if (!children.remove(childId)) throw new IllegalArgumentException("list membership mismatch: " + childId);
                    order.remove(childId);
                    proposed.remove(childId);
                }
                default -> throw new IllegalArgumentException("unsupported patch op: " + kind);
            }
        }
        WireViewModel proposedView = new WireViewModel(base.viewRef(), next, base.rootInstanceId(), proposed, order);
        validateStructure(proposedView);
        if (!missing.isEmpty()) throw new MissingDefinitionException(missing);
        return new PatchPlan(base, proposedView, ops);
    }

    private static Map<String, List<String>> mutableChildOrder(WireViewModel view) {
        Map<String, List<String>> copy = new LinkedHashMap<>();
        for (Map.Entry<String, List<String>> entry : view.childOrder().entrySet()) copy.put(entry.getKey(), new ArrayList<>(entry.getValue()));
        return copy;
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

        Map<String, WireSwingComponentBinding> originalBindings = new LinkedHashMap<>(current.bindings);
        Component focusOwner = KeyboardFocusManager.getCurrentKeyboardFocusManager().getFocusOwner();
        boolean restoreFocus = focusOwner != null && SwingUtilities.isDescendingFrom(focusOwner, stableHost);
        Set<String> createdIds = new LinkedHashSet<>(plan.proposed.instances().keySet());
        createdIds.removeAll(plan.base.instances().keySet());
        Set<String> removedIds = new LinkedHashSet<>(plan.base.instances().keySet());
        removedIds.removeAll(plan.proposed.instances().keySet());
        Set<String> affectedParents = changedParents(plan.base, plan.proposed);

        try {
            for (String id : createdIds) {
                WireInstance instance = plan.proposed.instances().get(id);
                WireDefinition definition = definition(instance.definitionKey());
                WireSwingComponentBinding binding = componentFactory.create(definition, instance, this::queueAction);
                applyInitialSlots(binding, instance);
                current.bindings.put(id, binding);
            }
            for (String id : removedIds) current.bindings.remove(id);
            relayoutParents(current, plan.proposed, affectedParents);
        } catch (RuntimeException ex) {
            current.bindings.clear();
            current.bindings.putAll(originalBindings);
            try { relayoutParents(current, plan.base, affectedParents); }
            catch (RuntimeException ignored) { current.host.revalidate(); current.host.repaint(); }
            throw ex;
        }

        for (PlannedOperation op : plan.operations) {
            if (!(op instanceof SlotOperation slot)) continue;
            if (!plan.proposed.instances().containsKey(slot.instanceId)) continue;
            WireSwingComponentBinding binding = current.bindings.get(slot.instanceId);
            if (binding == null) throw new WireSwingException("INSTANCE_NOT_RENDERED", slot.instanceId);
            try { binding.applySlot(slot.slot, slot.value); }
            catch (RuntimeException ex) {
                emitError("SLOT_RENDER_FAILED", "PROPERTY", ex.getMessage(), Map.of("instanceId", slot.instanceId, "slot", slot.slot));
            }
        }
        current.host.revalidate(); current.host.repaint();
        if (restoreFocus && focusOwner.isDisplayable() && SwingUtilities.isDescendingFrom(focusOwner, stableHost)) {
            focusOwner.requestFocusInWindow();
        }
    }

    private Set<String> changedParents(WireViewModel before, WireViewModel after) {
        Set<String> parents = new LinkedHashSet<>();
        parents.addAll(before.childOrder().keySet());
        parents.addAll(after.childOrder().keySet());
        parents.removeIf(parent -> before.children(parent).equals(after.children(parent)));
        return parents;
    }

    private void relayoutParents(WireSwingRenderTree renderTree, WireViewModel view, Set<String> parentIds) {
        List<String> ordered = new ArrayList<>();
        for (String parentId : parentIds) {
            if (parentId.isBlank() || view.instances().containsKey(parentId)) ordered.add(parentId);
        }
        ordered.sort((a, b) -> Integer.compare(parentDepth(view, a), parentDepth(view, b)));
        for (String parentId : ordered) relayoutParent(renderTree, view, parentId);
    }

    private int parentDepth(WireViewModel view, String parentId) {
        if (parentId.isBlank()) return -1;
        int depth = 0;
        String cursor = parentId;
        Set<String> seen = new LinkedHashSet<>();
        while (!cursor.isBlank()) {
            if (!seen.add(cursor)) throw new WireSwingException("VIEW_PARENT_CYCLE", cursor);
            WireInstance instance = view.instances().get(cursor);
            if (instance == null) break;
            cursor = instance.parentInstanceId();
            depth++;
        }
        return depth;
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
            actionsBlockedByAuthority = false;
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
            target = parent.mount();
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
        List<String> orderedIds = view.children(parentId);
        for (String id : orderedIds) {
            WireInstance instance = view.instances().get(id);
            if (instance != null) children.add(instance);
        }
        if (!parentId.isBlank()) {
            WireInstance parent = view.instances().get(parentId);
            if (parent != null && isServerOrderedCollection(definition(parent.definitionKey()).primitive())) return children;
        }
        Map<String, Integer> insertion = new LinkedHashMap<>();
        for (int i = 0; i < orderedIds.size(); i++) insertion.put(orderedIds.get(i), i);
        children.sort((a, b) -> {
            long ao = layoutEngine.orderFor(definition(a.definitionKey()), insertion.getOrDefault(a.instanceId(), Integer.MAX_VALUE));
            long bo = layoutEngine.orderFor(definition(b.definitionKey()), insertion.getOrDefault(b.instanceId(), Integer.MAX_VALUE));
            int cmp = Long.compare(ao, bo);
            return cmp != 0 ? cmp : Integer.compare(insertion.getOrDefault(a.instanceId(), Integer.MAX_VALUE), insertion.getOrDefault(b.instanceId(), Integer.MAX_VALUE));
        });
        return children;
    }

    private static boolean isServerOrderedCollection(String primitive) {
        return switch (primitive) {
            case "LIST", "OFFER_LIST", "OFFER_SELECTOR", "SEMANTIC_COLLECTION" -> true;
            default -> false;
        };
    }

    private boolean hasChildren(WireViewModel view, String parentId) {
        return !view.children(parentId).isEmpty();
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

        int topLevel = 0;
        Set<String> orderedChildren = new LinkedHashSet<>();
        for (WireInstance instance : view.instances().values()) {
            if (instance.parentInstanceId().isBlank()) {
                topLevel++;
                if (!instance.instanceId().equals(view.rootInstanceId())) throw new WireSwingException("MULTIPLE_VIEW_ROOTS", instance.instanceId());
            } else if (!view.instances().containsKey(instance.parentInstanceId())) {
                throw new WireSwingException("VIEW_PARENT_MISSING", instance.instanceId() + " -> " + instance.parentInstanceId());
            }
        }
        if (topLevel != 1) throw new WireSwingException("VIEW_ROOT_CARDINALITY_INVALID", String.valueOf(topLevel));

        for (Map.Entry<String, List<String>> entry : view.childOrder().entrySet()) {
            String parentId = entry.getKey();
            if (!parentId.isBlank() && !view.instances().containsKey(parentId)) throw new WireSwingException("VIEW_ORDER_PARENT_MISSING", parentId);
            Set<String> local = new LinkedHashSet<>();
            for (String childId : entry.getValue()) {
                if (!local.add(childId)) throw new WireSwingException("VIEW_ORDER_DUPLICATE_CHILD", childId);
                WireInstance child = view.instances().get(childId);
                if (child == null) throw new WireSwingException("VIEW_ORDER_CHILD_MISSING", childId);
                if (!child.parentInstanceId().equals(parentId)) throw new WireSwingException("VIEW_ORDER_PARENT_MISMATCH", childId);
                if (!orderedChildren.add(childId)) throw new WireSwingException("VIEW_ORDER_DUPLICATE_CHILD", childId);
            }
        }
        if (orderedChildren.size() != view.instances().size()) throw new WireSwingException("VIEW_ORDER_INCOMPLETE", orderedChildren.size() + "/" + view.instances().size());

        for (WireInstance instance : view.instances().values()) {
            Set<String> ancestry = new LinkedHashSet<>();
            String cursor = instance.instanceId();
            while (!cursor.isBlank()) {
                if (!ancestry.add(cursor)) throw new WireSwingException("VIEW_PARENT_CYCLE", instance.instanceId());
                WireInstance current = view.instances().get(cursor);
                if (current == null) break;
                cursor = current.parentInstanceId();
            }
        }
    }

    private void validateParentBeforeChild(WireViewModel view) {
        Set<String> seen = new LinkedHashSet<>();
        for (WireInstance instance : view.instances().values()) {
            if (!instance.parentInstanceId().isBlank() && !seen.contains(instance.parentInstanceId())) {
                throw new WireSwingException("SNAPSHOT_PARENT_ORDER_INVALID", instance.instanceId() + " -> " + instance.parentInstanceId());
            }
            seen.add(instance.instanceId());
        }
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
                && a.metadata().equals(b.metadata());
    }

    private static Map<String, Object> deepCopyMap(Map<String, Object> source) { return WireValues.map(source); }

    private sealed interface PlannedOperation permits SlotOperation { }
    private static final class SlotOperation implements PlannedOperation { final String instanceId; final String slot; final Object value; SlotOperation(String instanceId, String slot, Object value) { this.instanceId = instanceId; this.slot = slot; this.value = value; } }
    private record PatchPlan(WireViewModel base, WireViewModel proposed, List<PlannedOperation> operations) { }
    private static final class MissingDefinitionException extends RuntimeException {
        private static final long serialVersionUID = 1L;
        transient final Set<String> keys;
        MissingDefinitionException(Set<String> keys) { super(keys.toString()); this.keys = Set.copyOf(keys); }
    }
}
