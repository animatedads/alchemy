package org.alchemy.wireui.swing;

import java.time.Duration;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

final class WireSwingActionQueue {
    private final LinkedBlockingQueue<Map<String, Object>> queue = new LinkedBlockingQueue<>();
    public void offer(Map<String, Object> action) { queue.offer(Collections.unmodifiableMap(new LinkedHashMap<>(action))); }
    public Map<String, Object> poll() { return queue.poll(); }
    public Map<String, Object> poll(Duration timeout) throws InterruptedException {
        return queue.poll(timeout.toMillis(), TimeUnit.MILLISECONDS);
    }
    public int size() { return queue.size(); }
}
