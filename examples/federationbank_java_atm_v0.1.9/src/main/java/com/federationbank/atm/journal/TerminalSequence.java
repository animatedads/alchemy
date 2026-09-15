package com.federationbank.atm.journal;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;

/** Small durable monotonic terminal sequence used in command IDs. */
public final class TerminalSequence {
    private final Path path;
    private long value;

    public TerminalSequence(Path path) throws IOException {
        this.path = path;
        if (Files.exists(path)) value = Long.parseLong(Files.readString(path, StandardCharsets.UTF_8).trim());
    }

    public synchronized long next() throws IOException {
        long next = Math.addExact(value, 1L);
        Path parent = path.toAbsolutePath().getParent();
        if (parent != null) Files.createDirectories(parent);
        Path tmp = path.resolveSibling(path.getFileName() + ".tmp");
        Files.writeString(tmp, Long.toString(next) + System.lineSeparator(), StandardCharsets.UTF_8);
        try { Files.move(tmp, path, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE); }
        catch (IOException e) { Files.move(tmp, path, StandardCopyOption.REPLACE_EXISTING); }
        value = next;
        return value;
    }
}
