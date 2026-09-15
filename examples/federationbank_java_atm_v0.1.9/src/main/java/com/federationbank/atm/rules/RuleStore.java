package com.federationbank.atm.rules;

import com.federationbank.atm.domain.AtmRules;
import com.federationbank.atm.protocol.Json;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;

/** Durable last-known-valid bank rule snapshot. */
public final class RuleStore {
    private final Path path;

    public RuleStore(Path path) { this.path = path; }

    public synchronized void save(AtmRules rules, String signature, String algorithm, String keyId) throws IOException {
        Files.createDirectories(path.toAbsolutePath().getParent());
        Map<String, Object> envelope = new LinkedHashMap<>();
        envelope.put("schema", "federationbank.atm.signed-rules/0.1");
        envelope.put("rules", rules.raw());
        envelope.put("signatureAlgorithm", algorithm);
        envelope.put("keyId", keyId);
        envelope.put("signature", signature);
        Path tmp = path.resolveSibling(path.getFileName() + ".tmp");
        Files.writeString(tmp, Json.stringify(envelope) + System.lineSeparator(), StandardCharsets.UTF_8);
        try {
            Files.move(tmp, path, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
        } catch (IOException atomicUnavailable) {
            Files.move(tmp, path, StandardCopyOption.REPLACE_EXISTING);
        }
    }

    @SuppressWarnings("unchecked")
    public synchronized Optional<SignedRules> load() throws IOException {
        if (!Files.exists(path)) return Optional.empty();
        Map<String, Object> e = Json.parseObject(Files.readString(path, StandardCharsets.UTF_8));
        Object rm = e.get("rules");
        if (!(rm instanceof Map<?, ?>)) return Optional.empty();
        Map<String, Object> rulesMap = (Map<String, Object>) rm;
        return Optional.of(new SignedRules(AtmRules.fromMap(rulesMap),
                String.valueOf(e.getOrDefault("signature", "")),
                String.valueOf(e.getOrDefault("signatureAlgorithm", "")),
                String.valueOf(e.getOrDefault("keyId", ""))));
    }

    public record SignedRules(AtmRules rules, String signature, String algorithm, String keyId) {}
}
