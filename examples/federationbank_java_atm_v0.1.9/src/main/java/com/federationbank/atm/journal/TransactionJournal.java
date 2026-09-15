package com.federationbank.atm.journal;

import com.federationbank.atm.protocol.Json;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Append-only local evidence journal. append() fsyncs before returning. */
public final class TransactionJournal {
    private final Path path;
    public TransactionJournal(Path path) { this.path = path; }

    public synchronized void append(JournalEvent event) throws IOException {
        Path parent = path.toAbsolutePath().getParent();
        if (parent != null) Files.createDirectories(parent);
        byte[] bytes = (Json.stringify(event.toMap()) + System.lineSeparator()).getBytes(StandardCharsets.UTF_8);
        try (FileChannel channel = FileChannel.open(path, StandardOpenOption.CREATE, StandardOpenOption.WRITE, StandardOpenOption.APPEND)) {
            channel.write(ByteBuffer.wrap(bytes));
            channel.force(true);
        }
    }

    @SuppressWarnings("unchecked")
    public synchronized List<JournalEvent> readAll() throws IOException {
        List<JournalEvent> out = new ArrayList<>();
        if (!Files.exists(path)) return out;
        for (String line : Files.readAllLines(path, StandardCharsets.UTF_8)) {
            if (line.isBlank()) continue;
            Map<String, Object> m = Json.parseObject(line);
            Object d = m.get("data");
            out.add(new JournalEvent(Instant.parse(String.valueOf(m.get("at"))), String.valueOf(m.get("transactionId")),
                    String.valueOf(m.get("kind")), String.valueOf(m.get("state")),
                    String.valueOf(m.getOrDefault("commandId", "")), String.valueOf(m.getOrDefault("idempotencyKey", "")),
                    d instanceof Map<?, ?> ? (Map<String, Object>) d : Map.of()));
        }
        return out;
    }

    public synchronized Map<String, JournalEvent> latestByTransaction() throws IOException {
        Map<String, JournalEvent> latest = new LinkedHashMap<>();
        for (JournalEvent e : readAll()) latest.put(e.transactionId(), e);
        return latest;
    }
}
